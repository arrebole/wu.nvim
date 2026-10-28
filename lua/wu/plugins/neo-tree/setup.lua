vim.pack.add({
  { src = "https://github.com/nvim-lua/plenary.nvim" },
  { src = "https://github.com/MunifTanjim/nui.nvim" },
  { src = "https://github.com/nvim-tree/nvim-web-devicons" },
  { src = "https://github.com/nvim-neo-tree/neo-tree.nvim", version = vim.version.range("3") },
})

require("neo-tree").setup(require("wu.plugins.neo-tree.config"))

-- 文件树右侧的分隔线归文件树窗口所有，经 winhighlight 映射到 NeoTreeWinSeparator。
-- 默认链接到 WinSeparator（默认主题下为正文色，过亮），这里改用固定颜色，切换主题后重新设置。
local function separator()
  vim.api.nvim_set_hl(0, "NeoTreeWinSeparator", { fg = "#4a4c60", bg = "NONE" })
end
separator()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("LocalNeoTreeSeparator", { clear = true }),
  callback = separator,
})
