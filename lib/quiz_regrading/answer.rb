class QuizRegrader::Answer

  REGRADE_OPTIONS = [
    'full_credit',
    'current_and_previous_correct',
    'current_correct_only',
    'no_regrade'
  ].freeze

  attr_accessor :answer, :question, :regrade_option

  def initialize(answer, question_regrade)
    @answer         = answer
    @question       = question_regrade.quiz_question
    @regrade_option = question_regrade.regrade_option

    unless REGRADE_OPTIONS.include?(regrade_option)
      raise ArgumentError.new("Regrade option not valid!")
    end
  end

  def regrade!
    return 0 if regrade_option == 'no_regrade'
    previous_score = points
    score = send("mark_#{regrade_option}!")
    answer[:regrade_option] = regrade_option
    answer[:score_before_regrade] = previous_score unless points == previous_score
    answer[:question_id] = question.id
    score
  end

  private

  def mark_full_credit!
    return 0 if correct?

    answer[:correct] = true
    points_possible - points
  end

  def mark_current_and_previous_correct!
    return 0 if correct?

    previously_partial = partial?
    previous_points    = points
    regrade_and_merge_answer!

    # previously partial correct
    if previously_partial
      points_possible - previous_points

    # now correct
    elsif correct?
      points
    else
      0
    end
  end

  def mark_current_correct_only!
    previously_partial = partial?
    previously_correct = correct?
    previous_points    = points
    regrade_and_merge_answer!

    # now fully correct
    if !previously_correct && correct?
      points_possible - previous_points

    # now partial correct
    elsif previously_correct && partial?
      -(points_possible - points)

    # no longer correct
    elsif previously_correct && !correct?
      -previous_points
    else
      0
    end
  end

  def correct?
    answer[:correct] == true
  end

  def partial?
    answer[:correct] == "partial"
  end

  def points
    answer[:points] || 0
  end

  def points_possible
    question_data[:points_possible] || 0
  end

  def question_data
    question.question_data
  end

  def regrade_and_merge_answer!
    question_id = question.id

    fake_submission_data = if question_data[:question_type] == 'multiple_answers_question'
      hash = {}
      answer.each { |k,v| hash["question_#{question_id}_#{k}"] = v if /answer/ =~ k.to_s }
      answer.merge(hash)
    else
      answer.merge("question_#{question_id}" => answer[:text])
    end

    question_data.merge!(id: question_id, question_id: question_id)
    newly_scored_data = QuizSubmission.score_question(question_data, fake_submission_data)

    # clear the answer data and modify it in-place with the newly scored data
    answer.clear
    answer.merge!(newly_scored_data)
  end
end
