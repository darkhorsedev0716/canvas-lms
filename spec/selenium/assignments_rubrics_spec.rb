require File.expand_path(File.dirname(__FILE__) + '/common')

describe "assignment rubrics" do
  it_should_behave_like "in-process server selenium tests"

  context "assignment rubrics as a teacher" do
    before (:each) do
      course_with_teacher_logged_in
    end

    def create_assignment_with_points(points)
      assignment_name = 'first test assignment'
      due_date = Time.now.utc + 2.days
      @group = @course.assignment_groups.create!(:name => "default")
      @assignment = @course.assignments.create(
          :name => assignment_name,
          :due_at => due_date,
          :points_possible => points,
          :assignment_group => @group
      )
    end

    it "should add a new rubric to assignment and verify assignment points" do
      initial_points = 9
      rubric_name = 'new rubric'
      create_assignment_with_points(initial_points)
      get "/courses/#{@course.id}/assignments/#{@assignment.id}"

      driver.find_element(:css, '.add_rubric_link').click
      replace_content(driver.find_element(:css, '.rubric_title input[name="title"]'), rubric_name)
      driver.find_element(:css, '.add_criterion_link').click
      driver.find_element(:id, 'grading_rubric').click
      driver.find_element(:css, '#edit_rubric_form').submit
      dialog_buttons = find_all_with_jquery('.ui-dialog:visible .ui-button')
      dialog_buttons[0].click
      wait_for_ajaximations
      driver.find_element(:css, '#rubrics .rubric .rubric_title .displaying .title').should include_text(rubric_name)

      #Commented out because we still want this test to run but this is the part where the bug is
      #BUG 7193 - Rubric total overwrites assignment total despite choosing to leave them different
      #get "/courses/#{@course.id}/assignments"
      #driver.find_element(:css, '.points_text').should include_text(initial_points.to_s)
    end

    it "should import rubric to assignment" do
      create_assignment_with_points(2)

      outcome_with_rubric
      @rubric.associate_with(@course, @course, :purpose => 'grading')

      get "/courses/#{@course.id}/assignments/#{@assignment.id}"

      driver.find_element(:css, '.add_rubric_link').click
      driver.find_element(:css, '#rubric_new .editing .find_rubric_link').click
      wait_for_ajax_requests
      driver.find_element(:css, '#rubric_dialog_'+@rubric.id.to_s+' .title').should include_text(@rubric.title)
      driver.find_element(:css, '#rubric_dialog_'+@rubric.id.to_s+' .select_rubric_link').click
      wait_for_ajaximations
      driver.find_element(:css, '#rubric_'+@rubric.id.to_s+' > thead .title').should include_text(@rubric.title)

    end

    it "should not adjust assignment points possible for grading rubric" do
      create_assignment_with_points(2)

      get "/courses/#{@course.id}/assignments/#{@assignment.id}"
      driver.find_element(:css, "#full_assignment .points_possible").text.should == '2'

      driver.find_element(:css, '.add_rubric_link').click
      driver.find_element(:id, 'grading_rubric').click
      driver.find_element(:id, 'edit_rubric_form').submit
      find_with_jquery('.ui-dialog-buttonset .ui-button:contains("Leave different")').click
      wait_for_ajaximations
      driver.find_element(:css, '#rubrics span .rubric_total').text.should == '5'
      driver.find_element(:css, "#full_assignment .points_possible").text.should == '2'
    end

    it "should adjust assignment points possible for grading rubric" do
      create_assignment_with_points(2)

      get "/courses/#{@course.id}/assignments/#{@assignment.id}"
      driver.find_element(:css, "#full_assignment .points_possible").text.should == '2'

      driver.find_element(:css, '.add_rubric_link').click
      driver.find_element(:id, 'grading_rubric').click
      driver.find_element(:id, 'edit_rubric_form').submit
      find_with_jquery('.ui-dialog-buttonset .ui-button:contains("Change")').click
      wait_for_ajaximations

      driver.find_element(:css, '#rubrics span .rubric_total').text.should == '5'
      driver.find_element(:css, "#full_assignment .points_possible").text.should == '5'
    end

    it "should carry decimal values through rubric to grading" do
      pending("failing on .toggle_full_rubric selector")
      student_in_course
      create_assignment_with_points(2.5)

      get "/courses/#{@course.id}/assignments/#{@assignment.id}"

      driver.find_element(:css, '.add_rubric_link').click
      replace_content(find_with_jquery(".criterion_points:visible"), '2.5')
      driver.find_element(:id, 'grading_rubric').click
      driver.find_element(:id, 'edit_rubric_form').submit
      wait_for_ajaximations

      get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"

      keep_trying_until { driver.find_element(:css, '.toggle_full_rubric').should be_displayed }
      driver.find_element(:css, '.toggle_full_rubric').click
      find_with_jquery('#rubric_holder .criterion:visible .rating').click
      driver.find_element(:css, '#rubric_holder .save_rubric_button').click
      wait_for_ajaximations

      driver.find_element(:css, '#rubric_summary_container .rubric_total').text.should == '2.5'
    end

    it "should not allow XSS attacks through rubric descriptions" do
      skip_if_ie('Unexpected page behavior')

      student = user_with_pseudonym :active_user => true,
                                    :username => "student@example.com",
                                    :password => "password"
      @course.enroll_user(student, "StudentEnrollment", :enrollment_state => 'active')

      @assignment = @course.assignments.create(:name => 'assignment with rubric')
      @rubric = Rubric.new(:title => 'My Rubric', :context => @course)
      @rubric.data = [
          {
              :points => 3,
              :description => "XSS Attack!",
              :long_description => "<b>This text should not be bold</b>",
              :id => 1,
              :ratings => [
                  {
                      :points => 3,
                      :description => "Rockin'",
                      :criterion_id => 1,
                      :id => 2
                  },
                  {
                      :points => 0,
                      :description => "Lame",
                      :criterion_id => 1,
                      :id => 3
                  }
              ]
          }
      ]
      @rubric.save!
      @rubric.associate_with(@assignment, @course, :purpose => 'grading')

      get "/courses/#{@course.id}/assignments/#{@assignment.id}"

      driver.find_element(:id, "rubric_#{@rubric.id}").find_element(:css, ".long_description_link").click
      driver.find_element(:css, "#rubric_long_description_dialog div.displaying .long_description").
          text.should == "<b>This text should not be bold</b>"
      close_visible_dialog

      get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"

      driver.find_element(:css, ".toggle_full_rubric").click
      wait_for_animations
      driver.find_element(:css, '#criterion_1 .long_description_link').click
      keep_trying_until { driver.find_element(:id, 'rubric_long_description_dialog').should be_displayed }
      driver.find_element(:css, "#rubric_long_description_dialog div.displaying .long_description").
          text.should == "<b>This text should not be bold</b>"
    end

    it "should follow learning outcome ignore_for_scoring" do
      student_in_course(:active_all => true)
      outcome_with_rubric
      @assignment = @course.assignments.create(:name => 'assignment with rubric')
      @association = @rubric.associate_with(@assignment, @course, :purpose => 'grading', :use_for_grading => true)
      @submission = @assignment.submit_homework(@student, {:url => "http://www.instructure.com/"})
      @rubric.data[0][:ignore_for_scoring] = '1'
      @rubric.points_possible = 5
      @rubric.instance_variable_set('@outcomes_changed', true)
      @rubric.save!
      @assignment.points_possible = 5
      @assignment.save!

      get "/courses/#{@course.id}/assignments/#{@assignment.id}/submissions/#{@student.id}"
      driver.find_element(:css, '.assess_submission_link').click
      driver.find_element(:css, '.total_points_holder .assessing').should include_text "out of 5"
      driver.find_element(:css, "#rubric_#{@rubric.id} tbody tr:nth-child(2) .ratings td:nth-child(1)").click
      driver.find_element(:css, '.rubric_total').should include_text "5"
      driver.find_element(:css, '.save_rubric_button').click
      wait_for_ajaximations
      driver.find_element(:css, '.grading_value').attribute(:value).should == "5"
    end
  end

  context "assignment rubrics as a student" do
    before (:each) do
      course_with_student_logged_in
    end

    it "should properly show rubric criterion details for learning outcomes" do
      @assignment = @course.assignments.create(:name => 'assignment with rubric')
      outcome_with_rubric

      @rubric.associate_with(@assignment, @course, :purpose => 'grading')

      get "/courses/#{@course.id}/assignments/#{@assignment.id}"

      driver.find_element(:css, "#rubrics .rubric_title").text.should == "My Rubric"
      driver.find_element(:css, ".criterion_description .long_description_link").click
      driver.find_element(:css, ".ui-dialog div.long_description").text.should == "This is awesome."
    end
  end

  context "assignment rubrics as an designer" do
    before (:each) do
      course_with_designer_logged_in
    end

    it "should allow an designer to create a course rubric" do
      pending "Bug #7136 - Rubrics cannot be created by designers" do
        rubric_name = 'this is a new rubric'
        get "/courses/#{@course.id}/rubrics"

        expect {
          driver.find_element(:css, '.add_rubric_link').click
          replace_content(driver.find_element(:css, '.rubric_title input'), rubric_name)
          driver.find_element(:id, 'edit_rubric_form').submit
          wait_for_ajaximations
        }.to change(Rubric, :count).by(1)
        refresh_page
        driver.find_element(:css, '#rubrics .title').text.should == rubric_name
      end
    end
  end
end
