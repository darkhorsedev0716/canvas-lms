#
# Copyright (C) 2018 - present Instructure, Inc.
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

class ObserverAlertThreshold < ActiveRecord::Base
  belongs_to :user_observation_link, :inverse_of => :observer_alert_thresholds
  has_many :observer_alerts, :inverse_of => :observer_alert_threshold

  ALERT_TYPES = %w(
    assignment_missing
    assignment_grade_high
    assignment_grade_low
    course_grade_high
    course_grade_low
    course_announcement
    institution_announcement
  ).freeze
  validates :alert_type, inclusion: { in: ALERT_TYPES }
  validates :user_observation_link_id, :alert_type, presence: true
  validates :alert_type, uniqueness: { scope: :user_observation_link }

  scope :active, -> { where.not(workflow_state: 'deleted') }

  def destroy
    self.workflow_state = 'deleted'
    self.save!
  end
end
