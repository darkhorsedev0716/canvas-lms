require File.expand_path(File.dirname(__FILE__) + '/common')

describe "assignment selenium tests" do
  it_should_behave_like "in-process server selenium tests"

  it "should properly show rubric criterion details for learning outcomes" do
    course_with_student_logged_in
    
    @assignment = @course.assignments.create(:name => 'assignment with rubric')
    @outcome = @course.learning_outcomes.create!(:description => '<p>This is <b>awesome</b>.</p>')
    @rubric = Rubric.new(:title => 'My Rubric', :context => @course)
    @rubric.data = [
      {
        :points => 3,
        :description => "Outcome row",
        :long_description => @outcome.description,
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
        ],
        :learning_outcome_id => @outcome.id
      }
    ]
    @rubric.instance_variable_set('@outcomes_changed', true)
    @rubric.save!
    
    @rubric.associate_with(@assignment, @course, :purpose => 'grading')
    
    get "/courses/#{@course.id}/assignments/#{@assignment.id}"
    
    driver.find_element(:css, "#rubrics tr.rubric_title").text.should == "My Rubric"
    driver.find_element(:css, ".criterion_description .long_description_link").click
    el = driver.find_element(:css, ".ui-dialog div.long_description").text.should == "This is awesome."
  end
  
  it "should highlight mini-calendar dates where stuff is due" do
    course_with_student_logged_in
    
    due_date = Time.now.utc + 2.days
    @assignment = @course.assignments.create(:name => 'assignment', :due_at => due_date)
    
    get "/courses/#{@course.id}/assignments/syllabus"
    
    driver.find_element(:css, ".mini_calendar_day.date_#{due_date.strftime("%m_%d_%Y")}").
      attribute('class').should match /has_event/
  end
  
  it "should not allow XSS attacks through rubric descriptions" do
    course_with_teacher_logged_in
    
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
    driver.find_element(:id, "rubric_long_description_dialog").
           find_element(:css, "div.displaying .long_description").
           text.should == "<b>This text should not be bold</b>"
    
    get "/courses/#{@course.id}/gradebook/speed_grader?assignment_id=#{@assignment.id}"
    
    driver.find_element(:css, ".toggle_full_rubric").click
    driver.find_element(:id, "rubric_#{@rubric.id}").find_element(:css, ".long_description_link").click
    driver.find_element(:id, "rubric_long_description_dialog").
           find_element(:css, "div.displaying .long_description").
           text.should == "<b>This text should not be bold</b>"
  end
end
