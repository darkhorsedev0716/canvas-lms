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

describe "enrollment_date_restrictions" do
  it "should not list inactive enrollments" do
    @student = user_with_pseudonym
    course(:course_name => "Course 1", :active_all => 1)
    e1 = student_in_course(:user => @student, :active_all => 1)
    course(:course_name => "Course 2", :active_all => 1)
    @course.update_attributes(:start_at => 2.days.from_now, :conclude_at => 4.days.from_now, :restrict_enrollments_to_course_dates => true)
    e2 = student_in_course(:user => @student, :active_all => 1)
    e1.state.should == :active
    e1.state_based_on_date.should == :active
    e2.state.should == :active
    e2.state_based_on_date.should == :inactive

    user_session(@student, @pseudonym)

    get "/"
    page = Nokogiri::HTML(response.body)
    list = page.css(".menu-item-drop-column-list li")
    list.length.should == 1
    list[0].text.should match /Course 1/
    list[0].text.should_not match /Course 2/
    page.css(".menu-item-drop-padded").should be_empty

    get "/courses"
    page = Nokogiri::HTML(response.body)
    active_enrollments = page.css(".current_enrollments li")
    active_enrollments.length.should == 1
    active_enrollments[0]['class'].should match /active/

    page.css(".past_enrollments li").should be_empty
  end

  it "should include see all enrollments link for date completed courses" do
    @student = user_with_pseudonym
    course(:course_name => "Course 1", :active_all => 1)
    e1 = student_in_course(:user => @student, :active_all => 1)
    course(:course_name => "Course 2", :active_all => 1)
    @course.update_attributes(:start_at => 4.days.ago, :conclude_at => 2.days.ago, :restrict_enrollments_to_course_dates => true)
    e2 = student_in_course(:user => @student, :active_all => 1)
    e1.state.should == :active
    e1.state_based_on_date.should == :active
    e2.state.should == :active
    e2.state_based_on_date.should == :completed

    user_session(@student, @pseudonym)

    get "/"
    page = Nokogiri::HTML(response.body)
    list = page.css(".menu-item-drop-column-list li")
    list.length.should == 1
    list[0].text.should match /Course 1/
    list[0].text.should_not match /Course 2/
    page.css(".menu-item-drop-padded").should_not be_empty

    get "/courses"
    page = Nokogiri::HTML(response.body)
    active_enrollments = page.css(".current_enrollments li")
    active_enrollments.length.should == 1
    active_enrollments[0]['class'].should match /active/

    past_enrollments = page.css(".past_enrollments li")
    past_enrollments.length.should == 1
    past_enrollments[0]['class'].should match /completed/
  end
end
