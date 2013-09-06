define [
  'compiled/views/PaginatedCollectionView'
  'compiled/views/conversations/MessageView'
  'jst/conversations/messageList'
], (PaginatedCollectionView, MessageView, template) ->

  class MessageListView extends PaginatedCollectionView

    tagName: 'div'

    itemView: MessageView

    template: template

    course: {}

    events:
      'click': 'onClick'

    onClick: (e) ->
      return unless e.target is @el
      @collection.each((m) -> m.set('selected', false))

    updateCourse: (course) ->
      @course = course

    updateMessage: (message, thread) =>
      currentThread = @collection.get(thread.id)
      currentThread.set
        last_message:  thread.last_message
        last_authored_message_at: new Date().toString()
        message_count: currentThread.get('messages').length
      @collection.sort()
      @render()
      currentThread.view.select()

    afterRender: ->
      super
      @$('.current-context').text(@course.name)
      @$('.list-header')[if @course.name then 'show' else 'hide']()
