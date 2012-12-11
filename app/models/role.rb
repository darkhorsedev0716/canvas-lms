#
# Copyright (C) 2012 Instructure, Inc.
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

class Role < ActiveRecord::Base
  belongs_to :account
  belongs_to :root_account, :class_name => 'Account'
  attr_accessible :name
  before_validation :infer_root_account_id
  validates_presence_of :name
  validates_inclusion_of :base_role_type, :in => RoleOverride::BASE_ROLE_TYPES
  validates_exclusion_of :name, :in => RoleOverride::KNOWN_ROLE_TYPES
  validates_uniqueness_of :name, :scope => :account_id
  validate :ensure_no_name_conflict_with_different_base_role_type

  def infer_root_account_id
    unless self.account
      self.errors.add(:account_id)
      return false
    end
    self.root_account_id = self.account.root_account_id || self.account.id
  end

  def ensure_no_name_conflict_with_different_base_role_type
    if self.root_account.all_roles.not_deleted.scoped(:conditions => ["name = ? AND base_role_type <> ?", self.name, self.base_role_type]).any?
      self.errors.add(:name, 'is already taken by a different type of Role in the same root account')
    end
  end

  include Workflow
  workflow do
    state :active do
      event :deactivate, :transitions_to => :inactive
    end
    state :inactive do
      event :activate, :transitions_to => :active
    end
    state :deleted
  end

  def account_role?
    base_role_type == AccountUser::BASE_ROLE_NAME
  end

  def course_role?
    !account_role?
  end

  alias_method :destroy!, :destroy
  def destroy
    self.workflow_state = 'deleted'
    self.deleted_at = Time.now
    save!
  end

  named_scope :not_deleted, :conditions => ['roles.workflow_state != ?', 'deleted']
  named_scope :deleted, :conditions => ['roles.workflow_state = ?', 'deleted']
  named_scope :active, :conditions => ['roles.workflow_state = ?', 'active']
  named_scope :inactive, :conditions => ['roles.workflow_state = ?', 'inactive']
  named_scope :for_courses, :conditions => ['roles.base_role_type != ?', AccountUser::BASE_ROLE_NAME]
  named_scope :for_accounts, :conditions => ['roles.base_role_type = ?', AccountUser::BASE_ROLE_NAME]

  def self.get_base_role_and_workflow_state(role_name, account)
    if RoleOverride.base_role_types.include?(role_name)
      [ role_name, 'active' ]
    elsif role = account.find_role(role_name)
      [ role.base_role_type, role.workflow_state ]
    else
      [ RoleOverride::NO_PERMISSIONS_TYPE, 'deleted' ]
    end
  end

  # Returns a list of hashes for each base enrollment type, and each will have a
  # custom_roles key, each will look like:
  # [{:base_role_name => "StudentEnrollment",
  #   :name => "StudentEnrollment",
  #   :label => "Student",
  #   :custom_roles =>
  #           [{:base_role_name => "StudentEnrollment",
  #             :name => "weirdstudent",
  #             :label => "weirdstudent"}]},
  # ]
  def self.all_enrollment_roles_for_account(account)
    custom_roles = account.available_course_roles_by_name.values
    RoleOverride::ENROLLMENT_TYPES.map do |br|
      new = br.clone
      new[:label] = br[:label].call
      new[:custom_roles] = custom_roles.select{|cr|cr.base_role_type == new[:base_role_name]}.map do |cr|
        {:base_role_name => cr.base_role_type, :name => cr.name, :label => cr.name}
      end
      new
    end
  end
end
