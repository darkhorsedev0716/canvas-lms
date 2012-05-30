define ['Backbone'], ({Model}) ->

  class Discussion extends Model

    url: ->
      "/api/v1/courses/#{@get 'course_id'}/discussion_topics"

    defaults:
      title: 'No title'
      message: 'No message'
      discussion_type: 'side_comment'
      delayed_post_at: null
      podcast_enabled: false
      podcast_has_student_posts: false
      require_initial_post: false
      assignment: null
        ###
        due_at: null
        points_possible: null
        ###
      is_announcement: false

