-- tabby 在 setup 时立即设置 tabline，渲染函数定义在它的 plugin/ 脚本里，需要立刻加载。
vim.pack.add({
  {
    src = "https://github.com/nanozuki/tabby.nvim",
    version = vim.version.range("2"),
  },
  "https://github.com/nvim-tree/nvim-web-devicons",
}, { load = true })

require("wu.plugins.tabline").setup(require("wu.plugins.tabline.config"))
