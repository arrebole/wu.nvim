-- 主题高亮表：组名 → nvim_set_hl 参数，全部从调色板取色。
-- 层次：编辑区透明（终端的模糊背景透上来），浮窗用半透明的玻璃底色，线条与次要文字尽量淡。
local M = {}

-- 按比例 t 把颜色 a 混向颜色 b，用于差异块等需要淡淡染色的底色。
local function mix(a, b, t)
  local x, y = tonumber(a:sub(2), 16), tonumber(b:sub(2), 16)
  local out = 0
  for _, shift in ipairs({ 65536, 256, 1 }) do
    local ca, cb = math.floor(x / shift) % 256, math.floor(y / shift) % 256
    out = out + math.floor(ca * (1 - t) + cb * t + 0.5) * shift
  end
  return ("#%06x"):format(out)
end

---@param c table 调色板，见 palette.lua
---@param opts { transparent: boolean }
function M.groups(c, opts)
  local bg = opts.transparent and "NONE" or c.bg
  local g = {}

  -- 窗口与边框
  g.Normal = { fg = c.fg, bg = bg }
  g.NormalNC = { link = "Normal" }
  g.NormalFloat = { fg = c.fg, bg = c.surface }
  g.FloatBorder = { fg = c.border, bg = c.surface }
  g.FloatTitle = { fg = c.subtle, bg = c.surface, bold = true }
  g.FloatFooter = { fg = c.muted, bg = c.surface }
  g.WinSeparator = { fg = c.border, bg = "NONE" }
  g.VertSplit = { link = "WinSeparator" }
  g.StatusLine = { fg = c.subtle, bg = bg }
  g.StatusLineNC = { fg = c.muted, bg = bg }
  g.TabLine = { fg = c.muted, bg = bg }
  g.TabLineSel = { fg = c.fg, bg = bg, bold = true }
  g.TabLineFill = { bg = bg }
  g.WinBar = { fg = c.subtle, bg = bg }
  g.WinBarNC = { fg = c.muted, bg = bg }
  g.MsgArea = { fg = c.subtle, bg = bg }

  -- 编辑区细节
  g.LineNr = { fg = c.faint }
  g.CursorLineNr = { fg = c.subtle }
  g.SignColumn = { bg = "NONE" }
  g.FoldColumn = { fg = c.faint }
  g.Folded = { fg = c.muted, bg = c.surface }
  g.CursorLine = { bg = c.raised }
  g.CursorColumn = { link = "CursorLine" }
  g.ColorColumn = { bg = c.surface }
  g.NonText = { fg = c.faint }
  g.EndOfBuffer = { fg = c.faint }
  g.Whitespace = { fg = c.faint }
  g.SpecialKey = { fg = c.faint }
  g.Conceal = { fg = c.muted }
  g.Cursor = { fg = c.bg, bg = c.fg }
  g.lCursor = { link = "Cursor" }
  g.TermCursor = { link = "Cursor" }
  g.Visual = { bg = c.overlay }
  g.VisualNOS = { link = "Visual" }
  g.Search = { fg = c.yellow, bg = c.overlay }
  g.CurSearch = { fg = c.bg, bg = c.yellow }
  g.IncSearch = { link = "CurSearch" }
  g.Substitute = { fg = c.bg, bg = c.red }
  g.MatchParen = { fg = c.bright, bg = c.overlay, bold = true }
  g.QuickFixLine = { bg = c.raised, bold = true }

  -- 补全菜单
  g.Pmenu = { fg = c.subtle, bg = c.surface }
  g.PmenuSel = { fg = c.bright, bg = c.overlay }
  g.PmenuKind = { fg = c.muted, bg = c.surface }
  g.PmenuExtra = { fg = c.muted, bg = c.surface }
  g.PmenuMatch = { fg = c.blue, bg = c.surface, bold = true }
  g.PmenuMatchSel = { fg = c.blue, bg = c.overlay, bold = true }
  g.PmenuSbar = { bg = c.surface }
  g.PmenuThumb = { bg = c.faint }
  g.WildMenu = { link = "PmenuSel" }

  -- 消息
  g.Title = { fg = c.bright, bold = true }
  g.Directory = { fg = c.blue }
  g.ModeMsg = { fg = c.subtle }
  g.MoreMsg = { fg = c.teal }
  g.Question = { fg = c.blue }
  g.ErrorMsg = { fg = c.red }
  g.WarningMsg = { fg = c.yellow }

  -- 差异与拼写
  g.DiffAdd = { bg = mix(c.bg, c.green, 0.18) }
  g.DiffChange = { bg = mix(c.bg, c.blue, 0.12) }
  g.DiffDelete = { fg = c.red, bg = mix(c.bg, c.red, 0.15) }
  g.DiffText = { bg = mix(c.bg, c.blue, 0.28) }
  g.Added = { fg = c.green }
  g.Changed = { fg = c.yellow }
  g.Removed = { fg = c.red }
  g.SpellBad = { undercurl = true, sp = c.red }
  g.SpellCap = { undercurl = true, sp = c.yellow }
  g.SpellRare = { undercurl = true, sp = c.purple }
  g.SpellLocal = { undercurl = true, sp = c.cyan }

  -- 语法：正文色为主，关键字、函数、字符串各占一种低饱和色。
  g.Comment = { fg = c.muted, italic = true }
  g.Constant = { fg = c.orange }
  g.String = { fg = c.green }
  g.Character = { link = "String" }
  g.Number = { fg = c.orange }
  g.Boolean = { fg = c.orange }
  g.Float = { link = "Number" }
  g.Identifier = { fg = c.fg }
  g.Function = { fg = c.blue }
  g.Statement = { fg = c.purple }
  g.Keyword = { fg = c.purple }
  g.Operator = { fg = c.subtle }
  g.PreProc = { fg = c.cyan }
  g.Type = { fg = c.cyan }
  g.Special = { fg = c.teal }
  g.Delimiter = { fg = c.subtle }
  g.SpecialComment = { fg = c.subtle, italic = true }
  g.Underlined = { underline = true }
  g.Error = { fg = c.red }
  g.Todo = { fg = c.bg, bg = c.yellow, bold = true }

  -- Treesitter：大多数捕获组由 Neovim 默认链接到上面的基础组，这里只补需要区分的。
  g["@variable"] = { fg = c.fg }
  g["@variable.builtin"] = { fg = c.red, italic = true }
  g["@variable.parameter"] = { fg = c.fg, italic = true }
  g["@variable.member"] = { fg = c.subtle }
  g["@property"] = { link = "@variable.member" }
  g["@constant.builtin"] = { fg = c.orange }
  g["@module"] = { fg = c.cyan }
  g["@function.builtin"] = { fg = c.cyan }
  g["@constructor"] = { fg = c.cyan }
  g["@keyword.return"] = { fg = c.purple, italic = true }
  g["@punctuation.bracket"] = { fg = c.subtle }
  g["@punctuation.delimiter"] = { fg = c.muted }
  g["@tag"] = { fg = c.blue }
  g["@tag.attribute"] = { fg = c.subtle, italic = true }
  g["@tag.delimiter"] = { fg = c.muted }
  g["@markup.heading"] = { fg = c.bright, bold = true }
  g["@markup.link"] = { fg = c.blue, underline = true }
  g["@markup.link.url"] = { fg = c.cyan, underline = true }
  g["@markup.raw"] = { fg = c.teal }
  g["@markup.list"] = { fg = c.muted }
  g["@markup.quote"] = { fg = c.subtle, italic = true }
  g["@markup.strong"] = { bold = true }
  g["@markup.italic"] = { italic = true }
  g["@comment.todo"] = { link = "Todo" }
  g["@comment.note"] = { fg = c.bg, bg = c.blue, bold = true }
  g["@comment.warning"] = { fg = c.bg, bg = c.yellow, bold = true }
  g["@comment.error"] = { fg = c.bg, bg = c.red, bold = true }
  g["@lsp.type.comment"] = {}

  -- 诊断与 LSP
  local levels = { Error = c.red, Warn = c.yellow, Info = c.blue, Hint = c.teal, Ok = c.green }
  for level, color in pairs(levels) do
    g["Diagnostic" .. level] = { fg = color }
    g["DiagnosticSign" .. level] = { fg = color }
    g["DiagnosticFloating" .. level] = { fg = color, bg = c.surface }
    g["DiagnosticVirtualText" .. level] = { fg = color, bg = mix(c.bg, color, 0.1) }
    g["DiagnosticUnderline" .. level] = { undercurl = true, sp = color }
  end
  g.DiagnosticUnnecessary = { fg = c.muted }
  g.DiagnosticDeprecated = { strikethrough = true, sp = c.muted }
  g.LspReferenceText = { bg = c.raised }
  g.LspReferenceRead = { link = "LspReferenceText" }
  g.LspReferenceWrite = { bg = c.raised, underline = true, sp = c.muted }
  g.LspInlayHint = { fg = c.muted, italic = true }
  g.LspSignatureActiveParameter = { fg = c.blue, bold = true }
  g.LspCodeLens = { fg = c.muted }

  -- 文件树：沿用编辑区的透明底，分隔线由 neo-tree/setup.lua 换成空格。
  g.NeoTreeNormal = { fg = c.subtle, bg = bg }
  g.NeoTreeNormalNC = { link = "NeoTreeNormal" }
  g.NeoTreeEndOfBuffer = { fg = c.bg, bg = bg }
  g.NeoTreeWinSeparator = { link = "NeoTreeNormal" }
  g.NeoTreeCursorLine = { bg = c.raised, bold = true }
  g.NeoTreeRootName = { fg = c.muted, bold = true }
  g.NeoTreeDirectoryName = { fg = c.subtle }
  g.NeoTreeDirectoryIcon = { fg = c.blue }
  g.NeoTreeFileName = { fg = c.subtle }
  g.NeoTreeFileNameOpened = { fg = c.bright, bold = true }
  g.NeoTreeIndentMarker = { fg = c.border }
  g.NeoTreeExpander = { fg = c.faint }
  g.NeoTreeDotfile = { fg = c.muted }
  g.NeoTreeHiddenByName = { link = "NeoTreeDotfile" }
  g.NeoTreeDimText = { fg = c.faint }
  g.NeoTreeMessage = { fg = c.muted, italic = true }
  g.NeoTreeModified = { fg = c.yellow }
  g.NeoTreeFilterTerm = { fg = c.blue, bold = true }
  g.NeoTreeFloatBorder = { link = "FloatBorder" }
  g.NeoTreeFloatTitle = { link = "FloatTitle" }
  g.NeoTreeTitleBar = { fg = c.bg, bg = c.blue }
  g.NeoTreeGitAdded = { fg = c.green }
  g.NeoTreeGitModified = { fg = c.yellow }
  g.NeoTreeGitDeleted = { fg = c.red }
  g.NeoTreeGitRenamed = { fg = c.purple }
  g.NeoTreeGitConflict = { fg = c.orange, bold = true }
  g.NeoTreeGitUntracked = { fg = c.teal, italic = true }
  g.NeoTreeGitIgnored = { fg = c.faint }
  g.NeoTreeGitUnstaged = { fg = c.orange }
  g.NeoTreeGitStaged = { fg = c.green }

  -- Git 标记
  g.GitSignsAdd = { fg = c.green }
  g.GitSignsChange = { fg = c.yellow }
  g.GitSignsDelete = { fg = c.red }
  g.GitSignsCurrentLineBlame = { fg = c.faint, italic = true }

  -- 命令行与消息（noice），以及本地 cmdpal：同一块玻璃。
  g.NoiceCmdlinePopup = { link = "NormalFloat" }
  g.NoiceCmdlinePopupBorder = { link = "FloatBorder" }
  g.NoiceCmdlinePopupTitle = { link = "FloatTitle" }
  g.NoiceCmdlinePopupBorderSearch = { link = "FloatBorder" }
  g.NoiceCmdlineIcon = { fg = c.blue }
  g.NoiceCmdlineIconSearch = { fg = c.yellow }
  g.NoiceMini = { fg = c.subtle, bg = c.surface }
  g.NoiceConfirm = { link = "NormalFloat" }
  g.NoiceConfirmBorder = { link = "FloatBorder" }
  g.NoicePopup = { link = "NormalFloat" }
  g.NoicePopupBorder = { link = "FloatBorder" }
  g.NoicePopupmenu = { link = "Pmenu" }
  g.NoicePopupmenuBorder = { link = "FloatBorder" }
  g.NoicePopupmenuSelected = { link = "PmenuSel" }
  g.NoicePopupmenuMatch = { link = "PmenuMatch" }
  g.NoiceLspProgressTitle = { fg = c.muted }
  g.NoiceLspProgressClient = { fg = c.subtle }
  g.CmdpalNormal = { link = "NormalFloat" }
  g.CmdpalBorder = { link = "FloatBorder" }
  g.CmdpalTitle = { link = "FloatTitle" }
  g.CmdpalPrompt = { fg = c.blue }

  -- 浮动终端（toggleterm、LazyGit、fzf）
  g.ToggleTermNormal = { link = "NormalFloat" }
  g.ToggleTermBorder = { link = "FloatBorder" }

  -- 启动面板
  g.DashboardTitle = { fg = c.bright, bold = true }
  g.DashboardMuted = { fg = c.muted }
  g.DashboardSection = { fg = c.subtle }
  g.DashboardRule = { fg = c.border }
  g.DashboardIndex = { fg = c.faint }
  g.DashboardIcon = { fg = c.blue }
  g.DashboardName = { fg = c.fg }
  g.DashboardPath = { fg = c.muted }
  g.DashboardKey = { fg = c.blue }
  g.DashboardSelected = { bg = c.raised }
  g.DashboardCursor = { fg = c.blue, bold = true }

  -- 缩进范围线
  g.MiniIndentscopeSymbol = { fg = c.faint }

  return g
end

return M
