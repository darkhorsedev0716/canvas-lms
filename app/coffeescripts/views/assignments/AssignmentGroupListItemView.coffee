define [
  'i18n!assignments'
  'underscore'
  'compiled/class/cache'
  'compiled/collections/AssignmentCollection'
  'compiled/views/DraggableCollectionView'
  'compiled/views/assignments/AssignmentListItemView'
  'compiled/views/assignments/CreateAssignmentView'
  'compiled/views/assignments/CreateGroupView'
  'compiled/views/assignments/DeleteGroupView'
  'jst/assignments/AssignmentGroupListItem'
], (I18n, _, Cache, AssignmentCollection, DraggableCollectionView, AssignmentListItemView, CreateAssignmentView, CreateGroupView, DeleteGroupView, template) ->

  class AssignmentGroupListItemView extends DraggableCollectionView
    tagName: "li"
    className: "item-group-condensed"
    itemView: AssignmentListItemView
    template: template

    @child 'createAssignmentView', '[data-view=createAssignment]'
    @child 'editGroupView', '[data-view=editAssignmentGroup]'
    @child 'deleteGroupView', '[data-view=deleteAssignmentGroup]'

    els: _.extend({}, @::els, {
      '.add_assignment': '$addAssignmentButton'
      '.delete_group': '$deleteGroupButton'
      '.edit_group': '$editGroupButton'
    })

    events:
      'click .element_toggler': 'toggleArrow'

    messages:
      toggleMessage: I18n.t('toggle_message',"toggle assignment visibility")

    # call remove on children so that they can clean up old dialogs.
    # this should eventually happen at a higher level (eg for all views), but
    # we need to make sure that all children view are also children dom
    # elements first.
    render: ->
      @createAssignmentView.remove() if @createAssignmentView
      @editGroupView.remove() if @editGroupView
      @deleteGroupView.remove() if @deleteGroupView
      super(ENV.PERMISSIONS.manage)

    afterRender: ->
      # need to hide child views and set trigger manually
      if @createAssignmentView
        @createAssignmentView.hide()
        @createAssignmentView.setTrigger @$addAssignmentButton

      if @editGroupView
        @editGroupView.hide()
        @editGroupView.setTrigger @$editGroupButton

      if @deleteGroupView
        @deleteGroupView.hide()
        @deleteGroupView.setTrigger @$deleteGroupButton

    initialize: ->
      @initializeCollection()
      super
      @initializeChildViews()

      # we need the following line in order to access this view later
      @model.groupView = @
      @initCache()

    initializeCollection: ->
      @model.get('assignments').each (assign) ->
        assign.doNotParse() if assign.multipleDueDates()

      @collection = @model.get('assignments')
      @collection.on 'add', @expand

    initializeChildViews: ->
      @editGroupView = false
      @createAssignmentView = false
      @deleteGroupView = false

      if @canManage()
        @editGroupView = new CreateGroupView
          assignmentGroup: @model
        @createAssignmentView = new CreateAssignmentView
          assignmentGroup: @model
        @deleteGroupView = new DeleteGroupView
          model: @model

    initCache: ->
      $.extend true, @, Cache
      @cache.use('localStorage')
      key = @cacheKey()
      if !@cache.get(key)?
        @cache.set(key, true)

    toJSON: ->
      count = @countRules()
      showRules = count != 0 and @canManage()

      data = @model.toJSON()
      showWeight = @model.collection.course?.get('apply_assignment_group_weights') and data.group_weight?

      attributes = _.extend(data, {
        showRules: showRules
        rulesText: I18n.t('rules_text', "Rule", { count: count })
        showWeight: showWeight
        groupWeight: data.group_weight
        toggleMessage: @messages.toggleMessage
      })

    countRules: ->
      rules = @model.get('rules')
      count = 0
      for k,v of rules
        if k == "never_drop"
          count += v.length
        else
          count++
      count

    isExpanded: ->
      @cache.get(@cacheKey())

    expand: =>
      @toggle(true) if !@isExpanded()

    toggle: (setTo=false) ->
      @$el.find('.element_toggler').click()
      @cache.set(@cacheKey(), setTo)

    cacheKey: ->
      "ag_#{@model.get('id')}_expanded"

    toggleArrow: (ev) ->
      arrow = $(ev.currentTarget).children('i')
      arrow.toggleClass('icon-mini-arrow-down').toggleClass('icon-mini-arrow-right')
      @toggleExpanded()

    toggleExpanded: ->
      key = @cacheKey()
      expanded = !@cache.get(key)
      @cache.set(key, expanded)

    canManage: ->
      ENV.PERMISSIONS.manage
