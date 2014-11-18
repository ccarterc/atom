app = require 'app'
ChildProcess = require 'child_process'
fs = require 'fs'
path = require 'path'

updateDotExe = path.resolve(path.dirname(process.execPath), '..', 'Update.exe')
exeName = path.basename(process.execPath)

# Spawn the Update.exe with the given arguments and invoke the callback when
# the command completes.
exports.spawn = (args, callback) ->
  updateProcess = ChildProcess.spawn(updateDotExe, args)

  stdout = ''
  updateProcess.stdout.on 'data', (data) -> stdout += data

  error = null
  updateProcess.on 'error', (processError) -> error ?= processError
  updateProcess.on 'close', (code, signal) ->
    error ?= new Error("Command failed: #{signal ? code}") if code isnt 0
    error?.code ?= code
    error?.stdout ?= stdout
    callback(error, stdout)

  undefined

# Is the Update.exe installed with Atom?
exports.existsSync = ->
  fs.existsSync(updateDotExe)

installContextMenu = (callback) ->
  fileKeyPath = 'HKCU\\Software\\Classes\\*\\shell\\Atom'
  directoryKeyPath = 'HKCU\\Software\\Classes\\directory\\shell\\Atom'
  backgroundKeyPath = 'HKCU\\Software\\Classes\\directory\\background\\shell\\Atom'

  spawnReg = (args, callback) ->
    args.unshift('add')
    regProcess = ChildProcess.spawn('reg.exe', args)

    error = null
    regProcess.on 'error', (processError) -> error ?= processError
    regProcess.on 'close', (code, signal) ->
      error ?= new Error("Command failed: #{signal ? code}") if code isnt 0
      error?.code ?= code
      callback(error)

  installMenu = (keyPath, callback) ->
    args = [keyPath, '/ve', '/d', 'Open with Atom', '/f']
    spawnReg args, ->
      args = [keyPath, '/v', 'Icon', '/d', process.execPath, '/f']
      spawnReg args, ->
        args = ["#{keyPath}\\command", '/ve', '/d', process.execPath, '/f']
        spawnReg(args, callback)

  installMenu fileKeyPath, ->
    installMenu directoryKeyPath, ->
      installMenu(backgroundKeyPath, callback)

# Handle squirrel events denoted by --squirrel-* command line arguments.
exports.handleStartupEvent = ->
  switch process.argv[1]
    when '--squirrel-install', '--squirrel-updated'
      exports.spawn ['--createShortcut', exeName], ->
        installContextMenu ->
          app.quit()
      true
    when '--squirrel-uninstall'
      exports.spawn ['--removeShortcut', exeName], -> app.quit()
      true
    when '--squirrel-obsolete'
      app.quit()
      true
    else
      false
