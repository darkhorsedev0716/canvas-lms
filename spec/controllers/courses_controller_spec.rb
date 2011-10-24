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

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe CoursesController do
  describe "GET 'index'" do
    it "should force login" do
      course_with_student(:active_all => true)
      get 'index'
      response.should be_redirect
    end
    
    it "should assign variables" do
      course_with_student_logged_in(:active_all => true)
      get 'index'
      response.should be_success
      assigns[:current_enrollments].should_not be_nil
      assigns[:current_enrollments].should_not be_empty
      assigns[:current_enrollments][0].should eql(@enrollment)
      assigns[:past_enrollments].should_not be_nil
    end
  end
  
  describe "GET 'settings'" do
    it "should require authorization" do
      course_with_teacher(:active_all => true)
      get 'settings', :course_id => @course.id
      assert_unauthorized
    end
    
    it "should should not allow students" do
      course_with_student_logged_in(:active_all => true)
      get 'settings', :course_id => @course.id
      assert_unauthorized
    end

    it "should render properly" do
      course_with_teacher_logged_in(:active_all => true)
      get 'settings', :course_id => @course.id
      response.should be_success
      response.should render_template("settings")
    end
  end
  
  describe "GET 'enrollment_invitation'" do
    it "should successfully reject invitation for logged-in user" do
      course_with_student_logged_in(:active_course => true)
      post 'enrollment_invitation', :course_id => @course.id, :reject => '1', :invitation => @enrollment.uuid
      response.should be_redirect
      response.should redirect_to(dashboard_url)
      assigns[:pending_enrollment].should eql(@enrollment)
      assigns[:pending_enrollment].should be_rejected
    end
    
    it "should successfully reject invitation for not-logged-in user" do
      course_with_student(:active_course => true, :active_user => true)
      post 'enrollment_invitation', :course_id => @course.id, :reject => '1', :invitation => @enrollment.uuid
      response.should be_redirect
      response.should redirect_to(root_url)
      assigns[:pending_enrollment].should eql(@enrollment)
      assigns[:pending_enrollment].should be_rejected
    end
    
    it "should not reject invitation for bad parameters" do
      course_with_student(:active_course => true, :active_user => true)
      post 'enrollment_invitation', :course_id => @course.id, :reject => '1', :invitation => @enrollment.uuid + 'a'
      response.should be_redirect
      response.should redirect_to(course_url(@course.id))
      assigns[:pending_enrollment].should be_nil
    end
    
    it "should accept invitation for logged-in user" do
      course_with_student_logged_in(:active_course => true, :active_user => true)
      post 'enrollment_invitation', :course_id => @course.id, :accept => '1', :invitation => @enrollment.uuid
      response.should be_redirect
      response.should redirect_to(course_url(@course.id))
      assigns[:pending_enrollment].should eql(@enrollment)
      assigns[:pending_enrollment].should be_active
    end
    
    it "should ask user to login for registered not-logged-in user" do
      user_with_pseudonym(:active_course => true, :active_user => true)
      course(:active_all => true)
      @enrollment = @course.enroll_user(@user)
      post 'enrollment_invitation', :course_id => @course.id, :accept => '1', :invitation => @enrollment.uuid
      response.should be_redirect
      response.should redirect_to(login_url)
    end
    
    it "should defer to registration_confirmation for pre-registered not-logged-in user" do
      user_with_pseudonym
      course(:active_course => true, :active_user => true)
      @enrollment = @course.enroll_user(@user)
      post 'enrollment_invitation', :course_id => @course.id, :accept => '1', :invitation => @enrollment.uuid
      response.should be_redirect
      response.should redirect_to(registration_confirmation_url(@pseudonym.communication_channel.confirmation_code, :enrollment => @enrollment.uuid))
    end

    it "should defer to registration_confirmation if logged-in user does not match enrollment user" do
      user_with_pseudonym
      @u2 = @user
      course_with_student_logged_in(:active_course => true, :active_user => true)
      @e2 = @course.enroll_user(@u2)
      post 'enrollment_invitation', :course_id => @course.id, :accept => '1', :invitation => @e2.uuid
      response.should redirect_to(registration_confirmation_url(:nonce => @pseudonym.communication_channel.confirmation_code, :enrollment => @e2.uuid))
    end
  end
  
  describe "GET 'show'" do
    it "should require authorization" do
      course_with_teacher(:active_all => true)
      get 'show', :id => @course.id
      assert_unauthorized
    end
    
    # No longer allowing session storage for permission definitions
    # it "should allow access if the course uuid id known" do
      # course
      # get 'show', :id => @course.id, :verification => @course.uuid
      # session[:claim_course_uuid].should eql(@course.uuid)
      # assigns[:context].should eql(@course)
      # response.should be_success
    # end
    
    # it "should allow access if the course uuid is held in the session" do
      # course
      # session[:course_uuid] = @course.uuid
      # get 'show', :id => @course.id
      # assigns[:context].should eql(@course)
      # response.should be_success
    # end
    
    it "should assign variables" do
      course_with_student_logged_in(:active_all => true)
      get 'show', :id => @course.id
      response.should be_success
      assigns[:context].should eql(@course)
      # assigns[:message_types].should_not be_nil
    end

    it "should give a helpful error message for students that can't access yet" do
      course_with_student_logged_in(:active_all => true)
      @course.workflow_state = 'claimed'
      @course.save!
      get 'show', :id => @course.id
      response.status.should == '401 Unauthorized'
      assigns[:unauthorized_message].should_not be_nil

      @course.workflow_state = 'available'
      @course.save!
      @enrollment.start_at = 2.days.from_now
      @enrollment.end_at = 4.days.from_now
      @enrollment.save!
      get 'show', :id => @course.id
      response.status.should == '401 Unauthorized'
      assigns[:unauthorized_message].should_not be_nil
    end

    context "invitations" do
      it "should allow an invited user to see the course" do
        course_with_student(:active_course => 1)
        @enrollment.should be_invited
        get 'show', :id => @course.id, :invitation => @enrollment.uuid
        response.should be_success
        assigns[:pending_enrollment].should == @enrollment
      end

      it "should re-invite an enrollment that has previously been rejected" do
        course_with_student(:active_course => 1)
        @enrollment.should be_invited
        @enrollment.reject!
        get 'show', :id => @course.id, :invitation => @enrollment.uuid
        response.should be_success
        @enrollment.reload
        @enrollment.should be_invited
      end

      it "should auto-redirect to accept if previews are not allowed" do
        # Currently, previews are only allowed for the default account
        @account = Account.create!
        course_with_student(:active_course => 1, :account => @account)
        get 'show', :id => @course.id, :invitation => @enrollment.uuid
        response.should be_redirect
        response.should redirect_to(course_enrollment_invitation_url(@course, :invitation => @enrollment.uuid, :accept => 1))
      end

      it "should ignore invitations that have been accepted" do
        course_with_student(:active_course => 1, :active_enrollment => 1)
        @course.grants_right?(@user, nil, :read).should be_true
        get 'show', :id => @course.id, :invitation => @enrollment.uuid
        response.status.should == '401 Unauthorized'

        # Force reload permissions
        controller.instance_variable_set(:@context_all_permissions, nil)
        user_session(@user)
        get 'show', :id => @course.id, :invitation => @enrollment.uuid
        response.should be_success
        assigns[:pending_enrollment].should be_nil
      end
    end
  end
  
  describe "POST 'unenroll'" do
    it "should require authorization" do
      course_with_teacher(:active_all => true)
      post 'unenroll_user', :course_id => @course.id, :id => @enrollment.id
      assert_unauthorized
    end
    
    it "should not allow students to unenroll" do
      course_with_student_logged_in(:active_all => true)
      post 'unenroll_user', :course_id => @course.id, :id => @enrollment.id
      assert_unauthorized
    end
    
    it "should unenroll users" do
      course_with_teacher_logged_in(:active_all => true)
      student_in_course
      post 'unenroll_user', :course_id => @course.id, :id => @enrollment.id
      @course.reload
      response.should be_success
      @course.enrollments.map{|e| e.user}.should_not be_include(@student)
    end

    it "should not allow teachers to unenroll themselves" do
      course_with_teacher_logged_in(:active_all => true)
      post 'unenroll_user', :course_id => @course.id, :id => @enrollment.id
      assert_unauthorized
    end

    it "should allow admins to unenroll themselves" do
      course_with_teacher_logged_in(:active_all => true)
      @course.account.add_user(@teacher)
      post 'unenroll_user', :course_id => @course.id, :id => @enrollment.id
      @course.reload
      response.should be_success
      @course.enrollments.map{|e| e.user}.should_not be_include(@teacher)
    end
  end
  
  describe "POST 'enroll_users'" do
    before :each do
      account = Account.default
      account.settings = { :open_registration => true }
      account.save!
    end

    it "should require authorization" do
      course_with_teacher(:active_all => true)
      post 'enroll_users', :course_id => @course.id, :user_list => "sam@yahoo.com"
      assert_unauthorized
    end
    
    it "should not allow students to enroll people" do
      course_with_student_logged_in(:active_all => true)
      post 'enroll_users', :course_id => @course.id, :user_list => "\"Sam\" <sam@yahoo.com>, \"Fred\" <fred@yahoo.com>"
      assert_unauthorized
    end
    
    it "should enroll people" do
      course_with_teacher_logged_in(:active_all => true)
      post 'enroll_users', :course_id => @course.id, :user_list => "\"Sam\" <sam@yahoo.com>, \"Fred\" <fred@yahoo.com>"
      response.should be_success
      @course.reload
      @course.students.map{|s| s.name}.should be_include("Sam")
      @course.students.map{|s| s.name}.should be_include("Fred")
    end

    it "should allow TAs to enroll Observers (by default)" do
      course_with_teacher(:active_all => true)
      @user = user
      @course.enroll_ta(user).accept!
      user_session(@user)
      post 'enroll_users', :course_id => @course.id, :user_list => "\"Sam\" <sam@yahoo.com>, \"Fred\" <fred@yahoo.com>", :enrollment_type => 'ObserverEnrollment'
      response.should be_success
      @course.reload
      @course.students.should be_empty
      @course.observers.map{|s| s.name}.should be_include("Sam")
      @course.observers.map{|s| s.name}.should be_include("Fred")
    end
    
  end
  
  describe "PUT 'update'" do
    it "should require authorization" do
      course_with_teacher(:active_all => true)
      put 'update', :id => @course.id, :course => {:name => "new course name"}
      assert_unauthorized
    end
    
    it "should not let students update the course details" do
      course_with_student_logged_in(:active_all => true)
      put 'update', :id => @course.id, :course => {:name => "new course name"}
      assert_unauthorized
    end
    
    it "should update course details" do
      course_with_teacher_logged_in(:active_all => true)
      put 'update', :id => @course.id, :course => {:name => "new course name"}
      assigns[:course].should_not be_nil
      assigns[:course].should eql(@course)
    end
    
    it "should allow sending events" do
      course_with_teacher_logged_in(:active_all => true)
      put 'update', :id => @course.id, :course => {:event => "complete"}
      assigns[:course].should_not be_nil
      assigns[:course].state.should eql(:completed)
    end
  end

  describe "POST unconclude" do
    it "should unconclude the course" do
      course_with_teacher_logged_in(:active_all => true)
      delete 'destroy', :id => @course.id, :event => 'conclude'
      response.should be_redirect
      @course.reload.should be_completed
      @course.conclude_at.should <= Time.now

      post 'unconclude', :course_id => @course.id
      response.should be_redirect
      @course.reload.should be_available
      @course.conclude_at.should be_nil
    end
  end
  
  # describe "GET 'public_feed'" do
    # it "should return success" do
      # course(:active_all => true)
      # get 'public_feed', :feed_code => "
    # end
  # end
end
