local core = require 'vfiler/core'
local vim = require 'vfiler/vim'

local M = {}

M.configs = {
  layout = {
    --top = 6,
    --top = 'auto',
    floating = {
      width = 'auto',
      height = 'auto',
      minwidth = 30,
      minheight = 5,
      relative = true,
    },
  },
}

function M.setup(configs)
  return core.merge_table(M.configs, configs)
end

return M
