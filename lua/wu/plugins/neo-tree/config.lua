return {
  -- 编辑窗口都关闭后不留下孤立的文件树。
  close_if_last_window = true,
  popup_border_style = "rounded",
  window = {
    position = "left",
    width = 32,
    mappings = {
      -- leader 是空格，释放给全局快捷键，这样在文件树里也能按 <leader>ee 关闭它。
      ["<space>"] = "none",
      ["l"] = "open",
      ["h"] = "close_node",
    },
  },
  -- 在文件树顶部显示来源切换栏，文件树和 Git 改动树都可以直接切换。
  -- source_selector = {
  --   winbar = true,
  --   tabs_layout = "center",
  --   sources = {
  --     { source = "filesystem" },
  --     { source = "git_status" },
  --   },
  -- },
  filesystem = {
    filtered_items = {
      -- 默认会隐藏点文件，并在目录末尾追加 "N hidden items"。
      -- 这里改为显示点文件，只彻底屏蔽版本库目录与系统杂项；按 H 仍可切换显示被过滤的项。
      hide_dotfiles = false,
      show_hidden_count = false,
      never_show = { ".git" },
    },
    follow_current_file = { enabled = true },
    use_libuv_file_watcher = true,
    -- 接管目录入口：nvim . 和 :edit <目录> 在当前窗口打开占满的文件树，打开文件后文件树转为侧边栏。
    hijack_netrw_behavior = "open_current",
  },
  event_handlers = {
    {
      -- 占满窗口的文件树打开文件时，文件会替换掉它；这时在侧边栏重新显示文件树，焦点留在文件上。
      -- 从侧边栏打开文件时文件树仍在，不做处理。
      event = "file_opened",
      handler = function()
        vim.schedule(function()
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree" then return end
          end
          require("neo-tree.command").execute({ action = "show", source = "filesystem", dir = vim.fn.getcwd() })
        end)
      end,
    },
  },
}
