define [
  'react'
  'jquery'
  'jsx/files/UploadButton'
  'compiled/react_files/modules/FileOptionsCollection'
], (React, $, UploadButton, FileOptionsCollection) ->

  Simulate = React.addons.TestUtils.Simulate

  module 'UploadButton',
    setup: ->
      props =
        currentFolder:
          files:
            models: []

      @button = React.render(UploadButton(props), $('<div>').appendTo("#fixtures")[0])

    teardown: ->
      React.unmountComponentAtNode(@button.getDOMNode().parentNode)
      $("#fixtures").empty()

  test 'hides actual file input form', ->
    form = @button.refs.form.getDOMNode()
    ok $(form).attr('class').match(/hidden/), 'is hidden from user'

  test 'only enques uploads when state.newUploads is true', ->
    @spy(@button, 'queueUploads')

    @button.state.nameCollisions.length = 0
    @button.state.resolvedNames.length = 1

    FileOptionsCollection.state.newOptions = false
    @button.componentDidUpdate()
    equal @button.queueUploads.callCount, 0

    FileOptionsCollection.state.newOptions = true
    @button.componentDidUpdate()
    equal @button.queueUploads.callCount, 1
