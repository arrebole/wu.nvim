-- wu 主题：极简毛玻璃风格，统一管理编辑器与各插件的配色。
-- 编辑区背景透明，由终端的半透明 / 模糊背景提供"玻璃"；浮窗用略亮的底色加 winblend，像叠在上面的一层磨砂玻璃。
local palette = require("wu.plugins.theme.palette")
local highlights = require("wu.plugins.theme.highlights")

local M = {}

local defaults = {
  -- 编辑区、文件树、状态栏不铺底色，透出终端背景；终端不透明时可关闭。
  transparent = true,
  -- 浮窗与补全菜单的透明度（0-100）。
  winblend = 12,
}
local options = vim.deepcopy(defaults)

M.palette = palette

function M.options()
  return options
end

-- 由 colors/wu.lua 调用，也可以直接调用。
function M.load()
  if vim.g.colors_name then vim.cmd("highlight clear") end
  vim.o.termguicolors = true
  vim.o.background = "dark"
  vim.g.colors_name = "wu"

  for name, spec in pairs(highlights.groups(palette, options)) do
    vim.api.nvim_set_hl(0, name, spec)
  end

  -- 内置终端的 16 色。
  local c = palette
  local ansi = {
    c.raised, c.red, c.green, c.yellow, c.blue, c.purple, c.cyan, c.subtle,
    c.muted, c.red, c.green, c.yellow, c.blue, c.purple, c.cyan, c.bright,
  }
  for i, color in ipairs(ansi) do vim.g["terminal_color_" .. (i - 1)] = color end
end

-- 当前是否在使用 wu 主题；其他模块据此决定直接取调色板还是从高亮组推算。
function M.active()
  return vim.g.colors_name == "wu"
end

function M.setup(opts)
  options = vim.tbl_extend("force", defaults, opts or {})
  vim.o.winblend = options.winblend
  vim.o.pumblend = options.winblend
  vim.cmd.colorscheme("wu")
end

return M
