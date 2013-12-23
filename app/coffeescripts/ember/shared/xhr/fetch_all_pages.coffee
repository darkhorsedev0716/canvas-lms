define [
  'ember'
  'ic-ajax'
  './parse_link_header'
], ({$, ArrayProxy}, ajax, parseLinkHeader) ->

  fetch = (url, records, data) ->
    opts = $.extend({dataType: "json"}, {data: data})
    ajax.raw(url, opts).then (result) ->
      records.pushObjects result.response
      meta = parseLinkHeader result.jqXHR
      if meta.next
        fetch meta.next, records, data
      else
        records.set('isLoaded', true)
        records.set('isLoading', false)

  fetchAllPages = (url, data) ->
    records = ArrayProxy.create({content: []})
    records.set('isLoading', true)
    fetch url, records, data
    records
