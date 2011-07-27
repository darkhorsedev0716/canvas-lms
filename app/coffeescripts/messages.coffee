$conversations = []
$conversation_list = []
$messages = []
$message_list = []
$form = []
$selected_conversation = null
$scope = null
MessageInbox = {}

class TokenInput
  constructor: (@node, @options) ->
    @node.data('token_input', this)
    @fake_input = $('<div />')
      .css('width', @node.css('width'))
      .css('font-family', @node.css('font-family'))
      .insertAfter(@node)
      .addClass('token_input')
      .bind('selectstart', false)
      .click => @input.focus()
    @node_name = @node.attr('name')
    @node.removeAttr('name').hide().change =>
      @tokens.html('')

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
        # TODO: recipient selection, virtual cursor fu
        #  $token.removeClass('selected').remove()
        #else
        #  @selected_token?.removeClass('selected')
        #  @selected_token = $token.addClass('selected')

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
            @selector.browse(@browser.data)
          .prependTo(@fake_input)
      @selector = new type(this, @node.attr('finder_url'), @options.selector)        

  add_token: (data) ->
    unless @tokens.find('#' + id).length
      $token = $('<li />')
      val = data?.value ? @val()
      id = 'token_' + val
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
    @selector?.reposition()

  has_token: (data) ->
    @tokens.find('#token_' + (data?.value ? data)).length > 0

  remove_token: (data) ->
    id = 'token_' + (data?.value ? data)
    @tokens.find('#' + id).remove()
    @selector?.reposition()

  remove_last_token: (data) ->
    @tokens.find('li').last().remove()
    @selector?.reposition()

  input_keydown: (e) ->
    @keyup_action = false
    if @selector
      if @selector?.capture_keydown(e)
        e.preventDefault()
        return false
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
    @fetch_list(data: data) unless @ui_locked or @menu.is(":visible") or @input.val()

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
        @close()
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
    post_data.exclude = @input.token_values()
    post_data.context = @stack[@stack.length - 1][0].data('id') if @list_expanded()
    post_data.limit ?= @options.limiter?(level: @stack.length)
    post_data


