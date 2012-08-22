define [
  'i18n!discussion_topics'
  'Backbone'
  'underscore'
  'jst/DiscussionTopics/SummaryView'
  'jst/_api_avatar'
], (I18n, Backbone, _, template) ->

  class DiscussionTopicSummaryView extends Backbone.View

    template: template

    attributes: ->
      'class': "discussion-topic #{@model.get('read_state')} #{if @model.selected then 'selected' else '' }"
      'data-id': @model.id

    events:
      'change .toggleSelected' : 'toggleSelected'
      'click' : 'openOnClick'

    initialize: ->
      @model.on 'change reset', @render, this
      @model.on 'destroy', @remove, this

    toJSON: ->
      _.extend super,
        permissions: @options.permissions
        selected: @model.selected
        unread_count_tooltip: (I18n.t 'unread_count_tooltip', {
          zero: 'No unread replies'
          one: '1 unread reply'
          other: '%{count} unread replies'
        }, count: @model.get('unread_count'))

        reply_count_tooltip: (I18n.t 'reply_count_tooltip', {
          zero: 'No replies',
          one: '1 reply',
          other: '%{count} replies'
        }, count: @model.get('discussion_subentry_count'))

        summary: @model.summary()

    render: ->
      super
      @$el.attr @attributes()
      this

    toggleSelected: ->
      @model.selected = !@model.selected
      @model.trigger 'change:selected'
      @$el.toggleClass 'selected', @model.selected

    openOnClick: (event) ->
      window.location = @model.get('html_url') unless $(event.target).closest(':focusable, label').length
