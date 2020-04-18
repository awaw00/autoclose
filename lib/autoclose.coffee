{CompositeDisposable} = require 'atom'

module.exports =
  subscriptions: null
  currentEditor: null
  action: null
  extension: ''
  disabledFileExtensions: []
  config:
    disabledFileExtensions:
      type: 'array',
      default: ['js', 'jsx'],
      description: 'Disabled autoclose in above file types'

  activate: ->
    @subscriptions = new CompositeDisposable
    atom.config.observe 'autoclose.disabledFileExtensions', (value) =>
      @disabledFileExtensions = value

    @currentEditor = atom.workspace.getActiveTextEditor()
    if @currentEditor
      @action = @currentEditor.onDidInsertText (event) =>
        @_closeTag(event)
    @_getFileExtension()
    atom.workspace.onDidChangeActivePaneItem (paneItem) =>
      @_paneItemChanged(paneItem)

  deactivate: ->
    if @action then @action.dispose()
    @subscriptions.dispose()

  _getFileExtension: ->
    filename = @currentEditor?.getFileName?()
    @extension = filename?.substr filename?.lastIndexOf('.') + 1

  _paneItemChanged: (paneItem) ->
    if !paneItem then return

    if @action then @action.dispose()
    @currentEditor = paneItem
    @_getFileExtension()
    if @currentEditor.onDidInsertText
      @action = @currentEditor.onDidInsertText (event) =>
        @_closeTag(event)

  _addIndent: (range) ->
    {start, end} = range
    buffer = @currentEditor.buffer
    lineBefore = buffer.getLines()[start.row]
    lineAfter = buffer.getLines()[end.row]
    content = lineBefore.substr(lineBefore.lastIndexOf('<')) + '\n' + lineAfter
    regex = ///
              ^.*\<([a-zA-Z0-9-_]+)(\s.+)?\>
              \n
              \s*\<\/\1\>.*
            ///

    if regex.test content
      @currentEditor.insertNewlineAbove()
      @currentEditor.insertText('  ')

  _closeTag: (event) ->
    return if @extension in @disabledFileExtensions

    {text, range} = event
    if text is '\n'
      @_addIndent event.range
      return

    return if text isnt '>' and text isnt '/'

    line = @currentEditor.buffer.getLines()[range.end.row]
    strBefore = line.substr 0, range.start.column
    strAfter = line.substr range.end.column
    previousTagIndex = strBefore.lastIndexOf('<')

    if previousTagIndex < 0
      return

    tagName = strBefore.match(/^.*\<([a-zA-Z0-9-_.]+)[^>]*?/)?[1]
    if !tagName then return

    if text is '>'
      if strBefore[strBefore.length - 1] is '/'
        return

      @currentEditor.insertText "</#{tagName}>"
      @currentEditor.moveLeft tagName.length + 3
    else if text is '/'
      if strAfter[0] is '>' then return
      @currentEditor.insertText '>'
