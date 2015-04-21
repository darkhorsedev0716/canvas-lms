require File.expand_path(File.dirname(__FILE__) + '/helpers/quizzes_common')

describe "quizzes question creation" do

  include_examples "quizzes selenium tests"

  before (:each) do
    course_with_teacher_logged_in
    @last_quiz = start_quiz_question
  end

  it "should create a quiz with a multiple choice question" do
    quiz = @last_quiz
    create_multiple_choice_question
    quiz.reload
    question_data = quiz.quiz_questions[0].question_data
    expect(f("#question_#{quiz.quiz_questions[0].id}")).to be_displayed

    expect(question_data[:answers].length).to eq 4
    expect(question_data[:answers][0][:text]).to eq "Correct Answer"
    expect(question_data[:answers][0][:weight]).to eq 100
    expect(question_data[:answers][0][:comments_html]).to eq "<p>Good job!</p>"
    expect(question_data[:answers][1][:text]).to eq "Wrong Answer #1"
    expect(question_data[:answers][1][:weight]).to eq 0
    expect(question_data[:answers][1][:comments_html]).to eq "<p>Bad job :(</p>"
    expect(question_data[:answers][2][:text]).to eq "Second Wrong Answer"
    expect(question_data[:answers][2][:weight]).to eq 0
    expect(question_data[:answers][3][:text]).to eq "Wrongest Answer"
    expect(question_data[:answers][3][:weight]).to eq 0
    expect(question_data[:points_possible]).to eq 1
    expect(question_data[:question_type]).to eq "multiple_choice_question"
    expect(question_data[:correct_comments_html]).to eq "<p>Good job on the question!</p>"
    expect(question_data[:incorrect_comments_html]).to eq "<p>You know what they say - study long study wrong.</p>"
    expect(question_data[:neutral_comments_html]).to eq "<p>Pass or fail you are a winner!</p>"
  end


  it "should create a quiz question with a true false question" do
    quiz = @last_quiz
    create_true_false_question
    quiz.reload
    keep_trying_until { expect(f("#question_#{quiz.quiz_questions[0].id}")).to be_displayed }

    quiz.reload
    question_data = quiz.quiz_questions[0].question_data
    expect(question_data[:answers][1][:comments_html]).to eq "<p>Good job!</p>"
  end

  it "should create a quiz question with a fill in the blank question" do
    quiz = @last_quiz
    create_fill_in_the_blank_question
    quiz.reload
    expect(f("#question_#{quiz.quiz_questions[0].id}")).to be_displayed
  end

  it "should create a quiz question with a fill in multiple blanks question" do
    quiz = @last_quiz

    question = fj(".question_form:visible")
    click_option('.question_form:visible .question_type', 'Fill In Multiple Blanks')

    replace_content(question.find_element(:css, "input[name='question_points']"), '4')

    type_in_tiny ".question:visible textarea.question_content", 'Roses are [color1], violets are [color2]'

    #check answer select
    select_box = question.find_element(:css, '.blank_id_select')
    select_box.click
    options = select_box.find_elements(:css, 'option')
    expect(options[0].text).to eq 'color1'
    expect(options[1].text).to eq 'color2'

    #input answers for both blank input
    answers = question.find_elements(:css, ".form_answers > .answer")

    replace_content(answers[0].find_element(:css, '.short_answer input'), 'red')
    replace_content(answers[1].find_element(:css, '.short_answer input'), 'green')
    options[1].click
    wait_for_ajaximations
    answers = question.find_elements(:css, ".form_answers > .answer")

    replace_content(answers[2].find_element(:css, '.short_answer input'), 'blue')
    replace_content(answers[3].find_element(:css, '.short_answer input'), 'purple')

    submit_form(question)
    wait_for_ajax_requests

    f('#show_question_details').click
    quiz.reload
    finished_question = f("#question_#{quiz.quiz_questions[0].id}")
    expect(finished_question).to be_displayed

    #check select box on finished question
    select_box = finished_question.find_element(:css, '.blank_id_select')
    select_box.click
    options = select_box.find_elements(:css, 'option')
    expect(options[0].text).to eq 'color1'
    expect(options[1].text).to eq 'color2'
  end

  it "should create a quiz question with a multiple answers question" do
    quiz = @last_quiz

    question = fj(".question_form:visible")
    click_option('.question_form:visible .question_type', 'Multiple Answers')

    type_in_tiny '.question:visible textarea.question_content', 'This is a multiple answer question.'

    answers = question.find_elements(:css, ".form_answers > .answer")

    replace_content(answers[0].find_element(:css, '.select_answer input'), 'first answer')
    replace_content(answers[2].find_element(:css, '.select_answer input'), 'second answer')
    answers[2].find_element(:css, ".select_answer_link").click

    submit_form(question)
    wait_for_ajax_requests

    f('#show_question_details').click
    finished_question = f("#question_#{quiz.quiz_questions[0].id}")
    expect(finished_question).to be_displayed
    expect(finished_question.find_elements(:css, '.answer.correct_answer').length).to eq 2
  end

  it "should create a quiz question with a multiple dropdown question" do
    quiz = @last_quiz

    question = fj(".question_form:visible")
    click_option('.question_form:visible .question_type', 'Multiple Dropdowns')

    type_in_tiny '.question:visible textarea.question_content', 'Roses are [color1], violets are [color2]'

    #check answer select
    select_box = question.find_element(:css, '.blank_id_select')
    select_box.click
    options = select_box.find_elements(:css, 'option')
    expect(options[0].text).to eq 'color1'
    expect(options[1].text).to eq 'color2'

    #input answers for both blank input
    answers = question.find_elements(:css, ".form_answers > .answer")
    answers[0].find_element(:css, ".select_answer_link").click

    replace_content(answers[0].find_element(:css, '.select_answer input'), 'red')
    replace_content(answers[1].find_element(:css, '.select_answer input'), 'green')
    options[1].click
    wait_for_ajaximations
    answers = question.find_elements(:css, ".form_answers > .answer")

    answers[2].find_element(:css, ".select_answer_link").click
    replace_content(answers[2].find_element(:css, '.select_answer input'), 'blue')
    replace_content(answers[3].find_element(:css, '.select_answer input'), 'purple')

    submit_form(question)
    wait_for_ajax_requests

    driver.execute_script("$('#show_question_details').click();")
    quiz.reload
    finished_question = f("#question_#{quiz.quiz_questions[0].id}")
    expect(finished_question).to be_displayed

    #check select box on finished question
    select_box = finished_question.find_element(:css, '.blank_id_select')
    select_box.click
    options = select_box.find_elements(:css, 'option')
    expect(options[0].text).to eq 'color1'
    expect(options[1].text).to eq 'color2'
  end

  it "should create a quiz question with a matching question" do
    quiz = @last_quiz

    question = fj(".question_form:visible")
    click_option('.question_form:visible .question_type', 'Matching')

    type_in_tiny '.question:visible textarea.question_content', 'This is a matching question.'

    answers = question.find_elements(:css, ".form_answers > .answer")

    answers = answers.each_with_index do |answer, i|
      answer.find_element(:name, 'answer_match_left').send_keys("#{i} left side")
      answer.find_element(:name, 'answer_match_right').send_keys("#{i} right side")
    end
    question.find_element(:name, 'matching_answer_incorrect_matches').send_keys('first_distractor')

    submit_form(question)
    wait_for_ajax_requests

    f('#show_question_details').click

    quiz.reload
    finished_question = f("#question_#{quiz.quiz_questions[0].id}")
    expect(finished_question).to be_displayed

    finished_question.find_elements(:css, '.answer_match').each_with_index do |filled_answer, i|
      expect(filled_answer.find_element(:css, '.answer_match_left')).to include_text("#{i} left side")
      expect(filled_answer.find_element(:css, '.answer_match_right')).to include_text("#{i} right side")
    end
  end

  #### Numerical Answer
  it "should create a quiz question with a numerical question" do
    quiz = @last_quiz

    click_option('.question_form:visible .question_type', 'Numerical Answer')
    type_in_tiny '.question:visible textarea.question_content', 'This is a numerical question.'

    quiz_form = f('.question_form')
    answers = quiz_form.find_elements(:css, ".form_answers > .answer")
    replace_content(answers[0].find_element(:name, 'answer_exact'), 5)
    replace_content(answers[0].find_element(:name, 'answer_error_margin'), 2)
    click_option('select.numerical_answer_type:eq(1)', 'Answer in the Range:')
    replace_content(answers[1].find_element(:name, 'answer_range_start'), 5)
    replace_content(answers[1].find_element(:name, 'answer_range_end'), 10)
    submit_form(quiz_form)
    wait_for_ajaximations

    f('#show_question_details').click
    quiz.reload
    finished_question = f("#question_#{quiz.quiz_questions[0].id}")
    expect(finished_question).to be_displayed

  end

  it "should create a quiz question with a formula question" do
    quiz = @last_quiz

    question = fj(".question_form:visible")
    click_option('.question_form:visible .question_type', 'Formula Question')

    type_in_tiny '.question_form:visible textarea.question_content', 'If [x] + [y] is a whole number, then this is a formula question.'

    fj('button.recompute_variables').click
    fj('.supercalc:visible').send_keys('x + y')
    fj('button.save_formula_button').click
    # normally it's capped at 200 (to keep the yaml from getting crazy big)...
    # since selenium tests take forever, let's make the limit much lower
    driver.execute_script("ENV.quiz_max_combination_count = 10")
    fj('.combination_count:visible').send_keys('20') # over the limit
    button = fj('button.compute_combinations:visible')
    button.click
    expect(fj('.combination_count:visible')).to have_attribute(:value, "10")
    keep_trying_until {
      button.text == 'Generate'
    }
    expect(ffj('table.combinations:visible tr').size).to eq 11 # plus header row
    submit_form(question)
    wait_for_ajax_requests

    quiz.reload
    expect(f("#question_#{quiz.quiz_questions[0].id}")).to be_displayed
  end

  it "should create a quiz question with an essay question" do
    quiz = @last_quiz

    question = fj(".question_form:visible")
    click_option('.question_form:visible .question_type', 'Essay Question')

    type_in_tiny '.question:visible textarea.question_content', 'This is an essay question.'
    submit_form(question)
    wait_for_ajax_requests

    quiz.reload
    finished_question = f("#question_#{quiz.quiz_questions[0].id}")
    expect(finished_question).not_to be_nil
    expect(finished_question.find_element(:css, '.text')).to include_text('This is an essay question.')
  end

  it "should create a quiz question with a file upload question" do
    quiz = @last_quiz

    create_file_upload_question

    quiz.reload
    finished_question = f("#question_#{quiz.quiz_questions[0].id}")
    expect(finished_question).not_to be_nil
    expect(finished_question.find_element(:css, '.text')).to include_text('This is a file upload question.')
  end

  it "should create a quiz question with a text question" do
    quiz = @last_quiz

    question = fj(".question_form:visible")
    click_option('.question_form:visible .question_type', 'Text (no question)')

    type_in_tiny '.question_form:visible textarea.question_content', 'This is a text question.'
    submit_form(question)
    wait_for_ajax_requests

    quiz.reload
    finished_question = f("#question_#{quiz.quiz_questions[0].id}")
    expect(finished_question).not_to be_nil
    expect(finished_question.find_element(:css, '.text')).to include_text('This is a text question.')
  end

  it "should create a quiz with a variety of quiz questions" do
    quiz = @last_quiz

    click_questions_tab
    create_multiple_choice_question
    click_new_question_button
    create_true_false_question
    click_new_question_button
    create_fill_in_the_blank_question

    quiz.reload
    refresh_page #making sure the quizzes load up from the database
    click_questions_tab
    3.times do |i|
      keep_trying_until(100) { expect(f("#question_#{quiz.quiz_questions[i].id}")).to be_displayed }
    end
    questions = ff('.display_question')
    expect(questions[0]).to have_class("multiple_choice_question")
    expect(questions[1]).to have_class("true_false_question")
    expect(questions[2]).to have_class("short_answer_question")
  end

  it "should not create an extra, blank, correct answer when you use [answer] as a placeholder" do
    quiz = @last_quiz

    # be a multiple dropdown question
    question = fj(".question_form:visible")
    click_option('.question_form:visible .question_type', 'Multiple Dropdowns')

    # set up a placeholder (this is the bug)
    type_in_tiny '.question:visible textarea.question_content', 'What is the [answer]'

    # check answer select
    select_box = question.find_element(:css, '.blank_id_select')
    select_box.click
    options = select_box.find_elements(:css, 'option')
    expect(options[0].text).to eq 'answer'

    # input answers for the blank input
    answers = question.find_elements(:css, ".form_answers > .answer")
    answers[0].find_element(:css, ".select_answer_link").click

    # make up some answers
    replace_content(answers[0].find_element(:css, '.select_answer input'), 'a')
    replace_content(answers[1].find_element(:css, '.select_answer input'), 'b')

    # save the question
    submit_form(question)
    wait_for_ajax_requests

    # check to see if the questions displays correctly
    f('#show_question_details').click
    quiz.reload
    finished_question = f("#question_#{quiz.quiz_questions[0].id}")
    expect(finished_question).to be_displayed

    # check to make sure extra answers were not generated
    expect(quiz.quiz_questions.first.question_data["answers"].count).to eq 2
    expect(quiz.quiz_questions.first.question_data["answers"].detect { |a| a["text"] == "" }).to be_nil
  end

  it "doesn't allow negative question points" do
    quiz = @last_quiz
    question = fj(".question_form:visible")
    click_option('.question_form:visible .question_type', 'essay_question', :value)

    replace_content(question.find_element(:css, "input[name='question_points']"), '-4')
    submit_form(question)

    wait_for_ajaximations
    expect(question).to be_displayed
    assert_error_box(".question_form:visible input[name='question_points']")
  end

  it "respects character limits on short answer questions" do
    quiz = @last_quiz
    question = fj(".question_form:visible")
    click_option('.question_form:visible .question_type', 'Fill In the Blank')

    replace_content(question.find_element(:css, "input[name='question_points']"), '4')

    answers = question.find_elements(:css, ".form_answers > .answer")
    answer = answers[0].find_element(:css, ".short_answer input")

    short_answer_field = lambda {
      replace_content(answer, 'a'*100)
      driver.execute_script(%{$('.short_answer input:focus').blur();}) unless alert_present?
    }

    keep_trying_until do
      short_answer_field.call
      alert_present?
    end
    alert = driver.switch_to.alert
    expect(alert.text).to match /Answers for fill in the blank questions must be under 80 characters long/
    alert.dismiss
  end

  context "drag and drop reordering" do

    before(:each) do
      resize_screen_to_normal
      quiz_with_new_questions
      create_question_group
    end

    it "should reorder quiz questions" do
      click_questions_tab
      old_data = get_question_data
      drag_question_to_top @quest2.id
      refresh_page
      new_data = get_question_data
      expect(new_data[0][:id]).to eq old_data[1][:id]
      expect(new_data[1][:id]).to eq old_data[0][:id]
      expect(new_data[2][:id]).to eq old_data[2][:id]
    end

    it "should add and remove questions to/from a group" do
      resize_screen_to_default
      # drag it into the group
      click_questions_tab
      drag_question_into_group @quest1.id, @group.id
      refresh_page
      group_should_contain_question(@group, @quest1)

      # drag it out
      click_questions_tab
      drag_question_to_top @quest1.id
      refresh_page
      data = get_question_data
      expect(data[0][:id]).to eq @quest1.id
    end

    it "should reorder questions within a group" do
      resize_screen_to_default
      drag_question_into_group @quest1.id, @group.id
      drag_question_into_group @quest2.id, @group.id
      data = get_question_data_for_group @group.id
      expect(data[0][:id]).to eq @quest2.id
      expect(data[1][:id]).to eq @quest1.id

      drag_question_to_top_of_group @quest1.id, @group.id
      refresh_page
      data = get_question_data_for_group @group.id
      expect(data[0][:id]).to eq @quest1.id
      expect(data[1][:id]).to eq @quest2.id
    end

    it "should reorder groups and questions" do
      click_questions_tab

      old_data = get_question_data
      drag_group_to_top @group.id
      refresh_page
      new_data = get_question_data
      expect(new_data[0][:id]).to eq old_data[2][:id]
      expect(new_data[1][:id]).to eq old_data[0][:id]
      expect(new_data[2][:id]).to eq old_data[1][:id]
    end
  end

  context "quiz attempts" do

    def fill_out_attempts_and_validate(attempts, alert_text, expected_attempt_text)
      wait_for_ajaximations
      click_settings_tab
      sleep 2 # wait for page to load
      quiz_attempt_field = lambda {
        set_value(f('#multiple_attempts_option'), false)
        set_value(f('#multiple_attempts_option'), true)
        set_value(f('#limit_attempts_option'), false)
        set_value(f('#limit_attempts_option'), true)
        replace_content(f('#quiz_allowed_attempts'), attempts)
        driver.execute_script(%{$('#quiz_allowed_attempts').blur();}) unless alert_present?
      }
      keep_trying_until do
        quiz_attempt_field.call
        alert_present?
      end
      alert = driver.switch_to.alert
      expect(alert.text).to eq alert_text
      alert.dismiss
      expect(fj('#quiz_allowed_attempts')).to have_attribute('value', expected_attempt_text) # fj to avoid selenium caching
    end

    it "should not allow quiz attempts that are entered with letters" do
      fill_out_attempts_and_validate('abc', 'Quiz attempts can only be specified in numbers', '')
    end

    it "should not allow quiz attempts that are more than 3 digits long" do
      fill_out_attempts_and_validate('12345', 'Quiz attempts are limited to 3 digits, if you would like to give your students unlimited attempts, do not check Allow Multiple Attempts box to the left', '')
    end

    it "should not allow quiz attempts that are letters and numbers mixed" do
      fill_out_attempts_and_validate('31das', 'Quiz attempts can only be specified in numbers', '')
    end

    it "should allow a 3 digit number for a quiz attempt", :priority => "2" do
      attempts = "123"
      click_settings_tab
      f('#multiple_attempts_option').click
      f('#limit_attempts_option').click
      replace_content(f('#quiz_allowed_attempts'), attempts)
      f('#quiz_time_limit').click
      expect(alert_present?).to be_falsey
      expect(fj('#quiz_allowed_attempts')).to have_attribute('value', attempts) # fj to avoid selenium caching

      expect_new_page_load {
        f('.save_quiz_button').click
        wait_for_ajaximations
        keep_trying_until { expect(f('#quiz_title')).to be_displayed }
      }

      expect(Quizzes::Quiz.last.allowed_attempts).to eq attempts.to_i
    end
  end

  it "should show errors for graded quizzes but not surveys" do
    quiz_with_new_questions
    change_quiz_type_to 'Graded Survey'
    expect_new_page_load {
      save_settings
      wait_for_ajax_requests
    }

    edit_quiz
    click_questions_tab
    edit_and_save_first_multiple_choice_answer 'instructure!'
    expect(error_displayed?).to be_falsey

    refresh_page
    click_questions_tab
    edit_and_save_first_multiple_choice_answer 'yog!'

    click_settings_tab
    change_quiz_type_to 'Graded Quiz'
    expect_new_page_load {
      save_settings
      wait_for_ajax_requests
    }

    edit_quiz
    click_questions_tab
    edit_first_question
    delete_first_multiple_choice_answer
    save_question
    expect(error_displayed?).to be_truthy

    refresh_page
    click_questions_tab
    edit_first_question
    delete_first_multiple_choice_answer
    save_question
    expect(error_displayed?).to be_truthy
  end


  context "quizzes with more than 25 questions", :priority => "2" do

    def quiz_questions_creation
      @q = @course.quizzes.create!(:title => "new quiz")
      26.times do
        @q.quiz_questions.create!(:question_data => {:name => "Quiz Questions", :question_type => 'essay_question', :question_text => 'qq_1', 'answers' => [], :points_possible => 1})
      end
      @q.generate_quiz_data
      @q.workflow_state = 'available'
      @q.save
      @q.reload
    end

    before (:each) do
      course_with_teacher_logged_in
      quiz_questions_creation
    end

    it "should edit quiz questions" do
      get "/courses/#{@course.id}/quizzes/#{@q.id}/edit"
      click_questions_tab
      driver.execute_script("$('.display_question').first().addClass('hover').addClass('active')")
      fj('.edit_teaser_link').click
      wait_for_ajaximations
      type_in_tiny '.question:visible textarea.question_content', 'This is an essay question.'
      submit_form(fj(".question_form:visible"))
      wait_for_ajax_requests
    end
  end

  context "quiz groups", :priority => "2" do
    it "should add questions from a question bank" do
      quiz_with_new_questions
      click_questions_tab
      f('.find_question_link').click
      wait_for_ajaximations
      f('.select_all_link').click

      click_option('.quiz_group_select', 'new', :value)
      f('#found_question_group_name').send_keys('group1')
      f('#found_question_group_pick').send_keys(2)
      f('#found_question_group_points').send_keys(2)
      submit_dialog("#add_question_group_dialog", '.submit_button')
      wait_for_ajax_requests
      submit_dialog("#find_question_dialog", '.submit_button')
      wait_for_ajax_requests
      expect(f('.quiz_group_form')).to be_displayed
    end
  end
end

