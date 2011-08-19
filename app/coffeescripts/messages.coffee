$conversations = []
$conversation_list = []
$messages = []
$message_list = []
$form = []
$selected_conversation = null
$last_label = null
MessageInbox = {}

class TokenInput
  constructor: (@node, @options) ->
    @node.data('token_input', this)
    @fake_input = $('<div />')
      .css('font-family', @node.css('font-family'))
      .insertAfter(@node)
      .addClass('token_input')
      .bind('selectstart', false)
      .click => @input.focus()
    @node_name = @node.attr('name')
    @node.removeAttr('name').hide().change =>
      @tokens.html('')
      @change?(@token_values())

    @placeholder = $('<span />')
    @placeholder.text(@options.placeholder)
    @placeholder.appendTo(@fake_input) if @options.placeholder

    @tokens = $('<ul />')
      .appendTo(@fake_input)
    @tokens.click (e) =>
      if $token = $(e.target).closest('li')
        $close = $(e.target).closest('a')
        if $close.length
          $token.remove()
          @change?(@token_values())

    # key capture input
    @input = $('<input />')
      .appendTo(@fake_input)
      .css('width', '20px')
      .css('font-size', @fake_input.css('font-size'))
      .autoGrowInput({comfortZone: 20})
      .focus =>
        @placeholder.hide()
        @active = true
        @fake_input.addClass('active')
      .blur =>
        @active = false
        setTimeout =>
          if not @active
            @fake_input.removeClass('active')
            @placeholder.showIf @val() is '' and not @tokens.find('li').length
            @selector?.blur?()
        , 50
      .keydown (e) =>
        @input_keydown(e)
      .keyup (e) =>
        @input_keyup(e)

    if @options.selector
      type = @options.selector.type ? TokenSelector
      delete @options.selector.type
      if @browser = @options.selector.browser
        delete @options.selector.browser
        $('<a class="browser">browse</a>')
          .click =>
            if @selector.browse(@browser.data)
              @fake_input.addClass('browse')
          .prependTo(@fake_input)
      @selector = new type(this, @node.attr('finder_url'), @options.selector)

    @base_exclude = []

    @resize()

  resize: () ->
    @fake_input.css('width', @node.css('width'))

  add_token: (data) ->
    val = data?.value ? @val()
    id = 'token_' + val
    unless @tokens.find('#' + id).length
      $token = $('<li />')
      text = data?.text ? @val()
      $token.attr('id', id)
      $text = $('<div />')
      $text.text(text)
      $token.append($text)
      $close = $('<a />')
      $token.append($close)
      $token.append($('<input />')
        .attr('type', 'hidden')
        .attr('name', @node_name + '[]')
        .val(val)
      )
      @tokens.append($token)
    @val('') unless data?.no_clear
    @placeholder.hide()
    @change?(@token_values())
    @selector?.reposition()

  has_token: (data) ->
    @tokens.find('#token_' + (data?.value ? data)).length > 0

  remove_token: (data) ->
    id = 'token_' + (data?.value ? data)
    @tokens.find('#' + id).remove()
    @change?(@token_values())
    @selector?.reposition()

  remove_last_token: (data) ->
    @tokens.find('li').last().remove()
    @change?(@token_values())
    @selector?.reposition()

  input_keydown: (e) ->
    @keyup_action = false
    if @selector
      if @selector?.capture_keydown(e)
        e.preventDefault()
        return false
      else # as soon as we start typing, we are no longer in browse mode
        @fake_input.removeClass('browse')
    else if e.which in @delimiters ? []
      @keyup_action = @add_token
      e.preventDefault()
      return false
    true

  token_values: ->
    input.value for input in @tokens.find('input')

  input_keyup: (e) ->
    @keyup_action?()

  bottom_offset: ->
    offset = @fake_input.offset()
    offset.top += @fake_input.height() + 2
    offset

  focus: ->
    @input.focus()

  val: (val) ->
    if val?
      if val isnt @input.val()
        @input.val(val).change()
        @selector?.reposition()
    else
      @input.val()

  caret: ->
    if @input[0].selectionStart?
      start = @input[0].selectionStart
      end = @input[0].selectionEnd
    else
      val = @val()
      range = document.selection.createRange().duplicate()
      range.moveEnd "character", val.length
      start = if range.text == "" then val.length else val.lastIndexOf(range.text)

      range = document.selection.createRange().duplicate()
      range.moveStart "character", -val.length
      end = range.text.length
    if start == end
      start
    else
      -1

   selector_closed: ->
     @fake_input.removeClass('browse')

$.fn.tokenInput = (options) ->
  @each ->
    new TokenInput $(this), $.extend(true, {}, options)

