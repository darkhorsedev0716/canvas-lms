define [
  'ic-ajax'
  'ember'
], (ajax, Ember) ->

  clone = (obj) ->
    Em.copy obj, true

  default_grade_response = [{
    "submission": {
        "assignment_id": "1",
        "attachment_id": null,
        "attachment_ids": null,
        "attempt": null,
        "body": null,
        "cached_due_date": "2013-12-19T06:59:59Z",
        "context_code": "course_2",
        "created_at": "2013-12-12T22:57:34Z",
        "grade": "100",
        "grade_matches_current_submission": true,
        "graded_at": "2013-12-16T21:25:44Z",
        "grader_id": "1",
        "group_id": null,
        "has_admin_comment": false,
        "has_rubric_assessment": null,
        "id": "34291",
        "media_comment_id": null,
        "media_comment_type": null,
        "media_object_id": null,
        "process_attempts": 0,
        "processed": null,
        "published_grade": "150",
        "published_score": 100.0,
        "quiz_submission_id": null,
        "score": 100.0,
        "student_entered_score": null,
        "submission_comments_count": null,
        "submission_type": null,
        "submitted_at": null,
        "turnitin_data": null,
        "updated_at": "2013-12-16T21:25:45Z",
        "url": null,
        "user_id": "1",
        "workflow_state": "graded",
        "submission_history": [{
            "submission": {
                "assignment_id": 1,
                "attachment_id": null,
                "attachment_ids": null,
                "attempt": null,
                "body": null,
                "cached_due_date": "2013-12-19T06:59:59Z",
                "context_code": "course_2",
                "created_at": "2013-12-12T22:57:34Z",
                "grade": "100",
                "grade_matches_current_submission": true,
                "graded_at": "2013-12-16T21:25:44Z",
                "grader_id": 1,
                "group_id": null,
                "has_admin_comment": false,
                "has_rubric_assessment": null,
                "id": 34291,
                "media_comment_id": null,
                "media_comment_type": null,
                "media_object_id": null,
                "process_attempts": 0,
                "processed": null,
                "published_grade": "150",
                "published_score": 100.0,
                "quiz_submission_id": null,
                "score": 100.0,
                "student_entered_score": null,
                "submission_comments_count": null,
                "submission_type": null,
                "submitted_at": null,
                "turnitin_data": null,
                "updated_at": "2013-12-16T21:25:45Z",
                "url": null,
                "user_id": 1,
                "workflow_state": "graded",
                "versioned_attachments": []
            }
        }],
        "submission_comments": [],
        "attachments": []
    }
  },
  {
    "submission": {
        "assignment_id": "1",
        "attachment_id": null,
        "attachment_ids": null,
        "attempt": null,
        "body": null,
        "cached_due_date": "2013-12-19T06:59:59Z",
        "context_code": "course_1",
        "created_at": "2013-12-12T22:57:35Z",
        "grade": "100",
        "grade_matches_current_submission": true,
        "graded_at": "2013-12-16T21:25:47Z",
        "grader_id": "1",
        "group_id": null,
        "has_admin_comment": false,
        "has_rubric_assessment": null,
        "id": "34292",
        "media_comment_id": null,
        "media_comment_type": null,
        "media_object_id": null,
        "process_attempts": 0,
        "processed": null,
        "published_grade": "100",
        "published_score": 100.0,
        "quiz_submission_id": null,
        "score": 100.0,
        "student_entered_score": null,
        "submission_comments_count": null,
        "submission_type": null,
        "submitted_at": null,
        "turnitin_data": null,
        "updated_at": "2013-12-16T21:25:47Z",
        "url": null,
        "user_id": "2",
        "workflow_state": "graded",
        "submission_history": [{
            "submission": {
                "assignment_id": 1,
                "attachment_id": null,
                "attachment_ids": null,
                "attempt": null,
                "body": null,
                "cached_due_date": "2013-12-19T06:59:59Z",
                "context_code": "course_2",
                "created_at": "2013-12-12T22:57:35Z",
                "grade": "100",
                "grade_matches_current_submission": true,
                "graded_at": "2013-12-16T21:25:47Z",
                "grader_id": 1,
                "group_id": null,
                "has_admin_comment": false,
                "has_rubric_assessment": null,
                "id": 34292,
                "media_comment_id": null,
                "media_comment_type": null,
                "media_object_id": null,
                "process_attempts": 0,
                "processed": null,
                "published_grade": "100",
                "published_score": 100.0,
                "quiz_submission_id": null,
                "score": 100.0,
                "student_entered_score": null,
                "submission_comments_count": null,
                "submission_type": null,
                "submitted_at": null,
                "turnitin_data": null,
                "updated_at": "2013-12-16T21:25:47Z",
                "url": null,
                "user_id": 2,
                "workflow_state": "graded",
                "versioned_attachments": []
            }
        }],
        "submission_comments": [],
        "attachments": []
      }
    }
  ]

  students = [
        {
          user: { id: '1', name: 'Bob' }
          course_section_id: '1'
          user_id: '1'
        }
        {
          user: { id: '2', name: 'Fred' }
          course_section_id: '1'
          user_id: '2'
        }
      ]

  assignmentGroups = [
        {
          id: '1'
          name: 'AG1'
          assignments: [
            {
              id: '1'
              name: 'Eat Soup'
              points_possible: 100
              grading_type: "points"
              submission_types: ["none"]
            }
            {
              id: '2'
              name: 'Drink Water'
              grading_type: "points"
              points_possible: null
            }
          ]
        }
      ]

  submissions = [
        {
          user_id: '1'
          submissions: [
            { id: '1', user_id: '1', assignment_id: '1', grade: '3' }
            { id: '2', user_id: '1', assignment_id: '2', grade: null }
          ]
        }
        {
          user_id: '2'
          submissions: [
            { id: '3', user_id: '2', assignment_id: '1', grade: '9' }
            { id: '4', user_id: '2', assignment_id: '2', grade: null }
          ]
        }
      ]

  sections = [
        { id: '1', name: 'Section 1' }
        { id: '2', name: 'Section 2' }
      ]

  set_default_grade_response: default_grade_response
  students: students
  assignment_groups: assignmentGroups
  submissions: submissions
  sections: sections
  create: (overrides) ->

    window.ENV.GRADEBOOK_OPTIONS = {
      students_url: '/api/v1/enrollments'
      assignment_groups_url: '/api/v1/assignment_groups'
      submissions_url: '/api/v1/submissions'
      sections_url: '/api/v1/sections'
      context_url: '/courses/1'
      context_id: 1
      group_weighting_scheme: "equal"
    }

    ajax.defineFixture window.ENV.GRADEBOOK_OPTIONS.students_url,
      response: clone students
      jqXHR: { getResponseHeader: -> {} }
      textStatus: ''

    ajax.defineFixture window.ENV.GRADEBOOK_OPTIONS.assignment_groups_url,
      response: clone assignmentGroups
      jqXHR: { getResponseHeader: -> {} }
      textStatus: ''

    ajax.defineFixture window.ENV.GRADEBOOK_OPTIONS.submissions_url,
      response: clone submissions
      jqXHR: { getResponseHeader: -> {} }
      textStatus: ''

    ajax.defineFixture window.ENV.GRADEBOOK_OPTIONS.sections_url,
      response: clone sections
      jqXHR: { getResponseHeader: -> {} }
      textStatus: ''

      #ajax.defineFixture overide.url, override.options for override in overrides?

