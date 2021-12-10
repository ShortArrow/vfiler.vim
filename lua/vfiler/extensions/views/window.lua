local core = require('vfiler/core')
local mapping = require('vfiler/mapping')
local vim = require('vfiler/vim')

local Window = {}
Window.__index = Window

function Window.new(options)
  return setmetatable({
    source_winid = vim.fn.win_getid(),
    options = core.table.copy(options),
    winid = 0,
    bufnr = 0,
    -- default buffer options
    bufoptions = {
      bufhidden = 'delete',
      buflisted = false,
      buftype = 'nofile',
      swapfile = false,
    },
    -- default window options
    winoptions = {
      colorcolumn = '',
      conceallevel =  2,
      concealcursor = 'nvc',
      foldcolumn = '0',
      foldenable = false,
      list = false,
      number = true,
      spell = false,
      wrap = false,
    },
  }, Window)
end

function Window:close()
  local winnr = vim.fn.bufwinnr(self.bufnr)
  if winnr >= 0 then
    vim.command(('silent %dquit!'):format(winnr))
  end
end

function Window:define_mapping(mappings, funcstr)
  return mapping.define(self.bufnr, mappings, funcstr)
end

function Window:open(name, texts)
  local option = self:_on_win_option(name, texts)
  self.winid = self:_on_open(name, texts, option)
  self.bufnr = vim.fn.winbufnr(self.winid)

  -- set buffer options
  vim.set_buf_options(self.bufnr, self.bufoptions)
  return self.winid
end

function Window:draw(name, texts)
  local winnr = self:winnr()
  vim.command('silent %delete _')
  vim.fn.setbufline(self.bufnr, 1, vim.to_vimlist(texts))

  -- set window options
  vim.set_win_options(winnr, self.winoptions)

  -- set name to statusline
  if name and #name > 0 then
    vim.set_win_option(winnr, 'statusline', name)
  end
end

function Window:set_buf_options(options)
  core.table.merge(self.bufoptions, options)
end

function Window:set_win_options(options)
  core.table.merge(self.winoptions, options)
end

function Window:winnr()
  return vim.fn.bufwinnr(self.bufnr)
end

function Window:_on_win_option(name, texts)
  local options = {
    layout = nil,
    width = 0,
    height = 0,
  }

  local wwidth = vim.fn.winwidth(self.source_winid)
  local wheight = vim.fn.winheight(self.source_winid)

  for _, layout in ipairs({'top', 'bottom', 'left', 'right'}) do
    local ops = self.options[layout]
    if ops then
      options.layout = layout
      if layout == 'top' or layout == 'bottom' then
        options.height = self:_winheight(wheight, ops, 1, wheight - 1, texts)
      elseif layout == 'right' or layout == 'left' then
        options.width = self:_winwidth(wwidth, ops, 1, wwidth - 1, texts)
      end
      break
    end
  end

  if not options.layout then
    core.message.error('Unsupported option.')
    return nil
  end
  return options
end

function Window:_on_open(name, texts, options)
  -- open window
  core.window.open(options.layout)
  vim.command('silent edit ' .. 'vfiler/' .. name)

  -- resize window
  if options.width > 0 then
    core.window.resize_width(options.width)
  end
  if options.height > 0 then
    core.window.resize_height(options.height)
  end
  return vim.fn.win_getid()
end

function Window:_winvalue(wvalue, value)
  local v = tonumber(value)
  if not v then
    core.message.error('Illegal config value: ' .. value)
    return
  end

  if tostring(value):match('%d+%.%d+') then
    -- float
    return math.floor(wvalue * v)
  end
  return v
end

function Window:_winheight(wheight, value, min, max, texts)
  local height = 0
  if value == 'auto' then
    height = #texts
  else
    height = self:_winvalue(wheight, value)
  end
  return math.floor(core.math.within(height, min, max))
end

function Window:_winwidth(wwidth, value, min, max, texts)
  local width = 0
  if value == 'auto' then
    for _, text in ipairs(texts) do
      local strwidth = vim.fn.strwidth(text)
      if width < strwidth then
        width = strwidth
      end
    end
  else
    width = self:_winvalue(wwidth, value)
  end
  return math.floor(core.math.within(width, min, max))
end

return Window
