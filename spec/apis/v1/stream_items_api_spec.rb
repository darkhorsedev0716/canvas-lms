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

require File.expand_path(File.dirname(__FILE__) + '/../api_spec_helper')

describe UsersController, :type => :integration do
  before do
    course_with_student(:active_all => true)
  end

  it "should return the activity stream" do
    json = api_call(:get, "/api/v1/users/activity_stream.json",
                    { :controller => "users", :action => "activity_stream", :format => 'json' })
    json.size.should == 0
    google_docs_collaboration_model(:user_id => @user.id)
    json = api_call(:get, "/api/v1/users/activity_stream.json",
                    { :controller => "users", :action => "activity_stream", :format => 'json' })
    json.size.should == 1
  end

  it "should format DiscussionTopic" do
    @context = @course
    discussion_topic_model
    @topic.reply_from(:user => @user, :text => 'hai')
    json = api_call(:get, "/api/v1/users/activity_stream.json",
                    { :controller => "users", :action => "activity_stream", :format => 'json' })
    json.should == [{
      'id' => StreamItem.last.id,
      'discussion_topic_id' => @topic.id,
      'title' => "value for title",
      'message' => 'value for message',
      'type' => 'DiscussionTopic',
      'context_type' => "Course",
      'created_at' => StreamItem.last.created_at.as_json,
      'updated_at' => StreamItem.last.updated_at.as_json,

      'total_root_discussion_entries' => 1,
      'root_discussion_entries' => [
        {
          'user' => { 'user_id' => @user.id, 'user_name' => 'User' },
          'message' => 'hai',
        },
      ],
      'course_id' => @course.id,
    }]
  end

  it "should format Announcement" do
    @context = @course
    announcement_model
    @a.reply_from(:user => @user, :text => 'hai')
    json = api_call(:get, "/api/v1/users/activity_stream.json",
                    { :controller => "users", :action => "activity_stream", :format => 'json' })
    json.should == [{
      'id' => StreamItem.last.id,
      'announcement_id' => @a.id,
      'title' => "value for title",
      'message' => 'value for message',
      'type' => 'Announcement',
      'context_type' => "Course",
      'created_at' => StreamItem.last.created_at.as_json,
      'updated_at' => StreamItem.last.updated_at.as_json,

      'total_root_discussion_entries' => 1,
      'root_discussion_entries' => [
        {
          'user' => { 'user_id' => @user.id, 'user_name' => 'User' },
          'message' => 'hai',
        },
      ],
      'course_id' => @course.id,
    }]
  end

  it "should format Conversation" do
    @sender = User.create!(:name => 'sender')
    @conversation = Conversation.initiate([@user.id, @sender.id], false)
    @conversation.add_message(@sender, "hello")
    @message = @conversation.conversation_messages.last
    json = api_call(:get, "/api/v1/users/activity_stream.json",
                    { :controller => "users", :action => "activity_stream", :format => 'json' }).first
    json.should == {
      'id' => StreamItem.last.id,
      'conversation_id' => @conversation.id,
      'type' => 'Conversation',
      'context_type' => nil,
      'created_at' => StreamItem.last.created_at.as_json,
      'updated_at' => StreamItem.last.updated_at.as_json,
      'title' => nil,
      'message' => nil,

      'private' => false,

      'recent_messages' => [{
        'id' => @message.id,
        'created_at' => @message.created_at.as_json,
        'generated' => false,
        'body' => 'hello',
        'author' => {
          'user_id' => @sender.id,
          'user_name' => 'sender',
        },
      }],

      'participant_count' => 2,
      'message_count' => 1,
    }
  end

  it "should format Message" do
    message_model(:user => @user, :to => 'dashboard', :notification => notification_model)
    json = api_call(:get, "/api/v1/users/activity_stream.json",
                    { :controller => "users", :action => "activity_stream", :format => 'json' })
    json.should == [{
      'id' => StreamItem.last.id,
      'message_id' => @message.id,
      'title' => "value for subject",
      'message' => 'value for body',
      'type' => 'Message',
      'context_type' => nil,
      'created_at' => StreamItem.last.created_at.as_json,
      'updated_at' => StreamItem.last.updated_at.as_json,

      'notification_category' => 'TestImmediately',
      'url' => nil,
    }]
  end

  it "should format Submission" do
    @assignment = @course.assignments.create!(:title => 'assignment 1', :description => 'hai', :points_possible => '14.2', :submission_types => 'online_text_entry')
    @teacher = User.create!(:name => 'teacher')
    @course.enroll_teacher(@teacher)
    @sub = @assignment.grade_student(@user, { :grade => '12' }).first
    @sub.workflow_state = 'submitted'
    @sub.submission_comments.create!(:comment => 'c1', :author => @teacher, :recipient_id => @user.id)
    @sub.submission_comments.create!(:comment => 'c2', :author => @user, :recipient_id => @teacher.id)
    @sub.save!
    json = api_call(:get, "/api/v1/users/activity_stream.json",
                    { :controller => "users", :action => "activity_stream", :format => 'json' })
    json.should == [{
      'id' => StreamItem.last.id,
      'title' => "assignment 1",
      'message' => nil,
      'type' => 'Submission',
      'context_type' => nil,
      'created_at' => StreamItem.last.created_at.as_json,
      'updated_at' => StreamItem.last.updated_at.as_json,
      'grade' => '12',
      'score' => 12,

      'assignment' => {
        'title' => 'assignment 1',
        'id' => @assignment.id,
        'points_possible' => 14.2,
      },
      'course_id' => @course.id,
    }]
  end

  it "should format Collaboration" do
    google_docs_collaboration_model(:user_id => @user.id, :title => 'hey')
    json = api_call(:get, "/api/v1/users/activity_stream.json",
                    { :controller => "users", :action => "activity_stream", :format => 'json' })
    json.should == [{
      'id' => StreamItem.last.id,
      'collaboration_id' => @collaboration.id,
      'title' => "hey",
      'message' => nil,
      'type' => 'Collaboration',
      'context_type' => nil,
      'created_at' => StreamItem.last.created_at.as_json,
      'updated_at' => StreamItem.last.updated_at.as_json,
    }]
  end

  it "should format WebConference" do
    WebConference.instance_eval do
      def plugins
        [OpenObject.new(:id => "big_blue_button", :settings => {:domain => "bbb.instructure.com", :secret_dec => "secret"}, :valid_settings? => true, :enabled? => true),]
      end
    end
    begin
      @conference = BigBlueButtonConference.create!(:title => 'myconf', :user => @user, :description => 'mydesc', :conference_type => 'big_blue_button')
      json = api_call(:get, "/api/v1/users/activity_stream.json",
                      { :controller => "users", :action => "activity_stream", :format => 'json' })
      json.should == [{
        'id' => StreamItem.last.id,
        'web_conference_id' => @conference.id,
        'title' => "myconf",
        'type' => 'WebConference',
        'context_type' => nil,
        'message' => 'mydesc',
        'created_at' => StreamItem.last.created_at.as_json,
        'updated_at' => StreamItem.last.updated_at.as_json,
      }]
    ensure
      WebConference.instance_eval do
        def plugins; Canvas::Plugin.all_for_tag(:web_conferencing); end
      end
    end
  end

  it "should return the course-specific activity stream" do
    @course1 = @course
    @course2 = course_with_student(:user => @user, :active_all => true).course
    @context = @course1
    @topic1 = discussion_topic_model
    @context = @course2
    @topic2 = discussion_topic_model
    json = api_call(:get, "/api/v1/users/activity_stream.json",
                    { :controller => "users", :action => "activity_stream", :format => 'json' })
    json.size.should == 2

    json = api_call(:get, "/api/v1/courses/#{@course2.id}/activity_stream.json",
                    { :controller => "courses", :action => "activity_stream", :course_id => @course2.to_param, :format => 'json' })
    json.size.should == 1
    json.first['discussion_topic_id'].should == @topic2.id
  end
end

