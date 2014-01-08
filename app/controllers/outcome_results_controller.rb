#
# Copyright (C) 2013 Instructure, Inc.
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

# @API Outcome Results
# @beta
#
# API for accessing learning outcome results
#
# @object OutcomeRollupScore
#     {
#       // The rollup score for the outcome, based on the student assessment
#       // scores related to the outcome. This could be null if the student has
#       // no related scores.
#       "score": 3,
#
#       "links": {
#         // The id of the related outcome
#         "outcome": 42
#       }
#     }
#
# @object OutcomeRollup
#     {
#       // an array of OutcomeRollupScore objects
#       "scores": ["OutcomeRollupScore"],
#
#       // The id of the resource for this rollup. For example, the user id.
#       "id": 42,
#
#       // The name of the resource for this rollup. For example, the user name.
#       "name": "John Doe",
#
#       "links": {
#         // (Optional) The id of the section this resource is in
#         "section": 57
#       }
#     }
#

class OutcomeResultsController < ApplicationController
  include Api::V1::OutcomeResults
  include Outcomes::ResultAnalytics

  before_filter :require_user
  before_filter :require_context
  before_filter :require_outcome_context
  before_filter :verify_aggregate_parameter
  before_filter :require_outcomes
  before_filter :require_users
  
  # @API Get outcome result rollups
  # @beta
  #
  # Gets the outcome rollups for the users and outcomes in the specified
  # context.
  #
  # @argument aggregate [Optional, String, "course"]
  #   If specified, instead of returning one rollup for each user, all the user
  #   rollups will be combined into one rollup for the course that will contain
  #   the average rollup score for each outcome.
  #
  # @argument user_ids[] [Optional, Integer]
  #   If specified, only the users whose ids are given will be included in the
  #   results or used in an aggregate result. it is an error to specify an id
  #   for a user who is not a student in the context
  #
  # @example_response
  #    {
  #      "rollups": [OutcomeRollup],
  #      "linked": {
  #        "outcomes": [Outcome]
  #      }
  #    }
  def rollups
    if params[:aggregate] == 'course'
      aggregate_rollups
    else
      user_rollups
    end
  end

  # Internal: Renders rollups for each user.
  #
  # Returns nothing.
  def user_rollups
    @users = Api.paginate(@users, self, api_v1_course_outcome_rollups_url(@context))
    @results = find_outcome_results(users: @users, context: @context, outcomes: @outcomes)
    rollups = outcome_results_rollups(@results, @users)
    json = outcome_results_rollups_json(rollups, @outcomes)
    json[:meta] = Api.jsonapi_meta(@users, self, api_v1_course_outcome_rollups_url(@context))
    render json: json
  end

  # Internal: Renders the aggregate rollups for the context.
  #
  # Returns nothing.
  def aggregate_rollups
    # calculating averages for all users in the context and only returning one
    # rollup, so don't paginate users in ths method.
    @results = find_outcome_results(users: @users, context: @context, outcomes: @outcomes)
    aggregate_rollups = [aggregate_outcome_results_rollup(@results, @context)]
    json = aggregate_outcome_results_rollups_json(aggregate_rollups, @outcomes)
    # no pagination, so no meta field
    render json: json
  end

  # Internal: Makes sure the context is a valid context for outcome_results and
  #   the current_user has appropriate permissions. This method is meant to be
  #   used as a before_filter.
  #
  # Returns nothing. May render if current_user does not have permissions.
  def require_outcome_context
    unless @context.is_a?(Course)
      return render json: {message: "invalid context type"}, status: :bad_request
    end

    authorized_action(@context, @current_user, [:manage_grades, :view_all_grades])
  end

  # Internal: Verifies the aggregate parameter.
  #
  # Returns false and renders an error if the aggregate parameter is invalid.
  #   Returns true otherwise.
  def verify_aggregate_parameter
    aggregate = params[:aggregate]
    if aggregate && !%w(course).include?(aggregate)
      render json: {message: "invalid aggregate parameter value"}, status: :bad_request
      false
    else
      true
    end
  end

  # Internal: Finds context outcomes
  #
  # Return an outcome scope
  def require_outcomes
    @outcomes = @context.linked_learning_outcomes
  end
  
  # Internal: Filter context users by user_ids param (if provided), ensuring
  #  that user_ids does not include users not in the context.
  #
  # Returns false and renders an error if user_ids includes a user outside the
  #  context. Returns a user scope otherwise.
  def require_users
    @users = users_for_outcome_context
    if params[:user_ids]
      user_ids = Api.value_to_array(params[:user_ids]).map(&:to_i).uniq
      @users = @users.where(id: user_ids)
      if @users.count != user_ids.count
        render json: {message: "can only include id's of users in the outcome context"}, status: :bad_request
        return false
      end
    end
    @users
  end

  # Internal: Gets a list of users that should have results returned based on
  #   @context. For courses, this will only return students.
  #
  # Returns an Enumeration of User objects.
  def users_for_outcome_context
    # this only works for courses; when other context types are added, this will
    # need to treat them differently.
    @context.students
  end

end
