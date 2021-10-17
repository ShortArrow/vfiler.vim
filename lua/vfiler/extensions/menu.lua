local config = require 'vfiler/extensions/config'
local core = require 'vfiler/core'
local mapping = require 'vfiler/mapping'
local vim = require 'vfiler/vim'

local ExtensionMenu = {}

mapping.setup {
  menu = {
    ['k'] = [[:lua require'vfiler/extensions/menu/action'.do_action('move_cursor_up', true)]],
    ['j'] = [[:lua require'vfiler/extensions/menu/action'.do_action('move_cursor_down', true)]],
    ['q'] = [[:lua require'vfiler/extensions/menu/action'.do_action('quit')]],
    ['<CR>'] = [[:lua require'vfiler/extensions/menu/action'.do_action('select')]],
    ['<ESC>'] = [[:lua require'vfiler/extensions/menu/action'.do_action('quit')]],
    ['gg'] = [[:lua require'vfiler/extensions/menu/action'.do_action('quit')]],
  },
}

function ExtensionMenu.new(name, context)
  local Extension = require('vfiler/extensions/extension')
  local view = Extension.create_view(config.configs.layout, 'menu')
  view:set_buf_options {
    filetype = 'vfiler_extension_menu',
    modifiable = false,
    modified = false,
    readonly = true,
  }
  view:set_win_options {
    number = true,
  }
  return core.inherit(ExtensionMenu, Extension, name, context, view, config)
end

function ExtensionMenu:select()
  local item = self.items[vim.fn.line('.')]

  self:quit()

  if self.on_selected then
    self.on_selected(item)
  end
  return item
end

function ExtensionMenu:_on_get_texts(items)
  return items
end

function ExtensionMenu:_on_draw(texts)
  vim.set_buf_option('modifiable', true)
  vim.set_buf_option('readonly', false)

  self.view:draw(texts)

  vim.set_buf_option('modifiable', false)
  vim.set_buf_option('readonly', true)
end

return ExtensionMenu
