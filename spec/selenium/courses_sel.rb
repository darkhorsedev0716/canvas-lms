require File.expand_path(File.dirname(__FILE__) + '/common')

shared_examples_for "course selenium tests" do
  it_should_behave_like "in-process server selenium tests"

  it "should properly hide the wizard and remember its hidden state" do
    course_with_teacher_logged_in

    get "/getting_started?fresh=1"
    driver.find_element(:css, ".save_button").click
    wizard_box = driver.find_element(:id, "wizard_box")
    keep_trying_until { wizard_box.displayed? }
    wizard_box.find_element(:css, ".close_wizard_link").click

    driver.navigate.refresh
    sleep 1 # we need to give the wizard a chance to pop up
    wizard_box = driver.find_element(:id, "wizard_box")
    wizard_box.displayed?.should be_false
  end

  it "should allow content export downloads" do
    course_with_teacher_logged_in
    get "/courses/#{@course.id}/content_exports"
    driver.find_element(:css, "button.submit_button").click
    job = Delayed::Job.last(:conditions => { :tag => 'ContentExport#export_course_without_send_later' })
    export = keep_trying_until { ContentExport.last }
    export.export_course_without_send_later
    new_download_link = keep_trying_until { driver.find_element(:css, "div#exports a") }
    url = new_download_link.attribute 'href'
    url.should match(%r{/files/\d+/download\?verifier=})
  end

  it "should correctly update the course quota" do
    course_with_admin_logged_in
    
    # first try setting the quota explicitly
    get "/courses/#{@course.id}/details"
    form = driver.find_element(:css, "#course_form")
    form.find_element(:css, ".edit_course_link").click
    quota_input = form.find_element(:css, "input#course_storage_quota_mb")
    quota_input.clear
    quota_input.send_keys("10")
    form.find_element(:css, 'button[type="submit"]').click
    keep_trying_until { driver.find_element(:css, ".loading_image_holder").nil? rescue true }
    form.find_element(:css, ".course_info.storage_quota_mb").text.should == "10"
    
    # then try just saving it (without resetting it)
    get "/courses/#{@course.id}/details"
    form = driver.find_element(:css, "#course_form")
    form.find_element(:css, ".course_info.storage_quota_mb").text.should == "10"
    form.find_element(:css, ".edit_course_link").click
    form.find_element(:css, 'button[type="submit"]').click
    keep_trying_until { driver.find_element(:css, ".loading_image_holder").nil? rescue true }
    form.find_element(:css, ".course_info.storage_quota_mb").text.should == "10"
    
    # then make sure it's right after a reload
    get "/courses/#{@course.id}/details"
    form = driver.find_element(:css, "#course_form")
    form.find_element(:css, ".course_info.storage_quota_mb").text.should == "10"
    @course.reload
    @course.storage_quota.should == 10.megabytes
  end

  it "should allow moving a student to a different section" do
    # this spec does lots of find_element where we expect that it won't exist.
    driver.manage.timeouts.implicit_wait = 0
    
    c = course :active_course => true
    users = {:plain => {}, :sis => {}}
    [:plain, :sis].each do |sis_type|
      [:student, :observer, :ta, :teacher].each do |enrollment_type|
        user = {
            :username => "#{enrollment_type}+#{sis_type}@example.com",
            :password => "#{enrollment_type}#{sis_type}1"
        }
        user[:user] = user_with_pseudonym :active_user => true,
          :username => user[:username],
          :password => user[:password]
        user[:enrollment] = c.enroll_user(user[:user], "#{enrollment_type.to_s.capitalize}Enrollment", :enrollment_state => 'active')
        if sis_type == :sis
          user[:enrollment].sis_source_id = "#{enrollment_type}.sis.1"
          user[:enrollment].save!
        end
        users[sis_type][enrollment_type] = user
      end
    end
    admin = {
      :username => 'admin@example.com',
      :password => 'admin1'
    }
    admin[:user] = account_admin_user :active_user => true
    user_with_pseudonym :user=> admin[:user],
      :username => admin[:username],
      :password => admin[:password]
    users[:plain][:admin] = admin

    section = c.course_sections.create!(:name => 'M/W/F')

    users[:plain].each do |user_type, logged_in_user|
      # Students and Observers can't do anything
      next if user_type == :student || user_type == :observer
      create_session(logged_in_user[:user].pseudonyms.first, false)

      get "/courses/#{c.id}/details"

      driver.find_element(:css, '#tab-users-link').click

      users.each do |sis_type, users2|
        users2.each do |enrollment_type, user|
          # Admin isn't actually enrolled
          next if enrollment_type == :admin
          # You can't move yourself
          next if user == logged_in_user

          enrollment = user[:enrollment]
          enrollment_element = driver.find_element(:css, "#enrollment_#{enrollment.id}")
          section_label = enrollment_element.find_element(:css, ".section") rescue nil
          section_dropdown = enrollment_element.find_element(:css, ".enrollment_course_section_form #course_section_id") rescue nil
          edit_section_link = enrollment_element.find_element(:css, ".edit_section_link") rescue nil
          unenroll_user_link = enrollment_element.find_element(:css, ".unenroll_user_link") rescue nil

          # Observers don't have a section
          if enrollment_type == :observer
            edit_section_link.nil?.should be_true
            section_label.nil?.should be_true
            next
          end
          section_label.nil?.should be_false
          section_label.displayed?.should be_true

          # "hover" over the user to make the links appear
          driver.execute_script("$('.user_list #enrollment_#{enrollment.id} .links').css('visibility', 'visible')")
          # All users can manage students; admins and teachers can manage all enrollment types
          can_modify = enrollment_type == :student || [:admin, :teacher].include?(user_type)
          if sis_type == :plain || logged_in_user == admin
            section_dropdown.displayed?.should be_false

            if can_modify
              edit_section_link.nil?.should be_false
              unenroll_user_link.nil?.should be_false

              # Move sections
              edit_section_link.click
              section_label.displayed?.should be_false
              section_dropdown.displayed?.should be_true
              section_dropdown.find_element(:css, "option[value=\"#{section.id.to_s}\"]").click

              keep_trying_until { !section_dropdown.displayed? }

              enrollment.reload
              enrollment.course_section_id.should == section.id
              section_label.displayed?.should be_true
              section_label.text.should == section.name

              # reset this enrollment for the next user
              enrollment.course_section = c.default_section
              enrollment.save!
            else
              edit_section_link.nil?.should be_true
              unenroll_user_link.nil?.should be_true
            end
          else
            edit_section_link.nil?.should be_true
            if can_modify
              unenroll_user_link.nil?.should be_false
              unenroll_user_link.attribute(:class).should match(/cant_unenroll/)
            else
              unenroll_user_link.nil?.should be_true
            end
          end
        end
      end
    end
  end

  it "should not redirect to the gradebook when switching courses when viewing a student's grades" do
    teacher = user_with_pseudonym(:username => 'teacher@example.com', :active_all => 1)
    student = user_with_pseudonym(:username => 'student@example.com', :active_all => 1)
    course1 = course_with_teacher_logged_in(:user => teacher, :active_all => 1).course
    student_in_course :user => student, :active_all => 1
    course2 = course_with_teacher(:user => teacher, :active_all => 1).course
    student_in_course :user => student, :active_all => 1
    create_session(teacher.pseudonyms.first, false)

    get "/courses/#{course1.id}/grades/#{student.id}"

    select = driver.find_element(:id, 'course_url')
    options = select.find_elements(:css, 'option')
    options.length.should == 2
    select.click
    find_with_jquery('#course_url option:not([selected])').click

    driver.current_url.should match %r{/courses/#{course2.id}/grades/#{student.id}}
  end
end

describe "course Windows-Firefox-Tests" do
  it_should_behave_like "course selenium tests"
end
