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

class ConversationMessage < ActiveRecord::Base
  belongs_to :conversation
  belongs_to :author, :class_name => 'User'
  has_many :conversation_message_participants
  has_many :attachments, :as => :context
  has_many :media_objects, :as => :context
  attr_accessible

  named_scope :human, :conditions => "NOT generated"

  validates_length_of :body, :maximum => maximum_text_length

  def body
    if generated?
      format_event_message
    else
      read_attribute(:body)
    end
  end

  def event_data
    return {} unless generated?
    @event_data ||= YAML.load(read_attribute(:body))
  end

  def format_event_message
    case event_data[:event_type]
    when :users_added
      users = User.find_all_by_id(event_data[:user_ids]).map(&:short_name)
      t :message_users_added, {
          :one => "%{user} was added to the conversation by %{current_user}",
          :other => "%{list_of_users} were added to the conversation by %{current_user}"
       },
       :count => users.size,
       :user => users.first,
       :list_of_users => users.to_sentence,
       :current_user => author.short_name
    end
  end
end
