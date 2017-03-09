require [
  'jquery'
  'react'
  'react-dom'
  'jsx/assignments/ModerationApp'
  'jsx/assignments/store/configureStore'
  'jsx/context_cards/StudentContextCardTrigger'
], ($, React, ReactDOM, ModerationApp, configureStore) ->

  ModerationAppFactory = React.createFactory ModerationApp

  store = configureStore({
    studentList: {
      selectedCount: 0,
      students: [],
      sort: {
        direction: 'asc',
        column: 'student_name'
      }
    },
    inflightAction: {
      review: false,
      publish: false
    },
    assignment: {
      published: window.ENV.GRADES_PUBLISHED,
      title: window.ENV.ASSIGNMENT_TITLE,
      course_id: window.ENV.COURSE_ID,
    },
    flashMessage: {
      error: false,
      message: '',
      time: Date.now()
    },
    urls: window.ENV.URLS,
  })

  permissions =
    viewGrades: window.ENV.PERMISSIONS.view_grades
    editGrades: window.ENV.PERMISSIONS.edit_grades

  ReactDOM.render(ModerationAppFactory(store: store, permissions: permissions), $('#assignment_moderation')[0])
