-- 标签栏为本地实现；文件图标来自 nvim-web-devicons，未安装时使用统一的文件图标。
vim.pack.add({ "https://github.com/nvim-tree/nvim-web-devicons" }, { load = true })

require("wu.plugins.tabline").setup(require("wu.plugins.tabline.config"))