class TokenSelector

  constructor: (@input, @url, @options={}) ->
    @stack = []
    @query_cache = {}
    @container = $('<div />').addClass('autocomplete_menu')
    @menu = $('<div />').append(@list = @new_list())
    @container.append($('<div />').append(@menu))
    @container.css('top', 0).css('left', 0)
    @mode = 'input'
    $('body').append(@container)

    @reposition = =>
      offset = @input.bottom_offset()
      @container.css('top', offset.top)
      @container.css('left', offset.left)
    $(window).resize @reposition
    @close()

  browse: (data) ->
    unless @ui_locked
      @input.val('')
      @close()
      @fetch_list(data: data)
      true

  new_list: ->
    $list = $('<div><ul class="heading"></ul><ul></ul></div>')
    $list.find('ul')
      .mousemove (e) =>
        return if @ui_locked
        $li = $(e.target).closest('li')
        $li = null unless $li.hasClass('selectable')
        @select($li)
      .mousedown (e) =>
        # sooper hacky... prevent the menu closing on scrollbar drag
        setTimeout =>
          @input.focus()
        , 0
      .click (e) =>
        return if @ui_locked
        $li = $(e.target).closest('li')
        $li = null unless $li.hasClass('selectable')
        @select($li)
        if @selection
          if $(e.target).closest('a.expand').length
            if @selection_expanded()
              @collapse()
            else
              @expand_selection()
          else if @selection_toggleable() and $(e.target).closest('a.toggle').length
            @toggle_selection()
          else if not @selection.hasClass('expanded')
            @toggle_selection(on)
            @clear()
            @close()
        @input.focus()
    $list

  capture_keydown: (e) ->
    return true if @ui_locked
    switch e.originalEvent?.keyIdentifier ? e.which
      when 'Backspace', 'U+0008', 8
        if @input.val() is ''
          if @list_expanded()
            @collapse()
          else if @menu.is(":visible")
            @close()
          else
            @input.remove_last_token()
          return true
      when 'Tab', 'U+0009', 9
        @toggle_selection(on) if @selection and not @selection.hasClass('expanded')
        @clear()
        @close()
        return true if @selection
      when 'Enter', 13
        if @selection and not @selection.hasClass('expanded')
          @toggle_selection(on)
          @clear()
        @close()
        return true
      when 'Shift', 16 # noop, but we don't want to set the mode to input
        return false
      when 'Esc', 'U+001B', 27
        if @menu.is(":visible")
          @close()
          return true
        else
          return false
      when 'U+0020', 32 # space
        if @selection_toggleable() and @mode is 'menu'
          @toggle_selection()
          return true
      when 'Left', 37
        if @list_expanded() and @input.caret() is 0
          if @selection_expanded() or @input.val() is ''
            @collapse()
          else
            @select(@list.find('li').first())
          return true
      when 'Up', 38
        @select_prev()
        return true
      when 'Right', 39
        return true if @input.caret() is @input.val().length and @expand_selection()
      when 'Down', 40
        @select_next()
        return true
      when 'U+002B', 187, 107 # plus
        if @selection_toggleable() and @mode is 'menu'
          @toggle_selection(on)
          return true
      when 'U+002D', 189, 109 # minus
        if @selection_toggleable() and @mode is 'menu'
          @toggle_selection(off)
          return true
    @mode = 'input'
    @fetch_list()
    false

  fetch_list: (options={}, @ui_locked=false) ->
    clearTimeout @timeout if @timeout?
    @timeout = setTimeout =>
      delete @timeout
      post_data = @prepare_post(options.data ? {})
      this_query = JSON.stringify(post_data)
      if this_query is @last_applied_query
        @ui_locked = false
        return
      else if @query_cache[this_query]
        @last_applied_query = this_query
        @last_search = post_data.search
        @render_list(@query_cache[this_query], options)
        return

      if post_data.search is '' and not @list_expanded() and not options.data
        return @render_list([])
      $.ajaxJSON @url, 'POST', $.extend({}, post_data),
        (data) =>
          @query_cache[this_query] = data
          if JSON.stringify(@prepare_post(options.data ? {})) is this_query # i.e. only if it hasn't subsequently changed (and thus triggered another call)
            @last_applied_query = this_query
            @last_search = post_data.search
            @render_list(data, options)
          else
            @ui_locked=false
        ,
        (data) =>
          @ui_locked=false
    , 100

  open: ->
    @container.show()
    @reposition()

  close: ->
    @ui_locked = false
    @container.hide()
    delete @last_applied_query
    for [$selection, $list, query, search], i in @stack
      @list.remove()
      @list = $list.css('height', 'auto')
    @stack = []
    @menu.css('left', 0)
    @select(null)
    @input.selector_closed()

  clear: ->
    @input.val('')

  blur: ->
    @close()

  list_expanded: ->
    if @stack.length then true else false

  selection_expanded: ->
    @selection?.hasClass('expanded') ? false

  selection_expandable: ->
    @selection?.hasClass('expandable') ? false

  selection_toggleable: ->
    @selection?.hasClass('toggleable') ? false

  expand_selection: ->
    return false unless @selection_expandable() and not @selection_expanded()
    @stack.push [@selection, @list, @last_applied_query, @last_search]
    @clear()
    @menu.css('width', ((@stack.length + 1) * 100) + '%')
    @fetch_list({expand: true}, true)

  collapse: ->
    return false unless @list_expanded()
    [$selection, $list, @last_applied_query, @last_search] = @stack.pop()
    @ui_locked = true
    $list.css('height', 'auto')
    @menu.animate {left: '+=' + @menu.parent().css('width')}, 'fast', =>
      @input.val(@last_search)
      @list.remove()
      @list = $list
      @select $selection
      @ui_locked = false
      # TODO: if any in this list are now selected, we should requery so
      # as to remove them

  toggle_selection: (state) ->
    return false unless state? or @selection_toggleable()
    id = @selection.data('id')
    state = !@input.has_token(value: id) unless state?
    if state
      @selection.addClass('on') if @selection_toggleable()
      @input.add_token value: id, text: @selection.find('b').text(), no_clear: true
    else
      @selection.removeClass('on')
      @input.remove_token value: id

  select: ($node, preserve_mode = false) ->
    return if $node?[0] is @selection?[0]
    @selection?.removeClass('active')
    @selection = if $node?.length
      $node.addClass('active')
      $node.scrollIntoView(ignore: {border: on})
      $node
    else
      null
    @mode = (if $node then 'menu' else 'input') unless preserve_mode

  select_next: (preserve_mode = false) ->
    @select(if @selection
      if @selection.next().length
        @selection.next()
      else if @selection.parent('ul').next().length
        @selection.parent('ul').next().find('li').first()
      else
        null
    else
      @list.find('li:first')
    , preserve_mode)

  select_prev: ->
    @select(if @selection
      if @selection?.prev().length
        @selection.prev()
      else if @selection.parent('ul').prev().length
        @selection.parent('ul').prev().find('li').last()
      else
        null
    else
      @list.find('li:last')
    )

  populate_row: ($node, data, options={}) ->
    if @options.populator
      @options.populator($node, data, options)
    else
      $node.data('id', data.text)
      $node.text(data.text)
    $node.addClass('first') if options.first
    $node.addClass('last') if options.last

  render_list: (data, options={}) ->
    if data.length or @list_expanded()
      @open()
    else
      @ui_locked = false
      @close()
      return

    if options.expand
      $list = @new_list()
    else
      $list = @list

    @selection = null
    $uls = $list.find('ul')
    $uls.html('')
    $heading = $uls.first()
    $body = $uls.last()
    if data.length
      for row, i in data
        $li = $('<li />').addClass('selectable')
        @populate_row($li, row, {level: @stack.length, first: (i is 0), last: (i is data.length - 1)})
        $li.addClass('on') if $li.hasClass('toggleable') and @input.has_token($li.data('id'))
        $body.append($li)
    else
      $message = $('<li class="message first last"></li>')
      $message.text(@options.messages?.no_results ? '')
      $body.append($message)

    if @list_expanded()
      $li = @stack[@stack.length - 1][0].clone()
      $li.addClass('expanded').removeClass('active first last')
      $heading.append($li).show()
    else
      $heading.hide()

    if options.expand
      $list.insertAfter(@list)
      @menu.animate {left: '-=' + @menu.parent().css('width')}, 'fast', =>
        @list.animate height: '1px', 'fast', =>
          @ui_locked = false
        @list = $list
        @select_next(true)
    else
      @select_next(true)
      @ui_locked = false

  prepare_post: (data) ->
    post_data = $.extend(data, {search: @input.val()})
    post_data.exclude = @input.base_exclude.concat(if @stack.length then [] else @input.token_values())
    post_data.context = @stack[@stack.length - 1][0].data('id') if @list_expanded()
    post_data.limit ?= @options.limiter?(level: @stack.length)
    post_data


