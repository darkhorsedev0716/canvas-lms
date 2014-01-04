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

require File.expand_path(File.dirname(__FILE__) + '/../api_spec_helper')

describe "Outcome Results API", :type => :integration do

  let(:outcome_course) do
    course(active_all: true) unless @course
    @course
  end


  let(:outcome_teacher) do
    teacher_in_course(active_all: true) unless @teacher
    @teacher
  end

  let(:outcome_student) do
    student_in_course(active_all: true) unless @student
    @student
  end

  let(:outcome_rubric) do
    outcome_course
    outcome_with_rubric unless @rubric
    @rubric
  end

  let(:outcome_outcome) do
    outcome_rubric unless @outcome
    @outcome
  end

  let(:outcome_assignment) do
    outcome_course.assignments.create!(
      title: "outcome assignment",
      description: "this is an outcome assignment",
      points_possible: @rubric.points_possible,
    )
  end

  let(:outcome_rubric_association) do
    outcome_rubric.associate_with(outcome_assignment, outcome_course, purpose: 'grading', use_for_grading: true)
  end

  let(:outcome_submission) do
    create_outcome_submission
  end

  let(:outcome_assessment) do
    create_outcome_assessment
  end

  def create_outcome_submission(student = outcome_student)
    outcome_assignment.find_or_create_submission(student)
  end

  def create_outcome_assessment(student = outcome_student)
    outcome_criterion = outcome_rubric.criteria.find {|c| !c[:learning_outcome_id].nil? }
    outcome_rating = outcome_criterion[:ratings].first
    outcome_rubric_association.assess(
      user: student,
      assessor: outcome_teacher,
      artifact: create_outcome_submission(student),
      assessment: {
        assessment_type: 'grading',
        "criterion_#{outcome_criterion[:id]}".to_sym => {
          points: outcome_rating[:points]
        }
      }
    )
  end

  let(:outcome_result) do
    outcome_assessment
    outcome_outcome.reload.learning_outcome_results.first
  end

  def outcome_rollups_url(context)
    api_v1_course_outcome_rollups_url(context)
  end

  describe "outcome rollups" do
    describe "error handling" do
      it "requires manage grades permisssion" do
        course_with_student_logged_in
        raw_api_call(:get, outcome_rollups_url(outcome_course),
          controller: 'outcome_results', action: 'rollups', format: 'json', course_id: outcome_course.id.to_s)
        response.status.to_i.should == 401
      end

      it "requires an existing context" do
        outcome_course
        course_with_teacher_logged_in(course: @course, active_all: true)
        bogus_course = Course.new { |c| c.id = -1 }
        raw_api_call(:get, outcome_rollups_url(bogus_course),
          controller: 'outcome_results', action: 'rollups', format: 'json', course_id: bogus_course.id.to_s)
        response.status.to_i.should == 404
      end
    end

    describe "basic response" do
      it "returns a json api structure" do
        outcome_student
        course_with_teacher_logged_in(course: @course, active_all: true)
        result = outcome_result
        api_call(:get, outcome_rollups_url(outcome_course),
          controller: 'outcome_results', action: 'rollups', format: 'json', course_id: outcome_course.id.to_s)
        json = JSON.parse(response.body)
        json.keys.sort.should == %w(linked rollups)
        json['rollups'].size.should == 1
        json['rollups'].each do |rollup|
          rollup.keys.sort.should == %w(id name scores)
          rollup['scores'].size.should == 1
          rollup['scores'].each do |score|
            score.keys.sort.should == %w(outcome_id score)
          end
        end
        json['linked'].keys.should == %w(outcomes)
        json['linked']['outcomes'].size.should == 1
      end
    end
  end

  describe "sharding" do
    specs_require_sharding

    it "returns results for users on multiple shards" do
      student = outcome_student
      outcome_assessment
      student2 = @shard2.activate { User.create!(name: 'outofshard') }
      enrollment = @course.enroll_student(student2, enrollment_state: 'active')
      create_outcome_assessment(student2)
      course_with_teacher_logged_in(course: @course, active_all: true)

      api_call(:get, outcome_rollups_url(outcome_course),
        controller: 'outcome_results', action: 'rollups', format: 'json', course_id: outcome_course.id.to_s)
      json = JSON.parse(response.body)
      json.keys.sort.should == %w(linked rollups)
      json['rollups'].size.should == 2
      json['rollups'].collect{|x| x['id']}.sort.should == [student.id, student2.id].sort
      json['rollups'].each do |rollup|
        rollup.keys.sort.should == %w(id name scores)
        rollup['scores'].size.should == 1
      end
    end
  end
end
