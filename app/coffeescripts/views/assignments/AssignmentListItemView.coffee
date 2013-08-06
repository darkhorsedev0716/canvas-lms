define [
  'Backbone'
  'underscore'
  'compiled/views/PublishIconView'
  'jst/assignments/AssignmentListItem'
], (Backbone, _, PublishIconView, template) ->

  class AssignmentListItemView extends Backbone.View
    tagName: "li"
    template: template

    @child 'publishIconView', '[data-view=publish-icon]'

    initialize: ->
      super

      @publishIconView = false
      if ENV.PERMISSIONS.manage
        @publishIconView = new PublishIconView(model: @model)
        @model.on('change:published', @upatePublishState)

    upatePublishState: =>
      @$('.ig-row').toggleClass('ig-published', @model.get('published'))

    afterRender: ->
      @createModuleToolTip()

    createModuleToolTip: =>
      link = @$el.find('.tooltip_link')
      link.tooltip
        position:
          my: 'center bottom'
          at: 'center top-10'
          collision: 'fit fit'
        tooltipClass: 'center bottom vertical'
        content: ->
          $(link.data('tooltipSelector')).html()

    toJSON: ->
      data = @model.toView()
      if modules = ENV.MODULES[data.id]
        moduleName = modules[0]
        has_modules = if modules.length > 0 then true else false
        joinedNames = modules.join(",")
        _.extend data, {
          modules: modules
          module_count: modules.length
          module_name: moduleName
          has_modules: has_modules
          joined_names: joinedNames
        }
      else
        data
