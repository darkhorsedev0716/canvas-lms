describe "jquery.instructure_misc_plugins", ->

  it 'showIf', ->
    loadFixtures "jquery.instructure_misc_plugins.html"
    $("#checkbox1").showIf(-> true)
    expect($("#checkbox1").is(":visible")).toEqual(true)
    $("#checkbox1").showIf(-> false)
    expect($("#checkbox1").is(":visible")).toEqual(false)
    $("#checkbox1").showIf(-> true)
    expect($("#checkbox1").is(":visible")).toEqual(true)
    $("#checkbox1").showIf(false)
    expect($("#checkbox1").is(":visible")).toEqual(false)
    $("#checkbox1").showIf(true)
    expect($("#checkbox1").is(":visible")).toEqual(true)
    expect($("#checkbox1").showIf(-> true)).toEqual($("#checkbox1"))
    expect($("#checkbox1").showIf(-> false)).toEqual($("#checkbox1"))
    expect($("#checkbox1").showIf(true)).toEqual($("#checkbox1"))
    expect($("#checkbox1").showIf(false)).toEqual($("#checkbox1"))

  it 'disableIf', ->
    loadFixtures "jquery.instructure_misc_plugins.html"
    $("#checkbox1").disableIf(-> true)
    expect($("#checkbox1").is(":disabled")).toEqual(true)
    $("#checkbox1").disableIf(-> false)
    expect($("#checkbox1").is(":disabled")).toEqual(false)
    $("#checkbox1").disableIf(-> true)
    expect($("#checkbox1").is(":disabled")).toEqual(true)
    $("#checkbox1").disableIf(false)
    expect($("#checkbox1").is(":disabled")).toEqual(false)
    $("#checkbox1").disableIf(true)
    expect($("#checkbox1").is(":disabled")).toEqual(true)
    expect($("#checkbox1").disableIf(-> true)).toEqual($("#checkbox1"))
    expect($("#checkbox1").disableIf(-> false)).toEqual($("#checkbox1"))
    expect($("#checkbox1").disableIf(true)).toEqual($("#checkbox1"))
    expect($("#checkbox1").disableIf(false)).toEqual($("#checkbox1"))
