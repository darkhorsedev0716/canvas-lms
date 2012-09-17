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

class GradeCalculator
  
  def initialize(user_ids, course_id)
    @course_id = course_id
    @course = Course.find(course_id)
    @groups = @course.assignment_groups.active
    @assignments = @course.assignments.active.only_graded
    @user_ids = Array(user_ids).map(&:to_i)
    @current_updates = []
    @final_updates = []
  end
  
  def self.recompute_final_score(user_ids, course_id)
    calc = GradeCalculator.new user_ids, course_id
    calc.recompute_and_save_scores
  end
  
  # recomputes the scores and saves them to each user's Enrollment
  def recompute_and_save_scores
    all_submissions = @course.submissions.for_user(@user_ids).to_a
    @user_ids.each do |user_id|
      submissions = all_submissions.select { |submission| submission.user_id == user_id }
      calculate_current_score(user_id, submissions)
      calculate_final_score(user_id, submissions)
    end

    Course.update_all({:updated_at => Time.now.utc}, {:id => @course.id})
    if !@current_updates.empty? || !@final_updates.empty?
      query = "updated_at=#{Enrollment.sanitize(Time.now.utc)}"
      query += ", computed_current_score=CASE #{@current_updates.join(" ")} ELSE computed_current_score END" unless @current_updates.empty?
      query += ", computed_final_score=CASE #{@final_updates.join(" ")} ELSE computed_final_score END" unless @final_updates.empty?
      Enrollment.update_all(query, {:user_id => @user_ids, :course_id => @course.id})
    end
  end

  private
  
  # The score ignoring unsubmitted assignments
  def calculate_current_score(user_id, submissions)
    group_sums = create_group_sums(submissions)
    score = calculate_total_from_group_scores(group_sums)
    @current_updates << "WHEN user_id=#{user_id} THEN #{score || "NULL"}"
  end

  # The final score for the class, so unsubmitted assignments count as zeros
  def calculate_final_score(user_id, submissions)
    group_sums = create_group_sums(submissions, false)
    score = calculate_total_from_group_scores(group_sums, false)
    @final_updates << "WHEN user_id=#{user_id} THEN #{score || "NULL"}"
  end
 
  # returns information about assignments groups in the form:
  # {1=>
  #   {:tally=>0.818181818181818,
  #    :submission_count=>2,
  #    :total_points=>110,
  #    :user_points=>90,
  #    :name=>"Assignments",
  #    :weighted_tally=>0,
  #    :group_weight=>0},
  #  5=> {...}}
  # each group
  def create_group_sums(submissions, ignore_ungraded=true)
    assignments_by_group_id = @assignments.group_by(&:assignment_group_id)
    submissions_by_assignment_id = Hash[
      submissions.map { |s| [s.assignment_id, s] }
    ]

    group_sums = {}
    @groups.each do |group|
      assignments = assignments_by_group_id[group.id] || []
      
      group_submissions = assignments.map do |a|
        s = submissions_by_assignment_id[a.id]

        # ignore submissions for muted assignments
        s = nil if a.muted?

        {
          :assignment => a,
          :submission => s,
          :score => s && s.score,
          :total => a.points_possible
        }
      end
      group_submissions.reject! { |s| s[:score].nil? } if ignore_ungraded
      group_submissions.reject! { |s| s[:total].to_i.zero? }
      group_submissions.each { |s| s[:score] ||= 0 }

      kept = drop_assignments(group_submissions, group.rules_hash)

      score, possible = kept.inject([0, 0]) { |(s_sum,p_sum),s|
        [s_sum + s[:score], p_sum + s[:total]]
      }
      grade = score.to_f / possible
      weight = group.group_weight.to_f

      group_sums[group.id] = {
        :name             => group.name,
        :tally            => grade,
        :submission_count => kept.size,
        :total_points     => possible,
        :user_points      => score,
        :group_weight     => weight,
        :weighted_tally   => grade * weight,
      }
    end
    group_sums
  end

  # see comments for dropAssignments in grade_calculator.coffee
  def drop_assignments(submissions, rules)
    drop_lowest    = rules[:drop_lowest] || 0
    drop_highest   = rules[:drop_highest] || 0
    never_drop_ids = rules[:never_drop] || []
    return submissions if drop_lowest.zero? && drop_highest.zero?

    if never_drop_ids.empty?
      cant_drop = []
    else
      cant_drop, submissions = submissions.partition { |s|
        never_drop_ids.include? s[:assignment].id
      }
    end

    # fudge the drop rules if there aren't enough submissions
    return cant_drop if submissions.empty?
    drop_lowest = submissions.size - 1 if drop_lowest >= submissions.size
    drop_highest = 0 if drop_lowest + drop_highest >= submissions.size

    totals = submissions.map { |s| s[:total] }
    max_total = totals.max

    grades = submissions.map { |s| s[:score].to_f / s[:total] }.sort
    q_low  = grades.first
    q_high = grades.last
    q_mid  = (q_low + q_high) / 2

    keep_highest = submissions.size - drop_lowest

    x, kept = big_f(q_mid, submissions, keep_highest)
    threshold = 1 / (2 * keep_highest * max_total**2)
    until q_high - q_low < threshold
      x < 0 ?
        q_high = q_mid :
        q_low  = q_mid
      q_mid = (q_low + q_high) / 2
      x, kept = big_f(q_mid, submissions, keep_highest)
    end

    kept.shift(drop_highest)
    kept += cant_drop

    kept
  end

  # helper function for drop_assignments
  #
  # returns a new q value (which should eventually approach 0) and any
  # submissions kept according to the given value of q
  def big_f(q, submissions, keep)
    kept = submissions.map { |s|
      rated_score = s[:score] - q * s[:total]
      [rated_score, s]
    }.sort { |(a_rated_score,az), (b_rated_score,bz)|
      b_rated_score <=> a_rated_score
    }.first(keep)

    q_kept = kept.reduce(0) { |sum,(rated_score,z)| sum + rated_score }
    [q_kept, kept.map(&:last)]
  end
  
  # Calculates the final score from the sums of all the assignment groups
  def calculate_total_from_group_scores(group_sums, ignore_ungraded=true)
    if @course.group_weighting_scheme == 'percent'
      score = 0
      possible_weight_from_submissions = 0
      total_possible_weight = 0
      group_sums.select { |id, hash| hash[:group_weight] > 0 }.each do |id, hash|
        if hash[:submission_count] > 0
          score += hash[:weighted_tally].to_f
          possible_weight_from_submissions += hash[:group_weight].to_f
        end
        total_possible_weight += hash[:group_weight].to_f
      end
      if ignore_ungraded && score && possible_weight_from_submissions < 100.0
        possible = total_possible_weight < 100 ? total_possible_weight : 100 
        score = score.to_f * possible / possible_weight_from_submissions.to_f rescue nil
      end
      score = (score * 10.0).round / 10.0 rescue nil
    else
      total_points = 0
      user_points = 0
      group_sums.select { |id, hash| hash[:submission_count] > 0 }.each do |id, hash|
        total_points += hash[:total_points] || 0
        user_points += hash[:user_points] || 0
      end
      score = (user_points.to_f / total_points.to_f * 1000.0).round / 10.0 rescue nil
      score = 0 if score && score.nan?
    end
    score
  end
end
