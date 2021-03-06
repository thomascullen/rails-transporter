fs = require 'fs'
path = require 'path'
pluralize = require 'pluralize'
changeCase = require 'change-case'
_ = require 'underscore'

AssetFinderView = require './asset-finder-view'
RailsUtil = require './rails-util'

module.exports =
class FileOpener
  _.extend this::, RailsUtil::

  openView: ->
    configExtension = atom.config.get('rails-transporter.viewFileExtension')
    @reloadCurrentEditor()

    for rowNumber in [@cusorPos.row..0]
      currentLine = @editor.lineTextForBufferRow(rowNumber)
      result = currentLine.match /^\s*def\s+(\w+)/
      if result?[1]?
        
        if @isController(@currentFile)
          targetFile = @currentFile.replace(path.join('app', 'controllers'), path.join('app', 'views'))
                                   .replace(/_controller\.rb$/, "#{path.sep}#{result[1]}.#{configExtension}")
        else if @isMailer(@currentFile)
          targetFile = @currentFile.replace(path.join('app', 'mailers'), path.join('app', 'views'))
                                   .replace(/\.rb$/, "#{path.sep}#{result[1]}.#{configExtension}")
        else
          targetFile = null
          
        if fs.existsSync targetFile
          @open(targetFile)
        else
          @openDialog(targetFile)
        return
        
    # there were no methods above the line where the command was triggered.
    atom.beep()

  openController: ->
    @reloadCurrentEditor()
    if @isModel(@currentFile)
      resource = path.basename(@currentFile, '.rb')
      targetFile = @currentFile.replace(path.join('app', 'models'), path.join('app', 'controllers'))
                               .replace(resource, "#{pluralize(resource)}_controller")
    else if @isView(@currentFile)
      targetFile = path.dirname(@currentFile)
                   .replace(path.join('app', 'views'), path.join('app', 'controllers')) + '_controller.rb'
    else if @isSpec(@currentFile)
      targetFile = @currentFile.replace(path.join('spec', 'controllers'), path.join('app', 'controllers'))
                               .replace(/_spec\.rb$/, '.rb')
    else if @isController(@currentFile) and @currentBufferLine.indexOf("include") isnt -1
      concernsDir = path.join(atom.project.getPaths()[0], 'app', 'controllers', 'concerns')
      targetFile = @concernPath(concernsDir, @currentBufferLine)

    if fs.existsSync targetFile
      @open(targetFile)
    else
      @openDialog(targetFile)
      

  openModel: ->
    @reloadCurrentEditor()
    if @isController(@currentFile)
      resourceName = pluralize.singular(@currentFile.match(/([\w]+)_controller\.rb$/)[1])
      targetFile = @currentFile.replace(path.join('app', 'controllers'), path.join('app', 'models'))
                               .replace(/([\w]+)_controller\.rb$/, "#{resourceName}.rb")

    else if @isView(@currentFile)
      dir = path.dirname(@currentFile)
      resource = path.basename(dir)
      targetFile = dir.replace(path.join('app', 'views'), path.join('app', 'models'))
                      .replace(resource, "#{pluralize.singular(resource)}.rb")

    else if @isSpec(@currentFile)
      targetFile = @currentFile.replace(path.join('spec', 'models'), path.join('app', 'models'))
                               .replace(/_spec\.rb$/, '.rb')
                               
    else if @isFactory(@currentFile)
      dir = path.basename(@currentFile, '.rb')
      resource = path.basename(dir)
      targetFile = @currentFile.replace(path.join('spec', 'factories'), path.join('app', 'models'))
                               .replace(resource, pluralize.singular(resource))
                               
    else if @isModel(@currentFile) and @currentBufferLine.indexOf("include") isnt -1
      concernsDir = path.join(atom.project.getPaths()[0], 'app', 'models', 'concerns')
      targetFile = @concernPath(concernsDir, @currentBufferLine)
    
    if fs.existsSync targetFile
      @open(targetFile)
    else
      @openDialog(targetFile)

  openHelper: ->
    @reloadCurrentEditor()
    if @isController(@currentFile)
      targetFile = @currentFile.replace(path.join('app', 'controllers'), path.join('app', 'helpers'))
                               .replace(/controller\.rb/, 'helper.rb')
    else if @isSpec(@currentFile)
      targetFile = @currentFile.replace(path.join('spec', 'helpers'), path.join('app', 'helpers'))
                               .replace(/_spec\.rb/, '.rb')
    else if @isModel(@currentFile)
      resource = path.basename(@currentFile, '.rb')
      targetFile = @currentFile.replace(path.join('app', 'models'), path.join('app', 'helpers'))
                               .replace(resource, "#{pluralize(resource)}_helper")
    else if @isView(@currentFile)
      targetFile = path.dirname(@currentFile)
                       .replace(path.join('app', 'views'), path.join('app', 'helpers')) + "_helper.rb"

    if fs.existsSync targetFile
      @open(targetFile)
    else
      @openDialog(targetFile)

  openSpec: ->
    @reloadCurrentEditor()
    if @isController(@currentFile)
      targetFile = @currentFile.replace(path.join('app', 'controllers'), path.join('spec', 'controllers'))
                               .replace(/controller\.rb$/, 'controller_spec.rb')
    else if @isHelper(@currentFile)
      targetFile = @currentFile.replace(path.join('app', 'helpers'), path.join('spec', 'helpers'))
                               .replace(/\.rb$/, '_spec.rb')
    else if @isModel(@currentFile)
      targetFile = @currentFile.replace(path.join('app', 'models'), path.join('spec', 'models'))
                               .replace(/\.rb$/, '_spec.rb')
    else if @isFactory(@currentFile)
      resource = path.basename(@currentFile.replace(/_spec\.rb/, '.rb'), '.rb')
      targetFile = @currentFile.replace(path.join('spec', 'factories'), path.join('spec', 'models'))
                               .replace("#{resource}.rb", "#{pluralize.singular(resource)}_spec.rb")
    
                               
    if fs.existsSync targetFile
      @open(targetFile)
    else
      @openDialog(targetFile)

  openPartial: ->
    @reloadCurrentEditor()
    if @isView(@currentFile)
      if @currentBufferLine.indexOf("render") isnt -1
        if @currentBufferLine.indexOf("partial") is -1
          result = @currentBufferLine.match(/render\s*\(?\s*["'](.+?)["']/)
          targetFile = @partialFullPath(@currentFile, result[1]) if result?[1]?
        else
          result = @currentBufferLine.match(/render\s*\(?\s*\:?partial(\s*=>|:*)\s*["'](.+?)["']/)
          targetFile = @partialFullPath(@currentFile, result[2]) if result?[2]?

    if fs.existsSync targetFile
      @open(targetFile)
    else
      @openDialog(targetFile)

  openAsset: ->
    @reloadCurrentEditor()
    if @isView(@currentFile)
      if @currentBufferLine.indexOf("javascript_include_tag") isnt -1
        result = @currentBufferLine.match(/javascript_include_tag\s*\(?\s*["'](.+?)["']/)
        targetFile = @assetFullPath(result[1], 'javascripts') if result?[1]?
      else if @currentBufferLine.indexOf("stylesheet_link_tag") isnt -1
        result = @currentBufferLine.match(/stylesheet_link_tag\s*\(?\s*["'](.+?)["']/)
        targetFile = @assetFullPath(result[1], 'stylesheets') if result?[1]?

    else if @isAsset(@currentFile)
      if @currentBufferLine.indexOf("require ") isnt -1
        result = @currentBufferLine.match(/require\s*(.+?)\s*$/)
        if @currentFile.indexOf(path.join('app', 'assets', 'javascripts')) isnt -1
          targetFile = @assetFullPath(result[1], 'javascripts') if result?[1]?
        else if @currentFile.indexOf(path.join('app', 'assets', 'stylesheets')) isnt -1
          targetFile = @assetFullPath(result[1], 'stylesheets') if result?[1]?
      else if @currentBufferLine.indexOf("require_tree ") isnt -1
        return @createAssetFinderView().toggle()
      else if @currentBufferLine.indexOf("require_directory ") isnt -1
        return @createAssetFinderView().toggle()

    @open(targetFile)

  openLayout: ->
    configExtension = atom.config.get('rails-transporter.viewFileExtension')
    @reloadCurrentEditor()
    layoutDir = path.join(atom.project.getPaths()[0], 'app', 'views', 'layouts')
    if @isController(@currentFile)
      if @currentBufferLine.indexOf("layout") isnt -1
        result = @currentBufferLine.match(/layout\s*\(?\s*["'](.+?)["']/)
        targetFile = path.join(layoutDir, "#{result[1]}.#{configExtension}") if result?[1]?
      else
        targetFile = @currentFile.replace(path.join('app', 'controllers'), path.join('app', 'views', 'layouts'))
                                 .replace('_controller.rb', ".#{configExtension}")
        unless fs.existsSync(targetFile)
          targetFile = path.join(path.dirname(targetFile), "application.#{configExtension}")

    @open(targetFile)
    
  openFactory: ->
    @reloadCurrentEditor()
    if @isModel(@currentFile)
      resource = path.basename(@currentFile, '.rb')
      targetFile = @currentFile.replace(path.join('app', 'models'), path.join('spec', 'factories'))
                               .replace(resource, pluralize(resource))
    else if @isSpec(@currentFile)
      resource = path.basename(@currentFile.replace(/_spec\.rb/, '.rb'), '.rb')
      targetFile = @currentFile.replace(path.join('spec', 'models'), path.join('spec', 'factories'))
                               .replace(resource, pluralize(resource))
                               .replace(/_spec\.rb/, '.rb')

    if fs.existsSync targetFile
      @open(targetFile)
    else
      @openDialog(targetFile)

  ## Private method
  createAssetFinderView: ->
    unless @assetFinderView?
      @assetFinderView = new AssetFinderView()

    @assetFinderView

  reloadCurrentEditor: ->
    @editor = atom.workspace.getActiveTextEditor()
    @currentFile = @editor.getPath()
    @cusorPos = @editor.getLastCursor().getBufferPosition()
    @currentBufferLine = @editor.getLastCursor().getCurrentBufferLine()

  open: (targetFile) ->
    return unless targetFile?
    files = if typeof(targetFile) is 'string' then [targetFile] else targetFile
    for file in files
      atom.workspace.open(file) if fs.existsSync(file)
  
  openDialog: (targetFile) ->
    if targetFile?
      atom.confirm
        message: "No #{targetFile} found"
        detailedMessage: "Shall we create #{targetFile} for you?"
        buttons:
          Yes: ->
            atom.workspace.open(targetFile)
            return
          No: ->
            atom.beep()
            return
    else
      atom.beep()
    

  partialFullPath: (currentFile, partialName) ->
    configExtension = atom.config.get('rails-transporter.viewFileExtension')
    
    if partialName.indexOf("/") is -1
      path.join(path.dirname(currentFile), "_#{partialName}.#{configExtension}")
    else
      path.join(atom.project.getPaths()[0], 'app', 'views', path.dirname(partialName), "_#{path.basename(partialName)}.#{configExtension}")

  assetFullPath: (assetName, type) ->
    fileName = path.basename(assetName)
    
    switch path.extname(assetName)
      when ".coffee", ".js", ".scss", ".css"
        ext = ''
      else
        ext = if type is 'javascripts' then '.js' else if 'stylesheets' then '.css'
        
    if assetName.match(/^\//)
      path.join(atom.project.getPaths()[0], 'public', path.dirname(assetName), "#{fileName}#{ext}")
    else
      for location in ['app', 'lib', 'vendor']
        baseName = path.join(atom.project.getPaths()[0], location, 'assets', type, path.dirname(assetName), fileName)
        if type is 'javascripts'
          for fullExt in ["#{ext}.erb", "#{ext}.coffee", "#{ext}.coffee.erb", ext]
            fullPath = baseName + fullExt
            return fullPath if fs.existsSync fullPath
          
        else if type is 'stylesheets'
          for fullExt in ["#{ext}.erb", "#{ext}.scss", "#{ext}.scss.erb", ext]
            fullPath = baseName + fullExt
            return fullPath if fs.existsSync fullPath
            
  concernPath: (concernsDir, currentBufferLine)->
    result = currentBufferLine.match(/include\s+(.+)/)
    
    if result?[1]?
      if result[1].indexOf('::') is -1
        path.join(concernsDir, changeCase.snakeCase(result[1])) + '.rb' 
      else
        concernPaths = (changeCase.snakeCase(concernName) for concernName in result[1].split('::'))
        path.join(concernsDir, concernPaths.join(path.sep)) + '.rb' 
          
    
          
