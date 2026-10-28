-- wu.nvim 对外入口。
-- 作为插件使用：由外部 init.lua 调用 require("wu").setup()
-- 作为独立配置使用：克隆到 ~/.config/nvim 后由顶层 init.lua 调用。
local M = {}

---@param opts table|nil 预留的配置项，当前为空。
function M.setup(opts)
  opts = opts or {}

  -- 禁用 netrw，让 neo-tree 接管目录入口；必须在 BufEnter 触发前完成。
  vim.g.loaded_netrw = 1
  vim.g.loaded_netrwPlugin = 1

  -- 偏好配置，必须在插件与快捷键之前加载。
  require("wu.settings")

  -- 主题先于插件加载：插件用 default 定义的高亮不会覆盖主题。
  require("wu.plugins.theme.setup")

  -- 插件与本地实现。
  require("wu.plugins.neo-tree.setup")
  require("wu.plugins.fzf.setup")
  require("wu.plugins.smear-cursor.setup")
  require("wu.plugins.indentscope.setup")
  require("wu.plugins.tabline.setup")
  require("wu.plugins.statusline.setup")
  require("wu.plugins.gitsigns.setup")
  require("wu.plugins.lazygit.setup")
  require("wu.plugins.toggleterm.setup")
  require("wu.plugins.noice.setup")
  require("wu.plugins.dashboard.setup")

  -- 自定义快捷键。
  require("wu.keymaps")
end

return M
