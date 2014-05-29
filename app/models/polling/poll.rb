#
# Copyright (C) 2014 Instructure, Inc.
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

module Polling
  class Poll < ActiveRecord::Base
    attr_accessible :user, :question, :description

    belongs_to :user
    has_many :poll_choices, class_name: 'Polling::PollChoice', dependent: :destroy
    has_many :poll_submissions, class_name: 'Polling::PollSubmission', dependent: :destroy
    has_many :poll_sessions, class_name: 'Polling::PollSession', dependent: :destroy

    validates_presence_of :question, :user
    validates_length_of :question, maximum: 255, allow_nil: true
    validates_length_of :description, maximum: 255, allow_nil: true

    set_policy do
      given { |user| user.roles.include?("admin") }
      can :create and can :update and can :read and can :delete and can :submit

      given { |user| user.roles.include?("teacher") }
      can :create

      given { |user| self.user.present? && self.user == user }
      can :update and can :read and can :delete

      given do |user, session|
        self.poll_sessions.any? { |poll_session| poll_session.grants_right?(user, session, :submit) }
      end
      can :read
    end

    def total_results
      poll_sessions.reduce(Hash.new(0)) do |poll_results, session|
        poll_results = poll_results.merge(session.results) do |key, poll_result_value, session_result_value|
          poll_result_value + session_result_value
        end

        poll_results
      end
    end
  end
end
