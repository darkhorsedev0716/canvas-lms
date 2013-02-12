class DiscussionTopicPresenter
  attr_reader :topic, :assignment, :user, :override_list

  include TextHelper

  def initialize(discussion_topic = DiscussionTopic.new, current_user = User.new)
    @topic = discussion_topic
    @user  = current_user

    @assignment = if @topic.for_assignment?
      AssignmentOverrideApplicator.assignment_overridden_for(@topic.assignment, @user)
    else
      nil
    end

    @override_list = if @topic.for_assignment?
      OverrideListPresenter.new(topic.assignment, user)
    else
      nil
    end
  end

  # Public: Return a presenter using an unoverridden copy of the topic's assignment
  #
  # Returns a DiscussionTopicPresenter
  def unoverridden
    self.class.new(@topic, nil)
  end
  
  # Public: Return a date string for the discussion assignment's lock at date.
  #
  # date_hash - A due date as a hash.
  #
  # Returns a date or date/time string.
  def lock_at(date_hash = {})
    override_list.lock_at(date_hash)
  end

  def unlock_at(date_hash = {})
    override_list.unlock_at(date_hash)
  end

  def due_at(date_hash = {})
    override_list.due_at(date_hash)
  end

  # Public: Determine if multiple due dates are visible to user.
  #
  # Returns a boolean
  def multiple_due_dates?
    override_list.multiple_due_dates?
  end
  
  # Public: Return all due dates visible to user, filtering out assignment info
  #   if it isn't needed (e.g. if all sections have overrides).
  #
  # Returns an array of due date hashes.
  def visible_due_dates
    override_list.visible_due_dates
  end

  # Public: Determine if the given user has permissions to manage this discussion.
  #
  # Returns a boolean.
  def has_manage_actions?(user)
    can_grade?(user) || show_peer_reviews?(user) || should_show_rubric?(user)
  end

  # Public: Determine if the given user can grade the discussion's assignment.
  #
  # user - The user whose permissions we're testing.
  #
  # Returns a boolean.
  def can_grade?(user)
    topic.for_assignment? &&
    (assignment.grants_right?(user, nil, :grade) ||
      assignment.context.grants_right?(user, nil, :manage_assignments))
  end

  # Public: Determine if the given user has permissions to view peer reviews.
  #
  # user - The user whose permissions we're testing.
  #
  # Returns a boolean.
  def show_peer_reviews?(user)
    if assignment.present?
      assignment.grants_right?(user, nil, :grade) &&
        assignment.has_peer_reviews?
    else
      false
    end
  end

  # Public: Determine if this discussion's assignment has an attached rubric.
  #
  # Returns a boolean.
  def has_attached_rubric?
    assignment.rubric_association.try(:rubric)
  end

  # Public: Determine if the given user can manage rubrics.
  #
  # user - The user whose permissions we're testing.
  #
  # Returns a boolean.
  def should_show_rubric?(user)
    if assignment
      has_attached_rubric? || assignment.grants_right?(user, nil, :update)
    else
      false
    end
  end

  # Public: Determine if comment feature is disabled for the context/announcement.
  #
  # Returns a boolean.
  def comments_disabled?
    topic.is_a?(Announcement) &&
      topic.context.is_a?(Course) &&
      topic.context.settings[:lock_all_announcements]
  end
end
