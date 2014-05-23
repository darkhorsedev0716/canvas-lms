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

module Lti
  class ToolProxy < ActiveRecord::Base

    attr_accessible :shared_secret, :guid, :product_version, :lti_version, :product_family, :root_account, :workflow_state, :raw_data

    has_many :bindings, class_name: 'Lti::ToolProxyBinding'
    has_many :resources, class_name: 'Lti::ResourceHandler'
    belongs_to :root_account, class_name: 'Account'
    belongs_to :product_family, class_name: 'Lti::ProductFamily'

    serialize :raw_data

    validates_presence_of :shared_secret, :guid, :product_version, :lti_version, :product_family_id, :root_account_id, :workflow_state, :raw_data
    validates_uniqueness_of :guid

  end
end