# depends on the scrollable ancestor being the first positioned
# ancestor. if it's not, it won't work
$.fn.scrollIntoView = (options = {}) ->
  $container = @offsetParent()
  containerTop = $container.scrollTop();
  containerBottom = containerTop + $container.height(); 
  elemTop = this[0].offsetTop;
  elemBottom = elemTop + $(this[0]).outerHeight();
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
    $('#action_compose_message').toggleClass 'active', newMessage

    if newMessage
      $form.find('.audience').html I18n.t('headings.new_message', 'New Message')
      $form.attr action: '/messages'
    else
      $form.find('.audience').html $selected_conversation.find('.audience').html()
      $form.attr action: $selected_conversation.find('a').attr('add_url')

    reset_message_form()
    unless $form.is ':visible'
      $form.parent().show()
      $form.hide().slideDown 'fast' , ->
        $form.find(':input:visible:first').focus()

  reset_message_form = ->
    $form.find('input, textarea').val('').change()

  parse_query_string = (query_string = window.location.search.substr(1)) ->
    hash = {}
    for parts in query_string.split(/\&/)
      [key, value] = parts.split(/\=/, 2)
      hash[decodeURIComponent(key)] = decodeURIComponent(value)
    hash

  select_conversation = ($conversation) ->
    if $selected_conversation && $selected_conversation.attr('id') == $conversation?.attr('id')
      $selected_conversation.removeClass 'inactive'
      $message_list.find('li.selected').removeClass 'selected'
      return

    $message_list.removeClass('private').hide().html ''
    $message_list.addClass('private') if $conversation?.hasClass('private')
    
    if $selected_conversation
      $selected_conversation.removeClass 'selected inactive'
      if $scope == 'unread'
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

    $('#menu_actions').triggerHandler('prepare_menu')
    $('#menu_actions').toggleClass 'disabled',
      !$('#menu_actions').parent().find('ul[style*="block"]').length

    if $selected_conversation
      location.hash = $selected_conversation.attr('id').replace('conversation_', '/messages/')
    else
      if match = location.hash.match(/^#\/messages\?(.*)$/)
        params = parse_query_string(match[1])
        if params.user_id and params.user_name and params.from_conversation_id
          $('#recipients').data('token_input').add_token value: params.user_id, text: params.user_name
          $('#from_conversation_id').val(params.from_conversation_id)
      location.hash = ''
      return

    $form.loadingImage()
    $c = $selected_conversation
    $.ajaxJSON $selected_conversation.find('a').attr('href'), 'GET', {}, (data) ->
      return unless $c == $selected_conversation
      for user in data.participants when !MessageInbox.user_cache[user.id]
        MessageInbox.user_cache[user.id] = user
        user.html_name = html_name_for_user(user)
      $messages.show()
      for message in data.messages
        $message_list.append build_message(message.conversation_message)
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
    $message.addClass('other') unless data.author_id is MessageInbox.user_id
    user = MessageInbox.user_cache[data.author_id]
    if avatar = user?.avatar
      $message.prepend $('<img />').attr('src', avatar).addClass('avatar')
    user.html_name ?= html_name_for_user(user) if user
    user_name = user?.name ? I18n.t('unknown_user', 'Unknown user')
    $message.find('.audience').html user?.html_name || $.h(user_name)
    $message.find('span.date').text $.parseFromISO(data.created_at).datetime_formatted
    $message.find('p').text data.body
    $pm_action = $message.find('a.send_private_message')
    pm_url = $.replaceTags($pm_action.attr('href'), 'user_id', data.author_id)
    pm_url = $.replaceTags(pm_url, 'user_name', encodeURIComponent(user_name))
    pm_url = $.replaceTags(pm_url, 'from_conversation_id', $selected_conversation.attr('id').replace('conversation_', ''))
    $pm_action.attr('href', pm_url).click =>
      setTimeout => 
        select_conversation()
    $message

  inbox_action_url_for = ($action) ->
    $.replaceTags $action.attr('href'), 'id', $selected_conversation.attr('id').replace('conversation_', '')

  inbox_action = ($action, options) ->
    defaults =
      loading_node: $selected_conversation
      url: inbox_action_url_for($action)
      method: 'POST'
      data: {}
    options = $.extend(defaults, options)

    options.before?(options.loading_node)
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
    $conversation = $("#conversation_blank").clone(true).attr('id', 'conversation_' + data.id)
    if data.avatar_url
      $conversation.prepend $('<img />').attr('src', data.avatar_url).addClass('avatar')
    $conversation[if append then 'appendTo' else 'prependTo']($conversation_list).click (e) ->
      e.preventDefault()
      select_conversation $(this)
    update_conversation($conversation, data, true)
    $conversation.hide().slideDown('fast') unless append

  update_conversation = ($conversation, data, no_move) ->
    $a = $conversation.find('a')
    $a.attr 'href', $.replaceTags($a.attr('href'), 'id', data.id)
    $a.attr 'add_url', $.replaceTags($a.attr('add_url'), 'id', data.id)
    $conversation.find('.audience').html data.audience if data.audience
    $conversation.find('span.date').text $.parseFromISO(data.last_message_at).datetime_formatted
    move_direction = if $conversation.data('last_message_at') > data.last_message_at then 'down' else 'up'
    $conversation.data 'last_message_at', data.last_message_at
    $p = $conversation.find('p')
    $p.text data.last_message
    $p.prepend ("<i class=\"flag_" + flag + "\"></i> " for flag in data.flags).join('') if data.flags.length
    $conversation.addClass('private') if data['private']
    $conversation.addClass('unsubscribed') unless data.subscribed
    $conversation.addClass(data.workflow_state)
    reposition_conversation($conversation, move_direction) unless no_move

  reposition_conversation = ($conversation, move_direction) ->
    last_message = $conversation.data('last_message_at')
    $n = $conversation
    if move_direction == 'up'
      $n = $n.prev() while $n.prev() && $n.prev().data('last_message_at') < last_message
    else
      $n = $n.next() while $n.next() && $n.next().data('last_message_at') > last_message
    return if $n == $conversation
    $dummy_conversation = $conversation.clone().insertAfter($conversation)
    $conversation.detach()[if move_direction == 'up' then 'insertBefore' else 'insertAfter']($n).animate({opacity: 'toggle', height: 'toggle'}, 0)
    $dummy_conversation.animate {opacity: 'toggle', height: 'toggle'}, 200, ->
      $(this).remove()
    $conversation.animate {opacity: 'toggle', height: 'toggle'}, 200

  remove_conversation = ($conversation) ->
    select_conversation()
    $conversation.fadeOut 'fast', ->
      $(this).remove()
      $('#no_messages').showIf !$conversation_list.find('li').length

  set_conversation_state = ($conversation, state) ->
    $conversation.removeClass('read unread archived').addClass state

  close_menus = () ->
    $('#actions .menus > li').removeClass('selected')

  open_menu = ($menu) ->
    close_menus()
    unless $menu.hasClass('disabled')
      $div = $menu.parent('li').addClass('selected').find('div')
      $menu.triggerHandler 'prepare_menu'
      $div.css 'margin-left', '-' + ($div.width() / 2) + 'px'

  $.extend window,
    MessageInbox: MessageInbox

  $(document).ready () ->
    $conversations = $('#conversations')
    $conversation_list = $conversations.find("ul")
    $messages = $('#messages')
    $message_list = $messages.find('ul').last()
    $form = $('#create_message_form')
    $scope = $('#menu_views').attr('class')

    $form.find("textarea").elastic()

    $form.submit (e) ->
      valid = !!($form.find('#body').val() and ($form.find('#recipient_info').filter(':visible').length is 0 or $form.find('.token_input li').length > 0))
      e.stopImmediatePropagation() unless valid
      valid
    $form.formSubmit
      beforeSubmit: ->
        $(this).loadingImage()
      success: (data) ->
        $(this).loadingImage 'remove'
        build_message(data.message.conversation_message).prependTo($message_list).slideDown 'fast'
        $conversation = $('#conversation_' + data.conversation.id)
        if $conversation.length
          update_conversation($conversation, data.conversation)
        else
          add_conversation(data.conversation)
        reset_message_form()
      error: (data) ->
        $form.find('.token_input').errorBox(I18n.t('recipient_error', 'The course or group you have selected has no valid recipients'))
        $('.error_box').filter(':visible').css('z-index', 10) # TODO: figure out why this is necessary
        $(this).loadingImage 'remove'

    $message_list.click (e) ->
      $message = $(e.target).closest('li')
      $selected_conversation?.addClass('inactive')
      $message.toggleClass('selected')

    $('#action_compose_message').click ->
      select_conversation()

    $('#actions .menus > li > a').click (e) ->
      e.preventDefault()
      open_menu $(this)
    .focus () ->
      open_menu $(this)

    $(document).bind 'mousedown', (e) ->
      unless $(e.target).closest("span.others").find('ul').length
        $('span.others ul').hide()
      close_menus() unless $(e.target).closest(".menus > li").length

    $('#menu_views').parent().find('li a').click (e) ->
      close_menus()
      $('#menu_views').text $(this).text()

    $('#menu_actions').bind 'prepare_menu', ->
      $container = $('#menu_actions').parent().find('div')
      $container.find('ul').removeClass('first last').hide()
      $container.find('li').hide()
      if $selected_conversation
        $('#action_mark_as_read').parent().showIf $selected_conversation.hasClass('unread')
        $('#action_mark_as_unread').parent().showIf $selected_conversation.hasClass('read')
        if $selected_conversation.hasClass('private')
          $('#action_add_recipients, #action_subscribe, #action_unsubscribe').parent().hide()
        else
          $('#action_unsubscribe').parent().showIf !$selected_conversation.hasClass('unsubscribed')
          $('#action_subscribe').parent().showIf $selected_conversation.hasClass('unsubscribed')
        $('#action_forward').parent().show()
        $('#action_archive').parent().showIf $scope != 'archived'
        $('#action_unarchive').parent().showIf $scope == 'archived'
        $('#action_delete').parent().showIf $selected_conversation.hasClass('inactive') && $message_list.find('.selected').length
        $('#action_delete_all').parent().showIf !$selected_conversation.hasClass('inactive') || !$message_list.find('.selected').length
      $('#action_mark_all_as_read').parent().showIf $scope == 'unread' && $conversation_list.find('.unread').length

      $container.find('li[style*="list-item"]').parent().show()
      $groups = $container.find('ul[style*="block"]')
      if $groups.length
        $($groups[0]).addClass 'first'
        $($groups[$groups.length - 1]).addClass 'last'
    .parent().find('li a').click (e) ->
      e.preventDefault()
      close_menus()

    $('#action_mark_as_read').click ->
      inbox_action $(this),
        before: ($node) ->
          set_conversation_state $node, 'read' unless $scope == 'unread'
        success: ($node) ->
          remove_conversation $node if $scope == 'unread'
        error: ($node) ->
          set_conversation_state $node 'unread' unless $scope == 'unread'

    $('#action_mark_all_as_read').click ->
      inbox_action $(this),
        url: $(this).attr('href'),
        success: ->
          $conversations.fadeOut 'fast', ->
            $(this).find('li').remove()
            $(this).show()
            $('#no_messages').show()
            select_conversation()

    $('#action_mark_as_unread').click ->
      inbox_action $(this),
        before: ($node) -> set_conversation_state $node, 'unread'
        error: ($node) -> set_conversation_state $node, 'read'

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
          data: {remove: (parseInt message.id.replace(/message_/, '') for message in $selected_messages)}
          success: ($node, data) ->
            # TODO: once we've got infinite scroll hooked up, we should
            # have the response tell us the number of messages still in
            # the conversation, and key off of that to know if we should
            # delete the conversation (or possibly reload its messages)
            if $message_list.find('li').not('.selected, .generated').length
              update_conversation($node, data)
              $selected_messages.remove()
            else
              remove_conversation($node)
          error: ->
            $selected_messages.show()

    $('#conversation_blank .audience, #create_message_form .audience').click (e) ->
      if ($others = $(e.target).closest('span.others').find('ul')).length
        if not $(e.target).closest('span.others ul').length
          $('span.others ul').not($others).hide()
          $others.toggle()
          $others.css('left', $others.parent().position().left)
        e.preventDefault()
        return false

    for conversation in MessageInbox.initial_conversations
      add_conversation conversation, true

    input = new TokenInput $('#recipients'),
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
    input.fake_input.css('width', '100%')

    if match = location.hash.match(/^#\/messages\/(\d+)$/)
      $('#conversation_' + match[1]).click()
    else
      $('#action_compose_message').click()