# depends on the scrollable ancestor being the first positioned
# ancestor. if it's not, it won't work
$.fn.scrollIntoView = (options = {}) ->
  $container = @offsetParent()
  containerTop = $container.scrollTop()
  containerBottom = containerTop + $container.height()
  elemTop = this[0].offsetTop
  elemBottom = elemTop + $(this[0]).outerHeight()
  if options.ignore?.border
    elemTop += parseInt($(this[0]).css('border-top-width').replace('px', ''))
    elemBottom -= parseInt($(this[0]).css('border-bottom-width').replace('px', ''))
  if elemTop < containerTop
    $container.scrollTop(elemTop)
  else if elemBottom > containerBottom
    $container.scrollTop(elemBottom - $container.height())

I18n.scoped 'conversations', (I18n) ->
  show_message_form = ->
    newMessage = !$selected_conversation?
    $form.find('#recipient_info').showIf newMessage
    $form.find('#group_conversation_info').hide()
    $('#action_compose_message').toggleClass 'active', newMessage

    if newMessage
      $form.find('.audience').html I18n.t('headings.new_message', 'New Message')
      $form.addClass('new')
      $form.find('#action_add_recipients').hide()
      $form.attr action: '/conversations'
    else
      $form.find('.audience').html $selected_conversation.find('.audience').html()
      $form.removeClass('new')
      $form.find('#action_add_recipients').showIf(!$selected_conversation.hasClass('private'))
      $form.attr action: $selected_conversation.find('a.details_link').attr('add_url')

    reset_message_form()
    $form.show().find(':input:visible:first').focus()

  reset_message_form = ->
    $form.find('.audience').html $selected_conversation.find('.audience').html() if $selected_conversation?
    $form.find('input[name!=authenticity_token], textarea').val('').change()
    $form.find(".attachment:visible").remove()
    $form.find(".media_comment").hide()
    $form.find("#action_media_comment").show()
    inbox_resize()

  parse_query_string = (query_string = window.location.search.substr(1)) ->
    hash = {}
    for parts in query_string.split(/\&/)
      [key, value] = parts.split(/\=/, 2)
      hash[decodeURIComponent(key)] = decodeURIComponent(value)
    hash

  is_selected = ($conversation) ->
    $selected_conversation && $selected_conversation.attr('id') == $conversation?.attr('id')

  select_conversation = ($conversation, params={}) ->
    toggle_message_actions(off)

    if is_selected($conversation)
      $selected_conversation.removeClass 'inactive'
      $message_list.find('li.selected').removeClass 'selected'
      return

    $message_list.removeClass('private').hide().html ''
    $message_list.addClass('private') if $conversation?.hasClass('private')

    if $selected_conversation
      $selected_conversation.removeClass 'selected inactive'
      if MessageInbox.scope == 'unread'
        $selected_conversation.fadeOut 'fast', ->
          $(this).remove()
          $('#no_messages').showIf !$conversation_list.find('li').length
      $selected_conversation = null
    if $conversation
      $selected_conversation = $conversation.addClass('selected')

    if $selected_conversation || $('#action_compose_message').length
      show_message_form()
    else
      $form.parent().hide()

    if $selected_conversation
      $selected_conversation.scrollIntoView()
    else
      if params and params.user_id and params.user_name and params.from_conversation_id
        $('#recipients').data('token_input').add_token value: params.user_id, text: params.user_name
        $('#from_conversation_id').val(params.from_conversation_id)
      return

    $form.loadingImage()
    $c = $selected_conversation
    $.ajaxJSON $selected_conversation.find('a.details_link').attr('href'), 'GET', {}, (data) ->
      return unless is_selected($c)
      for user in data.participants when !MessageInbox.user_cache[user.id]
        MessageInbox.user_cache[user.id] = user
        user.html_name = html_name_for_user(user)
      $messages.show()
      i = j = 0
      message = data.messages[0]
      submission = data.submissions[0]
      while message || submission
        if message && (!submission || $.parseFromISO(message.created_at).datetime > $.parseFromISO(submission.updated_at).datetime)
          # there's another message, and the next submission (if any) is not newer than it
          $message_list.append build_message(message)
          message = data.messages[++i]
        else
          # no more messages, or the next submission is newer than the next message
          $message_list.append build_submission(submission)
          submission = data.submissions[++j]
      $form.loadingImage 'remove'
      $message_list.hide().slideDown 'fast'
      if $selected_conversation.hasClass 'unread'
        # we've already done this server-side
        set_conversation_state $selected_conversation, 'read'
    , ->
      $form.loadingImage('remove')

  MessageInbox.shared_contexts_for_user = (user) ->
    shared_contexts = (course.name for course_id in user.course_ids when course = @contexts.courses[course_id]).
                concat(group.name for group_id in user.group_ids when group = @contexts.groups[group_id])
    shared_contexts.join(", ")

  html_name_for_user = (user) ->
    shared_contexts = MessageInbox.shared_contexts_for_user(user)
    $.htmlEscape(user.name) + if shared_contexts.length then " <em>" + $.htmlEscape(shared_contexts) + "</em>" else ''

  build_message = (data) ->
    $message = $("#message_blank").clone(true).attr('id', 'message_' + data.id)
    $message.data('id', data.id)
    $message.addClass(if data.generated
      'generated'
    else if data.author_id is MessageInbox.user_id
      'self'
    else
      'other'
    )
    user = MessageInbox.user_cache[data.author_id]
    if avatar = user?.avatar
      $message.prepend $('<img />').attr('src', avatar).addClass('avatar')
    user.html_name ?= html_name_for_user(user) if user
    user_name = user?.name ? I18n.t('unknown_user', 'Unknown user')
    $message.find('.audience').html user?.html_name || $.h(user_name)
    $message.find('span.date').text $.parseFromISO(data.created_at).datetime_formatted
    $message.find('p').html $.h(data.body).replace(/\n/g, '<br />')
    $pm_action = $message.find('a.send_private_message')
    pm_url = $.replaceTags $pm_action.attr('href'),
      user_id: data.author_id
      user_name: encodeURIComponent(user_name)
      from_conversation_id: $selected_conversation.data('id')
    $pm_action.attr 'href', pm_url
    if data.forwarded_messages?.length
      $ul = $('<ul class="messages"></ul>')
      for submessage in data.forwarded_messages
        $ul.append build_message(submessage)
      $message.append $ul

    $ul = $message.find('ul.message_attachments').detach()
    $media_object_blank = $ul.find('.media_object_blank').detach()
    $attachment_blank = $ul.find('.attachment_blank').detach()
    if data.media_comment? or data.attachments?.length
      $message.append $ul
      if data.media_comment?
        $ul.append build_media_object($media_object_blank, data.media_comment)
      if data.attachments?
        for attachment in data.attachments
          $ul.append build_attachment($attachment_blank, attachment)

    $message

  build_media_object = (blank, data) ->
    $media_object = blank.clone(true).attr('id', 'media_object_' + data.id)
    $media_object.data('id', data.id)
    $media_object.find('span.title').html $.h(data.title)
    $media_object.find('span.media_comment_id').html $.h(data.media_id)
    $media_object

  build_attachment = (blank, data) ->
    $attachment = blank.clone(true).attr('id', 'attachment_' + data.id)
    $attachment.data('id', data.id)
    $attachment.find('span.title').html $.h(data.display_name)
    $link = $attachment.find('a')
    $link.attr('href', $.replaceTags($link.attr('href'), id: data.id, uuid: data.uuid))
    $attachment

  build_submission = (data) ->
    $submission = $("#submission_blank").clone(true).attr('id', 'submission_' + data.id)
    $submission.data('id', data.id)
    $ul = $submission.find('ul')
    $header = $ul.find('li.header')
    href = $.replaceTags($header.find('a').attr('href'), course_id: data.course_id, assignment_id: data.assignment_id, id: data.author_id)
    $header.find('a').attr('href', href)
    user = MessageInbox.user_cache[data.author_id]
    user.html_name ?= html_name_for_user(user) if user
    user_name = user?.name ? I18n.t('unknown_user', 'Unknown user')
    $header.find('.title').html $.h(data.title)
    if data.created_at
      $header.find('span.date').text $.parseFromISO(data.created_at).datetime_formatted
    $header.find('.audience').html user?.html_name || $.h(user_name)
    score = data.score ? I18n.t('not_scored', 'no score')
    $header.find('.score').html(score)
    $comment_blank = $ul.find('.comment').detach()
    index = 0
    initially_shown = 4
    for comment in data.recent_comments
      index++
      comment = build_submission_comment($comment_blank, comment)
      comment.hide() if index > initially_shown
      $ul.append comment
    $more_link = $ul.find('.more').detach()
    if data.recent_comments.length > initially_shown
      $inline_more = $more_link.clone(true)
      $inline_more.find('.hidden').text(data.comment_count - initially_shown)
      $inline_more.attr('title', $.h(I18n.t('titles.expand_inline', "Show more comments")))
      $inline_more.click ->
        submission = $(this).closest('.submission')
        submission.find('.more:hidden').show()
        $(this).hide()
        submission.find('.comment:hidden').slideDown('fast')
        inbox_resize()
        return false
      $ul.append $inline_more
    if data.comment_count > data.recent_comments.length
      $more_link.find('a').attr('href', href).attr('target', '_blank')
      $more_link.find('.hidden').text(data.comment_count - data.recent_comments.length)
      $more_link.attr('title', $.h(I18n.t('titles.view_submission', "Open submission in new window.")))
      $more_link.hide() if data.recent_comments.length > initially_shown
      $ul.append $more_link
    $submission

  build_submission_comment = (blank, data) ->
    $comment = blank.clone(true).attr('id', 'submission_comment_' + data.id)
    $comment.data('id', data.id)
    user = MessageInbox.user_cache[data.author_id]
    if avatar = user?.avatar
      $comment.prepend $('<img />').attr('src', avatar).addClass('avatar')
    user.html_name ?= html_name_for_user(user) if user
    user_name = user?.name ? I18n.t('unknown_user', 'Unknown user')
    $comment.find('.audience').html user?.html_name || $.h(user_name)
    $comment.find('span.date').text $.parseFromISO(data.created_at).datetime_formatted
    $comment.find('p').html $.h(data.body).replace(/\n/g, '<br />')
    $comment

  inbox_action_url_for = ($action, $conversation) ->
    $.replaceTags $action.attr('href'), 'id', $conversation.data('id')

  inbox_action = ($action, options) ->
    $loading_node = options.loading_node ? $action.closest('ul.conversations li')
    $loading_node = $('#conversation_actions').data('selected_conversation') unless $loading_node.length
    defaults =
      loading_node: $loading_node
      url: inbox_action_url_for($action, $loading_node)
      method: 'POST'
      data: {}
    options = $.extend(defaults, options)

    return unless options.before?(options.loading_node, options) ? true
    options.loading_node?.loadingImage()
    $.ajaxJSON options.url,
      options.method,
      options.data,
      (data) ->
        options.loading_node?.loadingImage 'remove'
        options.success?(options.loading_node, data)
      , (data) ->
        options.loading_node?.loadingImage 'remove'
        options.error?(options.loading_node, data)

  add_conversation = (data, append) ->
    $('#no_messages').hide()
    $conversation = $("#conversation_blank").clone(true).attr('id', 'conversation_' + data.id)
    $conversation.data('id', data.id)
    if data.avatar_url
      $conversation.prepend $('<img />').attr('src', data.avatar_url).addClass('avatar')
    $conversation[if append then 'appendTo' else 'prependTo']($conversation_list).click (e) ->
      e.preventDefault()
      set_hash '#/conversations/' + $(this).data('id')
    update_conversation($conversation, data, null)
    $conversation.hide().slideDown('fast') unless append
    $conversation

  update_conversation = ($conversation, data, move_mode='slide') ->
    toggle_message_actions(off)

    $a = $conversation.find('a.details_link')
    $a.attr 'href', $.replaceTags($a.attr('href'), 'id', data.id)
    $a.attr 'add_url', $.replaceTags($a.attr('add_url'), 'id', data.id)
    $conversation.find('.audience').html data.audience if data.audience
    $conversation.find('.actions a').click (e) ->
      e.preventDefault()
      e.stopImmediatePropagation()
      close_menus()
      open_conversation_menu($(this))
    .focus () ->
      close_menus()
      open_conversation_menu($(this))

    if data.message_count?
      $conversation.find('.count').text data.message_count
      $conversation.find('.count').showIf data.message_count > 1
    $conversation.find('span.date').text $.friendlyDatetime($.parseFromISO(data.last_message_at).datetime)
    move_direction = if $conversation.data('last_message_at') > data.last_message_at then 'down' else 'up'
    $conversation.data 'last_message_at', data.last_message_at
    $conversation.data 'label', data.label
    $p = $conversation.find('p')
    $p.text data.last_message
    ($conversation.addClass(property) for property in data.properties) if data.properties.length
    $conversation.addClass('private') if data['private']
    $conversation.addClass('labeled').addClass(data['label']) if data['label']
    $conversation.addClass('unsubscribed') unless data.subscribed
    set_conversation_state $conversation, data.workflow_state
    reposition_conversation($conversation, move_direction, move_mode) if move_mode

  reposition_conversation = ($conversation, move_direction, move_mode) ->
    last_message = $conversation.data('last_message_at')
    $n = $conversation
    if move_direction == 'up'
      $n = $n.prev() while $n.prev() && $n.prev().data('last_message_at') < last_message
    else
      $n = $n.next() while $n.next() && $n.next().data('last_message_at') > last_message
    return if $n == $conversation
    if move_mode is 'immediate'
      $conversation.detach()[if move_direction == 'up' then 'insertBefore' else 'insertAfter']($n).scrollIntoView()
    else
      $dummy_conversation = $conversation.clone().insertAfter($conversation)
      $conversation.detach()[if move_direction == 'up' then 'insertBefore' else 'insertAfter']($n).animate({opacity: 'toggle', height: 'toggle'}, 0)
      $dummy_conversation.animate {opacity: 'toggle', height: 'toggle'}, 200, ->
        $(this).remove()
      $conversation.animate {opacity: 'toggle', height: 'toggle'}, 200, ->
        $conversation.scrollIntoView()

  remove_conversation = ($conversation) ->
    deselect = is_selected($conversation)
    $conversation.fadeOut 'fast', ->
      $(this).remove()
      $('#no_messages').showIf !$conversation_list.find('li').length
      set_hash '' if deselect

  set_conversation_state = ($conversation, state) ->
    $conversation.removeClass('read unread archived').addClass state

  open_conversation_menu = ($node) ->
    $node.parent().addClass('selected').closest('li').addClass('menu_active')
    $container = $('#conversation_actions')
    $container.addClass('selected')

    $conversation = $node.closest('li')
    $container.data('selected_conversation', $conversation)
    $container.find('ul').removeClass('first last').hide()
    $container.find('li').hide()
    $('#action_mark_as_read').parent().showIf $conversation.hasClass('unread')
    $('#action_mark_as_unread').parent().showIf $conversation.hasClass('read')
    $container.find('.label_group').show().find('.label_icon').removeClass('checked')
    $container.find('.label_icon.' + ($conversation.data('label') || 'none')).addClass('checked')
    if $conversation.hasClass('private')
      $('#action_subscribe, #action_unsubscribe').parent().hide()
    else
      $('#action_unsubscribe').parent().showIf !$conversation.hasClass('unsubscribed')
      $('#action_subscribe').parent().showIf $conversation.hasClass('unsubscribed')
    $('#action_forward').parent().show()
    $('#action_archive').parent().showIf MessageInbox.scope != 'archived'
    $('#action_unarchive').parent().showIf MessageInbox.scope == 'archived'
    $('#action_delete').parent().show()
    $('#action_delete_all').parent().show()

    $container.find('li[style*="list-item"]').parent().show()
    $groups = $container.find('ul[style*="block"]')
    if $groups.length
      $($groups[0]).addClass 'first'
      $($groups[$groups.length - 1]).addClass 'last'

    offset = $node.offset()
    $container.css('top', offset.top + ($node.height() * 0.9) - $container.offsetParent().offset().top)
    $container.css('left', offset.left + ($node.width() / 2) - $container.offsetParent().offset().left - ($container.width() / 2))

  close_menus = () ->
    $('#actions .menus > li, #conversation_actions, #conversations .actions').removeClass('selected')
    $('#conversations li.menu_active').removeClass('menu_active')

  open_menu = ($menu) ->
    close_menus()
    unless $menu.hasClass('disabled')
      $div = $menu.parent('li, span').addClass('selected').find('div')
      # TODO: move this out in the DOM so we can center it and not have it get clipped
      offset = -($div.parent().position().left + $div.parent().outerWidth() / 2) + 6 # for box shadow
      offset = -($div.outerWidth() / 2) if offset < -($div.outerWidth() / 2)
      $div.css 'margin-left', offset + 'px'

  inbox_resize = ->
    available_height = $(window).height() - $('#header').outerHeight(true) - ($('#wrapper-container').outerHeight(true) - $('#wrapper-container').height()) - ($('#main').outerHeight(true) - $('#main').height()) - $('#breadcrumbs').outerHeight(true) - $('#footer').outerHeight(true)
    available_height = 425 if available_height < 425
    $('#inbox').height(available_height)
    $message_list.height(available_height - $form.outerHeight(true))
    $conversation_list.height(available_height - $('#actions').outerHeight(true))

  toggle_message_actions = (state) ->
    if state?
      $message_list.find('> li').removeClass('selected')
      $message_list.find('> li :checkbox').attr('checked', false)
    else
      state = !!$message_list.find('li.selected').length
    $('#message_actions').showIf(state)
    $form[if state then 'addClass' else 'removeClass']('disabled')

  set_last_label = (label) ->
    $conversation_list.removeClass('red orange yellow green blue purple').addClass(label) # so that the label hover is correct
    $.cookie('last_label', label)
    $last_label = label

  set_hash = (hash) ->
    if hash isnt location.hash
      location.hash = hash
      $(document).triggerHandler('document_fragment_change', hash)

  $.extend window,
    MessageInbox: MessageInbox

  $(document).ready () ->
    $conversations = $('#conversations')
    $conversation_list = $conversations.find("ul.conversations")
    set_last_label($.cookie('last_label') ? 'red')
    $messages = $('#messages')
    $message_list = $messages.find('ul.messages')
    $form = $('#create_message_form')

    $form.find("textarea").elastic()

    $form.submit (e) ->
      valid = !!($form.find('#body').val() and ($form.find('#recipient_info').filter(':visible').length is 0 or $form.find('.token_input li').length > 0))
      e.stopImmediatePropagation() unless valid
      valid
    $form.formSubmit
      fileUpload: ->
        return $(this).find(".file_input:visible").length > 0
      beforeSubmit: ->
        $(this).loadingImage()
      success: (data) ->
        $(this).loadingImage 'remove'
        if data.conversations # e.g. we just sent bulk private messages
          for conversation in data.conversations
            $conversation = $('#conversation_' + conversation.id)
            update_conversation($conversation, conversation, 'immediate') if $conversation.length
          $.flashMessage(I18n.t('messages_sent', 'Messages Sent'))
        else
          $conversation = $('#conversation_' + data.conversation.id)
          if $conversation.length
            build_message(data.message).prependTo($message_list).slideDown 'fast' if is_selected($conversation)
            update_conversation($conversation, data.conversation)
          else
            add_conversation(data.conversation)
            set_hash '#/conversations/' + data.conversation.id
          $.flashMessage(I18n.t('message_sent', 'Message Sent'))
        reset_message_form()
      error: (data) ->
        $form.find('.token_input').errorBox(I18n.t('recipient_error', 'The course or group you have selected has no valid recipients'))
        $('.error_box').filter(':visible').css('z-index', 10) # TODO: figure out why this is necessary
        $(this).loadingImage 'remove'
    $form.click ->
      toggle_message_actions off

    $('#add_recipients_form').submit (e) ->
      valid = !!($(this).find('.token_input li').length)
      e.stopImmediatePropagation() unless valid
      valid
    $('#add_recipients_form').formSubmit
      beforeSubmit: ->
        $(this).loadingImage()
      success: (data) ->
        $(this).loadingImage 'remove'
        build_message(data.message).prependTo($message_list).slideDown 'fast'
        update_conversation($selected_conversation, data.conversation)
        reset_message_form()
        $(this).dialog('close')
      error: (data) ->
        $(this).loadingImage 'remove'
        $(this).dialog('close')


    $message_list.click (e) ->
      if $(e.target).closest('a.instructure_inline_media_comment').length
        # a.instructure_inline_media_comment clicks have to propagate to the
        # top due to "live" handling; if it's one of those, it's not really
        # intended for us, just let it go
      else
        $message = $(e.target).closest('#messages > ul > li')
        unless $message.hasClass('generated') or $message.hasClass('submission')
          $selected_conversation?.addClass('inactive')
          $message.toggleClass('selected')
          $message.find('> :checkbox').attr('checked', $message.hasClass('selected'))
        toggle_message_actions()

    $('.menus > li > a').click (e) ->
      e.preventDefault()
      open_menu $(this)
    .focus () ->
      open_menu $(this)

    $(document).bind 'mousedown', (e) ->
      unless $(e.target).closest("span.others").find('> span').length
        $('span.others > span').hide()
      close_menus() unless $(e.target).closest(".menus > li, #conversation_actions, #conversations .actions").length

    $('#menu_views').parent().find('li a').click (e) ->
      close_menus()
      $('#menu_views').text $(this).text()

    $('#message_actions').find('a').click (e) ->
      e.preventDefault()

    $('#conversation_actions').find('li a').click (e) ->
      e.preventDefault()
      close_menus()

    $('.action_mark_as_read').click (e) ->
      e.preventDefault()
      e.stopImmediatePropagation()
      inbox_action $(this),
        before: ($node) ->
          set_conversation_state $node, 'read' unless MessageInbox.scope == 'unread'
          true
        success: ($node) ->
          remove_conversation $node if MessageInbox.scope == 'unread'
        error: ($node) ->
          set_conversation_state $node 'unread' unless MessageInbox.scope == 'unread'

    $('.action_mark_as_unread').click (e) ->
      e.preventDefault()
      e.stopImmediatePropagation()
      inbox_action $(this),
        before: ($node) -> set_conversation_state $node, 'unread'
        error: ($node) -> set_conversation_state $node, 'read'

    $('.action_remove_label').click (e) ->
      e.preventDefault()
      e.stopImmediatePropagation()
      current_label = null
      inbox_action $(this),
        method: 'PUT'
        before: ($node) ->
          current_label = $node.data('label')
          $node.removeClass('labeled ' + current_label) if current_label
          current_label
        success: ($node, data) ->
          update_conversation($node, data)
          remove_conversation $node if MessageInbox.scope == 'labeled'
        error: ($node) ->
          $node.addClass('labeled ' + current_label)

    $('.action_add_label').click (e) ->
      e.preventDefault()
      e.stopImmediatePropagation()
      label = null
      current_label = null
      inbox_action $(this),
        method: 'PUT'
        before: ($node, options) ->
          current_label = $node.data('label')
          label = options.url.match(/%5Blabel%5D=(.*)/)[1]
          if label is 'last'
            label = $last_label
            options.url = options.url.replace(/%5Blabel%5D=last/, '%5Blabel%5D=' + label)
          $node.removeClass('red orange yellow green blue purple').addClass('labeled').addClass(label)
          label isnt current_label
        success: ($node, data) ->
          update_conversation($node, data)
          set_last_label(label)
          remove_conversation $node if MessageInbox.label_scope and MessageInbox.label_scope isnt label
        error: ($node) ->
          $node.removeClass('labeled ' + label)
          $node.addClass('labeled ' + current_label) if current_label

    $('#action_add_recipients').click (e) ->
      e.preventDefault()
      $('#add_recipients_form')
        .attr('action', inbox_action_url_for($(this), $selected_conversation))
        .dialog('close').dialog
          width: 400
          title: I18n.t('title.add_recipients', 'Add Recipients')
          open: ->
            token_input = $('#add_recipients').data('token_input')
            token_input.base_exclude = ($(node).data('id') for node in $selected_conversation.find('.participant'))
            token_input.resize()
            $(this).find("input[name!=authenticity_token]").val('').change().last().focus()
          close: ->
            $('#add_recipients').data('token_input').input.blur()

    $('#action_subscribe').click ->
      inbox_action $(this),
        method: 'PUT'
        data: {subscribed: 1}
        success: ($node) -> $node.removeClass 'unsubscribed'

    $('#action_unsubscribe').click ->
      inbox_action $(this),
        method: 'PUT'
        data: {subscribed: 0}
        success: ($node) -> $node.addClass 'unsubscribed'

    $('#action_archive, #action_unarchive').click ->
      inbox_action $(this), { success: remove_conversation }

    $('#action_delete_all').click ->
      if confirm I18n.t('confirm.delete_conversation', "Are you sure you want to delete your copy of this conversation? This action cannot be undone.")
        inbox_action $(this), { method: 'DELETE', success: remove_conversation }

    $('#action_delete').click ->
      $selected_messages = $message_list.find('.selected')
      message = if $selected_messages.length > 1
        I18n.t('confirm.delete_messages', "Are you sure you want to delete your copy of these messages? This action cannot be undone.")
      else
        I18n.t('confirm.delete_message', "Are you sure you want to delete your copy of this message? This action cannot be undone.")
      if confirm message
        $selected_messages.fadeOut 'fast'
        inbox_action $(this),
          loading_node: $selected_conversation
          data: {remove: (parseInt message.id.replace(/message_/, '') for message in $selected_messages)}
          success: ($node, data) ->
            # TODO: once we've got infinite scroll hooked up, we should
            # have the response tell us the number of messages still in
            # the conversation, and key off of that to know if we should
            # delete the conversation (or possibly reload its messages)
            if $message_list.find('> li').not('.selected, .generated, .submission').length
              $selected_messages.remove()
              update_conversation($node, data)
            else
              remove_conversation($node)
          error: ->
            $selected_messages.show()

    $('#action_forward').click ->
      $('#forward_message_form').dialog('close').dialog
        width: 500
        title: I18n.t('title.forward_messages', 'Forward Messages')
        open: ->
          token_input = $('#forward_recipients').data('token_input')
          token_input.resize()
          $(this).find("input[name!=authenticity_token]").val('').change().last().focus()
          $preview = $(this).find('ul.messages').first()
          $preview.html('')
          $preview.html($message_list.find('> li.selected').clone(true).removeAttr('id').removeClass('self'))
          $preview.find('> li')
            .removeClass('selected odd')
            .find('> :checkbox')
            .attr('checked', true)
            .attr('name', 'forwarded_message_ids[]')
            .val ->
              $(this).closest('li').data('id')
        close: ->
          $('#forward_recipients').data('token_input').input.blur()

    $('#forward_message_form').submit (e) ->
      valid = !!($(this).find('#forward_body').val() and $(this).find('.token_input li').length)
      e.stopImmediatePropagation() unless valid
      valid
    $('#forward_message_form').formSubmit
      beforeSubmit: ->
        $(this).loadingImage()
      success: (data) ->
        $(this).loadingImage 'remove'
        $conversation = $('#conversation_' + data.conversation.id)
        if $conversation.length
          build_message(data.message).prependTo($message_list).slideDown 'fast' if is_selected($conversation)
          update_conversation($conversation, data.conversation)
        else
          add_conversation(data.conversation)
        set_hash '#/conversations/' + data.conversation.id
        reset_message_form()
        $(this).dialog('close')
      error: (data) ->
        $(this).loadingImage 'remove'
        $(this).dialog('close')


    $('#cancel_bulk_message_action').click ->
      toggle_message_actions off

    $('#conversation_blank .audience, #create_message_form .audience').click (e) ->
      if ($others = $(e.target).closest('span.others').find('> span')).length
        if not $(e.target).closest('span.others > span').length
          $('span.others > span').not($others).hide()
          $others.toggle()
          $others.css('left', $others.parent().position().left)
          $others.css('top', $others.parent().height() + $others.parent().position().top)
        e.preventDefault()
        return false

    nextAttachmentIndex = 0
    $('#action_add_attachment').click (e) ->
      e.preventDefault()
      $attachment = $("#attachment_blank").clone(true)
      $attachment.attr('id', null)
      $attachment.find("input[type='file']").attr('name', 'attachments[' + (nextAttachmentIndex++) + ']')
      $('#attachment_list').append($attachment)
      $attachment.slideDown "fast", ->
        inbox_resize()
      return false

    $("#attachment_blank a.remove_link").click (e) ->
      e.preventDefault()
      $(this).parents(".attachment").slideUp "fast", ->
        inbox_resize()
        $(this).remove()
      return false

    $('#action_media_comment').click (e) ->
      e.preventDefault()
      $("#create_message_form .media_comment").mediaComment 'create', 'audio', (id, type) ->
        $("#media_comment_id").val(id)
        $("#media_comment_type").val(type)
        $("#create_message_form .media_comment").show()
        $("#action_media_comment").hide()

    $('#create_message_form .media_comment a.remove_link').click (e) ->
      e.preventDefault()
      $("#media_comment_id").val('')
      $("#media_comment_type").val('')
      $("#create_message_form .media_comment").hide()
      $("#action_media_comment").show()

    for conversation in MessageInbox.initial_conversations
      add_conversation conversation, true
    $('#no_messages').showIf !$conversation_list.find('li').length

    $('.recipients').tokenInput
      placeholder: I18n.t('recipient_field_placeholder', "Enter a name, email, course, or group")
      selector:
        messages: {no_results: I18n.t('no_results', 'No results found')}
        populator: ($node, data, options={}) ->
          if data.avatar
            $img = $('<img />')
            $img.attr('src', data.avatar)
            $node.append($img)
          $b = $('<b />')
          $b.text(data.name)
          $span = $('<span />')
          $span.text(MessageInbox.shared_contexts_for_user(data)) if data.course_ids?
          $node.append($b, $span)
          $node.data('id', data.id)
          $node.addClass(if data.type then data.type else 'user')
          if options.level > 0
            $node.prepend('<a class="toggle"><i></i></a>')
            $node.addClass('toggleable')
          if data.type == 'context'
            $node.prepend('<a class="expand"><i></i></a>')
            $node.addClass('expandable')
        limiter: (options) ->
          -1 if options.level > 0
        browser:
          data:
            limit: -1
            type: 'context'

    token_input = $('#recipients').data('token_input')
    # since it doesn't infer percentage widths, just whatever the current pixels are
    token_input.fake_input.css('width', '100%')
    token_input.change = (tokens) ->
      if tokens.length > 1 or tokens[0]?.match(/^(course|group)_/)
        $form.find('#group_conversation').attr('checked', true) if !$form.find('#group_conversation_info').is(':visible')
        $form.find('#group_conversation_info').show()
      else
        $form.find('#group_conversation').attr('checked', true)
        $form.find('#group_conversation_info').hide()

    $(window).resize inbox_resize
    setTimeout inbox_resize

    $(window).bind 'hashchange', ->
      hash = location.hash
      if (match = hash.match(/^#\/conversations\/(\d+)$/)) and ($c = $('#conversation_' + match[1])) and $c.length
        select_conversation($c)
      else if $('#action_compose_message').length
        params = {}
        if match = hash.match(/^#\/conversations\?(.*)$/)
          params = parse_query_string(match[1])
        select_conversation(null, params)
    .triggerHandler('hashchange')
