
vim.pack.add({
  "https://github.com/sphamba/smear-cursor.nvim",
})

-- 背景透明时拖尾无法取到底色来渐变，用主题底色代替。
require('smear_cursor').setup({
  transparent_bg_fallback_color = require("wu.plugins.theme").palette.bg,
})
