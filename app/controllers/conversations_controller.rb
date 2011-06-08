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

class ConversationsController < ApplicationController
  include ConversationsHelper

  before_filter :require_user
  before_filter :get_conversation, :only => [:show, :update, :destroy, :workflow_event, :add_recipients, :add_message, :remove_messages]
  before_filter :load_all_contexts, :only => [:index, :find_recipients, :create, :add_message]
  before_filter :normalize_recipients, :only => [:create, :add_recipients]
  add_crumb(lambda { I18n.t 'crumbs.messages', "Messages" }) { |c| c.send :conversations_url }

  def index
    @conversations = case params[:scope]
      when 'unread'
        @view_name = I18n.t('index.inbox_views.unread', 'Unread')
        @no_messages = I18n.t('no_unread_messages', 'You have no unread messages')
        @current_user.conversations.unread
      when 'archived'
        @view_name = I18n.t('index.inbox_views.archived', 'Archived')
        @no_messages = I18n.t('no_archived_messages', 'You have no archived messages')
        @disallow_messages = true
        @current_user.conversations.archived
      else
        @scope = :inbox
        @view_name = I18n.t('index.inbox_views.inbox', 'Inbox')
        @no_messages = I18n.t('no_messages', 'You have no messages')
        @current_user.conversations.default
    end.map{ |c| jsonify_conversation(c) }
    @scope ||= params[:scope].to_sym
  end

  def create
    if @recipient_ids.present? && params[:body].present?
      @conversation = @current_user.initiate_conversation(@recipient_ids)
      message = @conversation.add_message(params[:body])
      render :json => {:participants => jsonify_users(@conversation.participants),
                       :conversation => jsonify_conversation(@conversation.reload),
                       :message => message}
    else
      render :json => {}, :status => :bad_request
    end
  end

  def show
    @conversation.mark_as_read! if @conversation.unread?
    render :json => {:participants => jsonify_users(@conversation.participants),
                     :messages => @conversation.messages}
  end

  def update
    if @conversation.update_attributes(params[:conversation])
      render :json => @conversation
    else
      render :json => @conversation.errors, :status => :bad_request
    end
  end

  def workflow_event
    event = params[:event].to_sym
    if [:mark_as_read, :mark_as_unread, :archive, :unarchive].include?(event) && @conversation.send(event)
      render :json => @conversation
    else
      # TODO: if it was archived/marked_as_read/etc. out-of-band, we should
      # handle it better (perhaps reload the conversation js-side)
      render :json => @conversation.errors, :status => :bad_request
    end
  end

  def mark_all_as_read
    @current_user.conversations.unread.update_all(:workflow_state => 'read')
    render :json => {}
  end

  def destroy
    @conversation.messages.clear
    @conversation.update_cached_data
    render :json => {}
  end

  def add_recipients
    @conversation.add_participants(@recipient_ids) if @recipient_ids.present?
    render :json => {}
  end

  def add_message
    if params[:body].present?
      message = @conversation.add_message(params[:body])
      render :json => {:conversation => jsonify_conversation(@conversation.reload), :message => message}
    else
      render :json => {}, :status => :bad_request
    end
  end

  def remove_messages
    if params[:remove]
      to_delete = []
      @conversation.messages.each do |message|
        to_delete << message if params[:remove].include?(message.id.to_s)
      end
      @conversation.messages.delete(*to_delete)
      # if the only messages left are generated ones, e.g. "added
      # bob to the conversation", delete those too
      @conversation.messages.clear if @conversation.messages.all?(&:generated?)
      @conversation.update_cached_data
      render :json => @conversation
    end
  end

  def find_recipients
    max_results = 20
    recipients = []
    if params[:context]
      recipients = matching_participants(:search => params[:search], :context => params[:context], :limit => max_results)
    elsif params[:search]
      recipients = matching_contexts(params[:search]) + matching_participants(:search => params[:search], :limit => max_results)
    end
    render :json => recipients[0, max_results]
  end

  private

  def normalize_recipients
    if params[:users]
      @recipient_ids = matching_participants(:ids => params[:users].map(&:to_i)).map{ |p| p[:id] }
    elsif params[:context]
      @recipient_ids = matching_participants(:context => params[:context]).map{ |p| p[:id] }
    end
  end

  def load_all_contexts
    @contexts = {:courses => {}, :groups => {}}
    @current_user.courses.active.each do |course|
      @contexts[:courses][course.id] = {:id => course.id, :name => course.name, :type => :course}
    end
    @current_user.groups.active.each do |group|
      @contexts[:groups][group.id] = {:id => group.id, :name => group.name, :type => :group}
    end
  end

  def matching_contexts(search)
    @contexts.values.map(&:values).flatten.
      select{ |context| context[:name].downcase.include?(search.downcase) }.
      sort_by{ |context| context[:name] }.
      map{ |context| {:id => "#{context[:type]}_#{context[:id]}", :name => context[:name], :type => :context } }
  end

  def matching_participants(options)
    jsonify_users(@current_user.messageable_users(options))
  end

  def get_conversation
    @conversation = @current_user.conversations.find(params[:id] || params[:conversation_id] || 0)
  end

  def jsonify_conversation(conversation)
    hash = {:audience => formatted_audience(conversation, 4)}
    hash[:avatar_url] = avatar_url_for(conversation)
    conversation.as_json.merge(hash)
  end

  def jsonify_users(users)
    ids_present = users.first.respond_to?(:common_course_ids)
    users.map { |user|
      {:id => user.id,
       :name => user.short_name,
       :avatar => avatar_url_for_user(user),
       :course_ids => ids_present ? user.common_course_ids : [],
       :group_ids => ids_present ? user.common_group_ids : []
      }
    }
  end
end