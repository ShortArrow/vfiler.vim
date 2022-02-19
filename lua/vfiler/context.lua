local core = require('vfiler/libs/core')
local fs = require('vfiler/libs/filesystem')
local git = require('vfiler/libs/git')
local vim = require('vfiler/libs/vim')

local Directory = require('vfiler/items/directory')

local function expand(root, attribute)
  for _, child in ipairs(root.children) do
    local opened = attribute.opened_attributes[child.name]
    if opened then
      child:open()
      expand(child, opened)
    end

    local selected = attribute.selected_names[child.name]
    if selected then
      child.selected = true
    end
  end
  return root
end

------------------------------------------------------------------------------
-- ItemAttribute class
------------------------------------------------------------------------------
local ItemAttribute = {}
ItemAttribute.__index = ItemAttribute

function ItemAttribute.copy(attribute)
  local root_attr = ItemAttribute.new(attribute.name)
  for name, attr in pairs(attribute.opened_attributes) do
    root_attr.opened_attributes[name] = ItemAttribute.copy(attr)
  end
  for name, selected in pairs(attribute.selected_names) do
    root_attr.selected_names[name] = selected
  end
  return root_attr
end

function ItemAttribute.parse(root)
  local root_attr = ItemAttribute.new(root.name)
  if not root.children then
    return root_attr
  end
  for _, child in ipairs(root.children) do
    if child.opened then
      root_attr.opened_attributes[child.name] = ItemAttribute.parse(child)
    end
    if child.selected then
      root_attr.selected_names[child.name] = true
    end
  end
  return root_attr
end

function ItemAttribute.new(name)
  return setmetatable({
    name = name,
    opened_attributes = {},
    selected_names = {},
  }, ItemAttribute)
end

------------------------------------------------------------------------------
-- Session class
------------------------------------------------------------------------------

local Session = {}
Session.__index = Session

function Session.new()
  return setmetatable({
    _drives = {},
    _attributes = {},
  }, Session)
end

function Session:copy()
  local new = Session.new()
  new._drives = core.table.copy(self._drives)
  for path, attribute in pairs(self._attributes) do
    new._attributes[path] = {
      previus_path = attribute.previus_path,
      object = ItemAttribute.copy(attribute.object),
    }
  end
  return new
end

function Session:get_previous_path(rootpath)
  local attribute = self._attributes[rootpath]
  if not attribute then
    return nil
  end
  return attribute.previus_path
end

function Session:save(root, path)
  local drive = core.path.root(root.path)
  self._drives[drive] = root.path
  self._attributes[root.path] = {
    previus_path = path,
    object = ItemAttribute.parse(root),
  }
end

function Session:load(root)
  local attribute = self._attributes[root.path]
  if not attribute then
    return nil
  end
  expand(root, attribute.object)
  return attribute.previus_path
end

function Session:load_dirpath(drive)
  local dirpath = self._drives[drive]
  if not dirpath then
    return nil
  end
  return dirpath
end

------------------------------------------------------------------------------
-- Context class
------------------------------------------------------------------------------

local Context = {}
Context.__index = Context

--- Create a context object
---@param configs table
function Context.new(configs)
  local self = setmetatable({}, Context)
  self:_initialize()
  self.options = core.table.copy(configs.options)
  self.events = core.table.copy(configs.events)
  self.mappings = core.table.copy(configs.mappings)
  self._session = Session.new()
  self._git_enabled = self:_check_git_enabled()
  return self
end

--- Copy to context
function Context:copy()
  local configs = {
    options = self.options,
    events = self.events,
    mappings = self.mappings,
  }
  local new = Context.new(configs)
  new._session = self._session:copy()
  return new
end

--- Save the path in the current context
---@param path string
function Context:save(path)
  if not self.root then
    return
  end
  self._session:save(self.root, path)
end

function Context:duplicate()
  local new = setmetatable({}, Context)
  new:_initialize()
  new:reset(self)
  new._session = self._session:copy()
  return new
end

--- Get the parent directory path of the current context
function Context:parent_path()
  if self.root.parent then
    return self.root.parent.path
  end
  return core.path.parent(self.root.path)
end

--- Switch the context to the specified directory path
---@param dirpath string
function Context:switch(dirpath)
  dirpath = core.path.normalize(dirpath)
  -- perform auto cd
  if self.options.auto_cd then
    vim.fn.execute('lcd ' .. dirpath, 'silent')
  end

  local previus_path = self._session:get_previous_path(dirpath)

  -- reload git status
  local job
  if self._git_enabled then
    if not (self.gitroot and dirpath:match(self.gitroot)) then
      self.gitroot = git.get_toplevel(dirpath)
    end
    if self.gitroot then
      job = self:_reload_gitstatus_job()
    end
  end

  self.root = Directory.new(fs.stat(dirpath))
  self.root:open()
  self._session:load(self.root)

  if job then
    job:wait()
  end
  return previus_path
end

--- Switch the context to the specified drive path
---@param drive string
function Context:switch_drive(drive)
  local dirpath = self._session:load_dirpath(drive)
  if not dirpath then
    dirpath = drive
  end
  return self:switch(dirpath)
end

--- Synchronize with other context
---@param context table
function Context:sync(context)
  self._session:save(context.root, context.root.path)
  return self:switch(context.root.path)
end

--- Update from another context
---@param context table
function Context:update(context)
  self.options = core.table.copy(context.options)
  self.mappings = core.table.copy(context.mappings)
  self.events = core.table.copy(context.events)
  self._git_enabled = self:_check_git_enabled()
end

function Context:_check_git_enabled()
  if not self.options.git.enabled or vim.fn.executable('git') ~= 1 then
    return false
  end
  return self.options.columns:match('git%w*') ~= nil
end

function Context:_initialize()
  self.clipboard = nil
  self.extension = nil
  self.linked = nil
  self.root = nil
  self.gitroot = nil
  self.gitstatus = {}
  self.in_preview = {
    preview = nil,
    once = false,
  }
end

function Context:_reload_gitstatus_job()
  local git_options = self.options.git
  local options = {
    untracked = git_options.untracked,
    ignored = git_options.ignored,
  }
  return git.reload_status(self.gitroot, options, function(status)
    self.gitstatus = status
  end)
end

return Context
