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

module SIS
  class GroupMembershipImporter
    def initialize(batch_id, root_account, logger, override_sis_stickiness)
      @batch_id = batch_id
      @root_account = root_account
      @logger = logger
      @override_sis_stickiness = override_sis_stickiness
    end

    def process
      start = Time.now
      importer = Work.new(@batch_id, @root_account, @logger)
      yield importer
      @logger.debug("Group Users took #{Time.now - start} seconds")
      return importer.success_count
    end

  private
    class Work
      attr_accessor :success_count

      def initialize(batch_id, root_account, logger)
        @batch_id = batch_id
        @root_account = root_account
        @logger = logger
        @success_count = 0
        @groups_cache = {}
      end

      def add_group_membership(user_id, group_id, status)
        @logger.debug("Processing Group User #{[user_id, group_id, status].inspect}")
        raise ImportError, "No group_id given for a group user" if group_id.blank?
        raise ImportError, "No user_id given for a group user" if user_id.blank?
        raise ImportError, "Improper status \"#{status}\" for a group user" unless status =~ /\A(accepted|deleted)/i

        pseudo = Pseudonym.find_by_account_id_and_sis_user_id(@root_account.id, user_id)
        user = pseudo.try(:user)

        group = @groups_cache[group_id]
        group ||= Group.find_by_root_account_id_and_sis_source_id(@root_account.id, group_id)
        @groups_cache[group.sis_source_id] = group if group

        raise ImportError, "User #{user_id} didn't exist for group user" unless user
        raise ImportError, "Group #{group_id} didn't exist for group user" unless group

        # can't query group.group_memberships, since that excludes deleted memberships
        group_membership = GroupMembership.find_by_group_id_and_user_id(group.id, user.id)
        group_membership ||= group.group_memberships.build(:user => user)

        group_membership.sis_batch_id = @batch_id

        case status
        when /accepted/i
          group_membership.workflow_state = 'accepted'
        when /deleted/i
          group_membership.workflow_state = 'deleted'
        end

        group_membership.save
        @success_count += 1
      end

    end
  end
end
