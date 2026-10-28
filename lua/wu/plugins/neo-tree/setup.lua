vim.pack.add({
  { src = "https://github.com/nvim-lua/plenary.nvim" },
  { src = "https://github.com/MunifTanjim/nui.nvim" },
  { src = "https://github.com/nvim-tree/nvim-web-devicons" },
  { src = "https://github.com/nvim-neo-tree/neo-tree.nvim", version = vim.version.range("3") },
})

require("neo-tree").setup(require("wu.plugins.neo-tree.config"))

-- 文件树右侧的分隔线归文件树窗口所有：在文件树窗口里把竖线字符换成空格，
-- 这一列的颜色（NeoTreeWinSeparator）由主题设为文件树底色，看起来像文件树的右边距。
require("neo-tree.events").subscribe({
  event = "neo_tree_window_after_open",
  id = "wu-neo-tree-separator",
  handler = function(args)
    local win = args and args.winid
    if not (win and vim.api.nvim_win_is_valid(win)) then return end
    local chars = vim.opt.fillchars:get()
    for _, name in ipairs({ "vert", "vertleft", "vertright", "verthoriz" }) do chars[name] = " " end
    local items = {}
    for name, char in pairs(chars) do items[#items + 1] = name .. ":" .. char end
    vim.wo[win].fillchars = table.concat(items, ",")
  end,
})
