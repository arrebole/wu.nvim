return {
  -- 可用组件：mode / branch / diagnostics / filetype / encoding / position
  sections = {
    left = { "mode", "branch" },
    right = { "diagnostics", "filetype", "encoding", "position" },
  },
  -- 窗口宽度低于阈值时隐藏组件，窄窗口只保留模式和光标位置。
  min_width = { branch = 60, diagnostics = 80, filetype = 60, encoding = 100 },
  separator = " · ",
  -- 需要 Nerd Font；关闭后使用纯文本标记。
  icons = true,
}
