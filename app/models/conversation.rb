#
# Copyright (C) 2011 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

class Conversation < ActiveRecord::Base
  has_many :conversation_participants
  has_many :subscribed_conversation_participants,
           :conditions => "subscribed",
           :class_name => 'ConversationParticipant'
  has_many :conversation_messages, :order => "created_at DESC, id DESC"

  # see also User#messageable_users
  has_many :participants,
    :through => :conversation_participants,
    :source => :user,
    :select => User::MESSAGEABLE_USER_COLUMN_SQL + ", NULL AS common_courses, NULL AS common_groups",
    :order => 'last_authored_at IS NULL, last_authored_at DESC, LOWER(COALESCE(short_name, name))'
  has_many :subscribed_participants,
    :through => :subscribed_conversation_participants,
    :source => :user,
    :select => User::MESSAGEABLE_USER_COLUMN_SQL + ", NULL AS common_courses, NULL AS common_groups",
    :order => 'last_authored_at IS NULL, last_authored_at DESC, LOWER(COALESCE(short_name, name))'
  has_many :attachments, :through => :conversation_messages

  attr_accessible

  def private?
    private_hash.present?
  end

  def self.private_hash_for(user_ids)
    Digest::SHA1.hexdigest(user_ids.sort.join(','))
  end

  def self.initiate(user_ids, private)
    private_hash = private ? private_hash_for(user_ids) : nil
    transaction do
      unless private_hash && conversation = find_by_private_hash(private_hash)
        conversation = new
        conversation.private_hash = private_hash
        conversation.has_attachments = false
        conversation.has_media_objects = false
        conversation.save!
        user_ids.each do |user_id|
          participant = conversation.conversation_participants.build
          participant.user_id = user_id
          participant.workflow_state = 'read'
          participant.save!
        end
      end
      conversation
    end
  end

  def self.update_all_for_asset(asset, options)
    transaction do
      asset.lock!
      if options[:delete_all]
        asset.conversation_messages.destroy_all
        return
      end

      groups = asset.conversation_groups

      conversations = if groups.empty?
        []
      elsif options[:only_existing]
        find_all_by_private_hash(groups.map{ |g| private_hash_for(g) }, :lock => true)
      else
        groups.map{ |g| initiate(g, true) }.each(&:lock!)
      end

      current_messages = conversations.map{ |c| c.update_for_asset(asset, options) }

      # delete asset messages from obsolete conversations (e.g. once the first
      # instructor comments on a submission, remove it from conversations
      # between the submitter and other instructors)
      (asset.conversation_messages - current_messages).each(&:destroy)
    end
  end

  def update_for_asset(asset, options)
    message = asset.conversation_messages.detect { |m| m.conversation_id == id }
    if message
      add_message_to_participants(message, options) # make sure it gets re-added
    else
      message = add_message(asset.user, '', options.merge(:asset => asset, :update_participants => false))
    end
    if (data = asset.conversation_message_data).present?
      message.created_at = data[:created_at]
      message.author_id = data[:author_id]
      message.body = data[:body]
      message.save!
    end

    if options[:update_participants]
      update_participants message, options.merge(:skip_attachments_and_media_comments => true)
    else
      conversation_participants.each{ |cp| cp.update_cached_data!(options.merge(:set_last_message_at => false)) }
    end
    message
  end

  def add_participants(current_user, user_ids)
    user_ids.map!(&:to_i)
    raise "can't add participants to a private conversation" if private?
    transaction do
      lock!
      user_ids -= conversation_participants.map(&:user_id)
      next if user_ids.empty?

      last_message_at = conversation_messages.human.first.created_at
      raise "can't add participants if there are no messages" unless last_message_at
      num_messages = conversation_messages.human.size

      User.update_all("unread_conversations_count = unread_conversations_count + 1, updated_at = '#{Time.now.to_s(:db)}'", :id => user_ids)
      user_ids.each do |user_id|
        participant = conversation_participants.build
        participant.user_id = user_id
        participant.workflow_state = 'unread'
        participant.last_message_at = last_message_at
        participant.message_count = num_messages
        participant.save!
      end

      # give them all messages
      connection.execute(<<-SQL)
        INSERT INTO conversation_message_participants(conversation_message_id, conversation_participant_id)
        SELECT conversation_messages.id, conversation_participants.id
        FROM conversation_messages, conversation_participants
        WHERE conversation_messages.conversation_id = #{self.id}
          AND conversation_messages.conversation_id = conversation_participants.conversation_id
          AND conversation_participants.user_id IN (#{user_ids.join(', ')})
      SQL

      # announce their arrival
      add_event_message(current_user, :event_type => :users_added, :user_ids => user_ids)
    end
  end

  def add_event_message(current_user, event_data={})
    add_message(current_user, event_data.to_yaml, :generated => true)
  end

  def add_message(current_user, body, options = {})
    transaction do
      lock!

      options = {:generated => false,
                 :update_for_sender => true,
                 :only_existing => false}.update(options)
      options[:update_participants] = !options[:generated]         unless options.has_key?(:update_participants)
      options[:update_for_skips]    = options[:update_for_sender]  unless options.has_key?(:update_for_skips)
      options[:skip_ids]          ||= [current_user.id]

      message = conversation_messages.build
      message.author_id = current_user.id
      message.body = body
      message.generated = options[:generated]
      message.context = options[:context]
      message.asset = options[:asset]
      if options[:forwarded_message_ids].present?
        messages = ConversationMessage.find_all_by_id(options[:forwarded_message_ids].map(&:to_i))
        conversation_ids = messages.select(&:forwardable?).map(&:conversation_id).uniq
        raise "can only forward one conversation at a time" if conversation_ids.size != 1
        raise "user doesn't have permission to forward these messages" unless current_user.conversations.find_by_conversation_id(conversation_ids.first)
        # TODO: optimize me
        message.forwarded_message_ids = messages.map(&:id).join(',')
      end
      message.save!

      yield message if block_given?

      add_message_to_participants(message, options)
      if options[:update_participants]
        update_participants(message, options)
      end
      message
    end
  end

  def add_message_to_participants(message, options = {})
    skip_ids = [0]
    if !message.just_created
      skip_ids += ConversationMessageParticipant.for_conversation_and_message(id, message.id).
                  map(&:conversation_participant_id)
    end
    skip_ids |= conversation_participants.deleted.map(&:id) if options[:only_existing]

    conditions = self.class.send(:sanitize_sql_array, ["conversation_id = ? AND id NOT IN (?)", id, skip_ids])

    unless options[:generated]
      connection.execute("UPDATE conversation_participants SET message_count = message_count + 1 WHERE #{conditions}")
    end

    connection.execute(<<-SQL)
      INSERT INTO conversation_message_participants(conversation_message_id, conversation_participant_id)
      SELECT #{message.id}, id FROM conversation_participants WHERE #{conditions}
    SQL
  end

  def update_participants(message, options = {})
    skip_ids = options[:skip_ids] || [message.author_id]
    skip_ids = [0] if skip_ids.empty?
    update_for_skips = options[:update_for_skips] != false

    # make sure this jumps to the top of the inbox and is marked as unread for anyone who's subscribed
    cp_conditions = self.class.send :sanitize_sql_array, [
      "cp.conversation_id = ? AND cp.workflow_state <> 'unread' AND (cp.last_message_at IS NULL OR cp.subscribed) AND cp.user_id NOT IN (?)",
      self.id,
      skip_ids
    ]
    if connection.adapter_name =~ /mysql/i
      connection.execute <<-SQL
        UPDATE users, conversation_participants cp
        SET unread_conversations_count = unread_conversations_count + 1
        WHERE users.id = cp.user_id AND #{cp_conditions}
      SQL
    else
      User.update_all 'unread_conversations_count = unread_conversations_count + 1',
                      "id IN (SELECT user_id FROM conversation_participants cp WHERE #{cp_conditions})"
    end
    conversation_participants.update_all(
      {:last_message_at => message.created_at, :workflow_state => 'unread'},
      ["(last_message_at IS NULL OR subscribed) AND user_id NOT IN (?)", skip_ids]
    )

    # for the sender (or override(s)), we just update the timestamps
    # for the sake of overrides, we need to ensure that the message.created_at
    # is newer than last_message_at (e.g. for the submission comment migration)
    # once that code is removed, we can simplify this.
    conversation_participants.update_all(
      ["last_message_at = CASE WHEN last_message_at IS NULL OR last_message_at < ? THEN ? ELSE last_message_at END,
        last_authored_at = CASE WHEN user_id = ? AND (last_authored_at IS NULL OR last_authored_at < ?) THEN ? ELSE last_authored_at END", message.created_at, message.created_at, message.author_id, message.created_at, message.created_at],
      ["user_id IN (?)" + (update_for_skips ? "" : " AND last_message_at IS NOT NULL"), skip_ids]
    )
    return if options[:skip_attachments_and_media_comments]

    updated = false
    if message.attachments.present?
      self.has_attachments = true
      conversation_participants.update_all({:has_attachments => true}, "NOT has_attachments")
      updated = true
    end
    if message.media_comment_id.present?
      self.has_media_objects = true
      conversation_participants.update_all({:has_media_objects => true}, "NOT has_media_objects")
      updated = true
    end
    self.save if updated
  end

  def reply_from(opts)
    user = opts.delete(:user)
    message = opts.delete(:text).to_s.strip
    user = nil unless user && self.participants.find_by_id(user.id)
    if !user
      raise "Only message participants may reply to messages"
    elsif message.blank?
      raise "Message body cannot be blank"
    else
      add_message(user, message, opts)
    end
  end
end
