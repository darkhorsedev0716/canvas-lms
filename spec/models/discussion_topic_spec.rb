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

describe DiscussionTopic do
  it "should santize message" do
    course_model
    @course.discussion_topics.create!(:message => "<a href='#' onclick='alert(12);'>only this should stay</a>")
    @course.discussion_topics.first.message.should eql("<a href=\"#\">only this should stay</a>")
  end
  
  it "should update the assignment it is associated with" do
    course_model
    a = @course.assignments.create!(:title => "some assignment", :points_possible => 5)
    a.points_possible.should eql(5.0)
    a.submission_types.should_not eql("online_quiz")
    t = @course.discussion_topics.build(:assignment => a, :title => "some topic", :message => "a little bit of content")
    t.save
    t.assignment_id.should eql(a.id)
    t.assignment.should eql(a)
    a.reload
    a.discussion_topic.should eql(t)
    a.submission_types.should eql("discussion_topic")
  end
  
  it "should delete the assignment if the topic is no longer graded" do
    course_model
    a = @course.assignments.create!(:title => "some assignment", :points_possible => 5)
    a.points_possible.should eql(5.0)
    a.submission_types.should_not eql("online_quiz")
    t = @course.discussion_topics.build(:assignment => a, :title => "some topic", :message => "a little bit of content")
    t.save
    t.assignment_id.should eql(a.id)
    t.assignment.should eql(a)
    a.reload
    a.discussion_topic.should eql(t)
    t.assignment = nil
    t.save
    t.reload
    t.assignment_id.should eql(nil)
    t.assignment.should eql(nil)
    a.reload
    a.should be_deleted
  end

  it "should not grant permissions if it is locked" do
    course_with_teacher(:active_all => 1)
    student_in_course(:active_all => 1)
    @topic = @course.discussion_topics.create!(:user => @teacher)
    relevant_permissions = [:read, :reply, :update, :delete]
    (@topic.check_policy(@teacher) & relevant_permissions).map(&:to_s).sort.should == ['read', 'reply', 'update', 'delete'].sort
    (@topic.check_policy(@student) & relevant_permissions).map(&:to_s).sort.should == ['read', 'reply'].sort
    @topic.lock!
    (@topic.check_policy(@teacher) & relevant_permissions).map(&:to_s).sort.should == ['read', 'update', 'delete'].sort
    (@topic.check_policy(@student) & relevant_permissions).map(&:to_s).should == ['read']
    @topic.unlock!
    (@topic.check_policy(@teacher) & relevant_permissions).map(&:to_s).sort.should == ['read', 'reply', 'update', 'delete'].sort
    (@topic.check_policy(@student) & relevant_permissions).map(&:to_s).sort.should == ['read', 'reply'].sort

    @entry = @topic.discussion_entries.create!(:user => @teacher)
    @entry.discussion_topic = @topic
    (@entry.check_policy(@teacher) & relevant_permissions).map(&:to_s).sort.should == ['read', 'reply', 'update', 'delete'].sort
    (@entry.check_policy(@student) & relevant_permissions).map(&:to_s).sort.should == ['read', 'reply'].sort
    @topic.lock!
    (@topic.check_policy(@teacher) & relevant_permissions).map(&:to_s).sort.should == ['read', 'update', 'delete'].sort
    (@entry.check_policy(@student) & relevant_permissions).map(&:to_s).should == ['read']
    @topic.unlock!
    (@entry.check_policy(@teacher) & relevant_permissions).map(&:to_s).sort.should == ['read', 'reply', 'update', 'delete'].sort
    (@entry.check_policy(@student) & relevant_permissions).map(&:to_s).sort.should == ['read', 'reply'].sort
  end
  
  context "delayed posting" do
    def delayed_discussion_topic(opts = {})
      @topic = @course.discussion_topics.build(opts)
      @topic.workflow_state = 'post_delayed'
      @topic.save!
      @topic
    end
    
    it "shouldn't send to streams on creation or update if it's delayed" do
      course_with_student(:active_all => true)
      @user.register
      topic = @course.discussion_topics.create!(:title => "this should not be delayed", :message => "content here")
      StreamItem.find_by_item_asset_string(topic.asset_string).should_not be_nil
      
      topic = delayed_discussion_topic(:title => "this should be delayed", :message => "content here", :delayed_post_at => Time.now + 1.day)
      StreamItem.find_by_item_asset_string(topic.asset_string).should be_nil
      
      topic.message = "content changed!"
      topic.save
      StreamItem.find_by_item_asset_string(topic.asset_string).should be_nil
    end

    it "should send to streams on update from delayed to active" do
      course_with_student(:active_all => true)
      @user.register
      topic = delayed_discussion_topic(:title => "this should be delayed", :message => "content here", :delayed_post_at => Time.now + 1.day)
      topic.workflow_state.should == 'post_delayed'
      StreamItem.find_by_item_asset_string(topic.asset_string).should be_nil
      
      topic.delayed_post_at = nil
      topic.title = "this isn't delayed any more"
      topic.workflow_state = 'active'
      topic.save!
      StreamItem.find_by_item_asset_string(topic.asset_string).should_not be_nil
    end
  end
  
  context "clone_for" do
    it "should clone to another context" do
      course_model
      topic = @course.discussion_topics.create!(:message => "<a href='#' onclick='alert(12);'>only this should stay</a>", :title => "some topic")
      course
      new_topic = topic.clone_for(@course)
      new_topic.context.should eql(@course)
      new_topic.context.should_not eql(topic.context)
      new_topic.message.should eql(topic.message)
      new_topic.title.should eql(topic.title)
    end
  end
  
  context "sub-topics" do
    it "should default subtopics_refreshed_at on save if a group assignment" do
      course_with_student(:active_all => true)
      @group = @course.groups.create(:name => "group", :group_category_name => "category")
      @topic = @course.discussion_topics.create(:title => "topic")
      @topic.subtopics_refreshed_at.should be_nil

      @topic.assignment = @course.assignments.build(:submission_types => 'discussion_topic', :title => @topic.title, :group_category_name => @group.group_category_name)
      @topic.assignment.infer_due_at
      @topic.assignment.saved_by = :discussion_topic
      @topic.save
      @topic.subtopics_refreshed_at.should_not be_nil
    end

    it "should not allow students to edit sub-topics" do
      course_with_student(:active_all => true)
      @first_user = @user
      @second_user = user_model
      @course.enroll_student(@second_user).accept
      @parent_topic = @course.discussion_topics.create!(:title => "parent topic", :message => "msg")
      @group = @course.groups.create!(:name => "course group")
      @group.add_user(@first_user)
      @group.add_user(@second_user)
      @group_topic = @group.discussion_topics.create!(:title => "group topic", :message => "ok to be edited", :user => @first_user)
      @sub_topic = @group.discussion_topics.build(:title => "sub topic", :message => "not ok to be edited", :user => @first_user)
      @sub_topic.root_topic_id = @parent_topic.id
      @sub_topic.save!
      @group_topic.grants_right?(@second_user, nil, :update).should eql(true)
      @sub_topic.grants_right?(@second_user, nil, :update).should eql(false)
    end
  end

  context "refresh_subtopics" do
    it "should be a no-op unless there's an assignment and it has a group_category_name" do
      course_with_student(:active_all => true)
      @topic = @course.discussion_topics.create(:title => "topic")
      @topic.refresh_subtopics.should be_nil
      @topic.reload.child_topics.should be_empty

      @topic.assignment = @course.assignments.build(:submission_types => 'discussion_topic', :title => @topic.title)
      @topic.assignment.saved_by = :discussion_topic
      @topic.save
      @topic.refresh_subtopics.should be_nil
      @topic.reload.child_topics.should be_empty
    end

    it "should create a topic per active group in the category otherwise" do
      course_with_student(:active_all => true)
      @group1 = @course.groups.create(:name => "group 1", :group_category_name => "category")
      @group2 = @course.groups.create(:name => "group 2", :group_category_name => "category")

      @topic = @course.discussion_topics.build(:title => "topic")
      @assignment = @course.assignments.build(:submission_types => 'discussion_topic', :title => @topic.title, :group_category_name => @group1.group_category_name)
      @assignment.infer_due_at
      @assignment.saved_by = :discussion_topic
      @topic.assignment = @assignment
      @topic.save

      subtopics = @topic.refresh_subtopics
      subtopics.should_not be_nil
      subtopics.size.should == 2
      subtopics.each{ |t| t.root_topic.should == @topic }
      @group1.reload.discussion_topics.should_not be_empty
      @group2.reload.discussion_topics.should_not be_empty
    end
  end

  context "root_topic?" do
    it "should be false if the topic has a root topic" do
      # subtopic has the assignment and group_category_name, but has a root topic
      course_with_student(:active_all => true)
      @parent_topic = @course.discussion_topics.create(:title => "parent topic")
      @subtopic = @parent_topic.child_topics.build(:title => "subtopic")
      @assignment = @course.assignments.build(:submission_types => 'discussion_topic', :title => @subtopic.title, :group_category_name => "category")
      @assignment.infer_due_at
      @assignment.saved_by = :discussion_topic
      @subtopic.assignment = @assignment
      @subtopic.save

      @subtopic.should_not be_root_topic
    end

    it "should be false unless the topic has an assignment" do
      # topic has no root topic, but also has no assignment
      course_with_student(:active_all => true)
      @topic = @course.discussion_topics.create(:title => "subtopic")
      @topic.should_not be_root_topic
    end

    it "should be false unless the topic's assignment has a group_category_name" do
      # topic has no root topic and has an assignment, but the assignment has no group_category_name
      course_with_student(:active_all => true)
      @topic = @course.discussion_topics.create(:title => "topic")
      @assignment = @course.assignments.build(:submission_types => 'discussion_topic', :title => @topic.title)
      @assignment.infer_due_at
      @assignment.saved_by = :discussion_topic
      @topic.assignment = @assignment
      @topic.save

      @topic.should_not be_root_topic
    end

    it "should be true otherwise" do
      # topic meets all criteria
      course_with_student(:active_all => true)
      @topic = @course.discussion_topics.create(:title => "topic")
      @assignment = @course.assignments.build(:submission_types => 'discussion_topic', :title => @topic.title, :group_category_name => "category")
      @assignment.infer_due_at
      @assignment.saved_by = :discussion_topic
      @topic.assignment = @assignment
      @topic.save

      @topic.should be_root_topic
    end
  end

  context "for_assignment?/for_group_assignment?" do
    it "should not be for_assignment?/for_group_assignment? unless it has an assignment" do
      course_with_student(:active_all => true)
      @topic = @course.discussion_topics.create(:title => "topic")
      @topic.should_not be_for_assignment
      @topic.should_not be_for_group_assignment

      @topic.assignment = @course.assignments.build(:submission_types => 'discussion_topic', :title => @topic.title, :group_category_name => "category")
      @topic.assignment.infer_due_at
      @topic.assignment.saved_by = :discussion_topic
      @topic.save
      @topic.should be_for_assignment
      @topic.should be_for_group_assignment
    end

    it "should not be for_group_assignment? unless the assignment has a group_category_name" do
      course_with_student(:active_all => true)
      @topic = @course.discussion_topics.build(:title => "topic")
      @assignment = @course.assignments.build(:submission_types => 'discussion_topic', :title => @topic.title)
      @assignment.infer_due_at
      @assignment.saved_by = :discussion_topic
      @topic.assignment = @assignment
      @topic.save
      @topic.should be_for_assignment
      @topic.should_not be_for_group_assignment

      @assignment.group_category_name = "category"
      @assignment.save
      @topic.reload.should be_for_group_assignment
    end
  end

  context "should_send_to_stream" do
    it "should be true for non-assignment discussions" do
      course_with_student(:active_all => true)
      @topic = @course.discussion_topics.create(:title => "topic")
      @topic.should_send_to_stream.should be_true
    end

    it "should be true for non-group discussion assignments" do
      course_with_student(:active_all => true)
      @topic = @course.discussion_topics.build(:title => "topic")
      @assignment = @course.assignments.build(:submission_types => 'discussion_topic', :title => @topic.title, :due_at => 1.day.from_now)
      @assignment.saved_by = :discussion_topic
      @topic.assignment = @assignment
      @topic.save
      @topic.should_send_to_stream.should be_true
    end

    it "should be true for the parent topic only in group discussion assignments, not the subtopics" do
      course_with_student(:active_all => true)
      @parent_topic = @course.discussion_topics.create(:title => "parent topic")
      @subtopic = @parent_topic.child_topics.build(:title => "subtopic")
      @assignment = @course.assignments.build(:submission_types => 'discussion_topic', :title => @subtopic.title, :group_category_name => "category", :due_at => 1.day.from_now)
      @assignment.saved_by = :discussion_topic
      @subtopic.assignment = @assignment
      @subtopic.save
      @parent_topic.should_send_to_stream.should be_true
      @subtopic.should_send_to_stream.should be_false
    end
  end
end
