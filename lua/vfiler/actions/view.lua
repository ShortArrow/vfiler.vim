local api = require('vfiler/actions/api')
local sort = require('vfiler/sort')

local Menu = require('vfiler/extensions/menu')

local M = {}

function M.change_sort(vfiler, context, view)
  local menu = Menu.new(vfiler, 'Select Sort', {
    initial_items = sort.types(),
    default = context.options.sort,

    on_selected = function(filer, c, v, sort_type)
      if c.options.sort == sort_type then
        return
      end

      local item = v:get_item()
      c.options.sort = sort_type
      v:draw(c)
      v:move_cursor(item.path)
    end,
  })
  api.start_extension(vfiler, context, view, menu)
end

function M.toggle_show_linenumber(vfiler, context, view)
  local options = context.options
  options.show_linenumber = not options.show_linenumber
  view:draw(context)
end

function M.toggle_show_hidden(vfiler, context, view)
  local options = context.options
  options.show_hidden_files = not options.show_hidden_files
  view:draw(context)
end

function M.toggle_sort(vfiler, context, view)
  local sort_type = context.options.sort
  if sort_type:match('^%l') ~= nil then
    context.options.sort = sort_type:sub(1, 1):upper() .. sort_type:sub(2)
  else
    context.options.sort = sort_type:sub(1, 1):lower() .. sort_type:sub(2)
  end
  view:draw(context)
end

return M
