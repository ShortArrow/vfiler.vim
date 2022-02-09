local action_modules = {
  'bookmark',
  'buffer',
  'cursor',
  'event',
  'file',
  'item',
  'preview',
  'view',
}

local M = setmetatable({}, {
  __index = function(t, key)
    for _, name in ipairs(action_modules) do
      local module = require('vfiler/actions/' .. name)
      local func = module[key]
      if func then
        t[key] = func
        return func
      end
    end
    error(('"%s" action is undefined.'):format(key))
    return nil
  end,
})

return M
