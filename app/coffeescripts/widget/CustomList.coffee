### 
requires:
  - vendor/jquery-1.6.4.js
  - compiled/util/objectCollection.js
  - vendor/publisher.js
  - compiled/Template.js
  - jst/CustomList/courseList/wrapper.js
  - jst/CustomList/courseList/content.js
  - jQuery.ajaxJSON
###

class @CustomList

  options:
    animationDuration: 200
    model: 'Course'
    dataAttribute: 'id'
    wrapper: 'courseList/wrapper'
    content: 'courseList/content'
    url: '/favorites'
    appendTarget: 'body',
    resetCount: 12

  constructor: (selector, items, options) ->
    @options          = jQuery.extend {}, @options, options
    @appendTarget     = jQuery @options.appendTarget
    @element          = jQuery selector
    @targetList       = @element.find '> ul'
    @wrapper          = jQuery Template @options.wrapper, {}
    @sourceList       = @wrapper.find '> ul'
    @contentTemplate  = new Template @options.content
    @ghost            = jQuery('<ul/>').addClass('customListGhost')
    @requests         = { add: {}, remove: {} }
    @doc              = jQuery document.body
    @isOpen           = false

    @attach()
    @setItems items

  open: ->
    @wrapper.appendTo(@appendTarget).show()
    setTimeout => # css3 animation
      @element.addClass('customListEditing')
    , 1

  close: ->
    @wrapper.hide 0, =>
      @teardown()
    @element.removeClass('customListEditing');
    @resetList() if @pinned.length is 0

  attach: ->
    @element.delegate '.customListOpen', 'click', jQuery.proxy(this, 'open')
    @wrapper.delegate '.customListClose', 'click', jQuery.proxy(this, 'close')
    @wrapper.delegate '.customListRestore', 'click', jQuery.proxy(this, 'reset')
    @wrapper.delegate 'a', 'click.customListTeardown', (event) ->
      event.preventDefault()
    @wrapper.delegate(
      '.customListItem',
      'click.customListTeardown',
      jQuery.proxy(this, 'sourceClickHandler')
    )

  teardown: ->
    @wrapper.detach()

  add: (id, element) ->
    item          = @items.findBy('id', id)
    clone         = element.clone().hide()
    item.element  = clone

    element.addClass 'on'

    @pinned.push item
    @pinned.sortBy('shortName')

    index = @pinned.indexOf(item) + 1
    target = @targetList.find("li:nth-child(#{index})")

    if target.length isnt 0
      clone.insertBefore target
    else
      clone.appendTo @targetList

    clone.slideDown @options.animationDuration
    @animateGhost element, clone
    @onAdd item

  animateGhost: (fromElement, toElement) ->
    from          = fromElement.offset()
    to            = toElement.offset()
    clone         = fromElement.clone()
    from.position = 'absolute'

    @ghost.append(clone)
    @ghost.appendTo(@doc).css(from).animate to, @options.animationDuration, =>
      @ghost.detach().empty()

  remove: (item, element) ->
    element.removeClass 'on'
    @animating = true
    @onRemove item
    item.element.slideUp @options.animationDuration, =>
      item.element.remove()
      @pinned.eraseBy 'id', item.id
      @animating = false

  abortAll: ->
    req.abort() for id, req of @requests.add
    req.abort() for id, req of @requests.remove

  reset: ->
    @abortAll()

    callback = =>
      delete @requests.reset

    @requests.reset = jQuery.ajaxJSON(@options.url + '/' + @options.model, 'DELETE', {}, callback, callback)
    @resetList()

  resetList: ->
    defaultItems = @items.slice 0, @options.resetCount
    html = @contentTemplate.toHTML { items: defaultItems }
    @targetList.empty().html(html)
    @setPinned()

  onAdd: (item) ->
    if @requests.remove[item.id]
      @requests.remove[item.id].abort()
      return

    success = =>
      args = [].slice.call arguments
      args.unshift(item.id)
      @addSuccess.apply(this, args)

    error = =>
      args = [].slice.call arguments
      args.unshift(item.id)
      @addError.apply(this, args)

    data = 
      favorite:
        context_type: @options.model,
        context_id: item.id

    req = jQuery.ajaxJSON(@options.url, 'POST', data, success, error)

    @requests.add[item.id] = req

  onRemove: (item) ->
    if @requests.add[item.id]
      @requests.add[item.id].abort();
      return

    success = =>
      args = [].slice.call arguments
      args.unshift(item.id)
      @removeSuccess.apply(this, args)

    error = =>
      args = [].slice.call arguments
      args.unshift(item.id)
      @removeError.apply(this, args)

    url = @options.url + '/' + item.id
    req = jQuery.ajaxJSON(url, 'DELETE', {context_type: @options.model}, success, error)

    @requests.remove[item.id] = req

  addSuccess: (id) ->
    delete @requests.add[id]

  addError: (id) ->
    delete @requests.add[id]

  removeSuccess: (id) ->
    delete @requests.remove[id]

  removeError: (id) ->
    delete @requests.remove[id]

  setItems: (items) ->
    @items  = objectCollection items
    @items.sortBy 'shortName'
    html    = @contentTemplate.toHTML items: @items
    @sourceList.html html
    @setPinned()

  setPinned: ->
    @pinned = objectCollection []

    @element.find('> ul > li').each (index, element) =>
      element = jQuery element
      id      = element.data('id')
      item    = @items.findBy('id', id)

      return unless item
      item.element = element
      @pinned.push item

    @wrapper.find('ul > li').removeClass('on')

    for item in @pinned
      match = @wrapper.find("ul > li[data-id=#{item.id}]")
      match.addClass 'on'

  sourceClickHandler: (event) ->
    @checkElement jQuery event.currentTarget

  checkElement: (element) ->
    # DOM and data get out of sync for atomic clicking, hence @animating
    return if @animating or @requests.reset
    id = element.data 'id'
    item = @pinned.findBy 'id', id

    if item
      @remove item, element
    else
      @add id, element

