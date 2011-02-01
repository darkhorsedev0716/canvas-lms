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

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')

describe QuizSubmission do
  before(:each) do
    course
    @quiz = @course.quizzes.create!
  end
  
  it "should not allow updating scores on an uncompleted submission" do
    q = @quiz.quiz_submissions.create!
    q.state.should eql(:untaken)
    res = q.update_scores rescue false
    res.should eql(false)
  end
  
  it "should not allowed grading on an already-graded submission" do
    q = @quiz.quiz_submissions.create!
    q.workflow_state = "complete"
    q.save!

    q.workflow_state.should eql("complete")
    q.state.should eql(:complete)
    q.write_attribute(:submission_data, [])
    res = false
    begin
      res = q.grade_submission
      0.should eql(1)
    rescue => e
      e.to_s.should match(Regexp.new("Can't grade an already-submitted submission"))
    end
    res.should eql(false)
  end
  
  it "should know if it is overdue" do
    now = Time.now
    q = @quiz.quiz_submissions.new
    q.end_at = now
    q.save!
    
    q.overdue?.should eql(false)
    q.end_at = now - (3 * 60)
    q.save!
    q.overdue?.should eql(false)

    q.overdue?(true).should eql(true)
    q.end_at = now - (6 * 60)
    q.save!
    q.overdue?.should eql(true)
    q.overdue?(true).should eql(true)
  end
  
  it "should calculate score based on quiz scoring policy" do
    q = @course.quizzes.create!(:scoring_policy => "keep_latest")
    s = q.quiz_submissions.new
    s.workflow_state = "complete"
    s.score = 5.0
    s.attempt = 1
    s.save!
    s.score.should eql(5.0)
    s.kept_score.should eql(5.0)
    
    s.score = 4.0
    s.attempt = 2
    s.save!
    s.kept_score.should eql(4.0)
    
    q.update_attributes!(:scoring_policy => "keep_highest")
    s.reload
    s.score = 3.0
    s.attempt = 3
    s.save!
    s.kept_score.should eql(5.0)
  end
  
  it "should update associated submission" do
    c = factory_with_protected_attributes(Course, :workflow_state => "active")
    a = c.assignments.new(:title => "some assignment")
    a.workflow_state = "available"
    a.save!
    u = User.new
    u.workflow_state = "registered"
    u.save!
    c.enroll_student(u)
    s = a.submit_homework(u)
    quiz = c.quizzes.create!
    q = quiz.quiz_submissions.new
    q.submission_id = s.id
    q.user_id = u.id
    q.workflow_state = "complete"
    q.score = 5.0
    q.save!
    q.kept_score.should eql(5.0)
    s.reload
    
    s.score.should eql(5.0)
  end
end
