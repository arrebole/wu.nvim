-- 顶部标签栏：左侧列出当前工作空间里打开的文件，右侧显示当前工作空间（tabpage）的编号。
-- 当前项用正文色加粗，其余项弱化为灰阶；颜色与状态栏共用调色板，背景跟随编辑区。
local buffers = require("wu.plugins.tabline.buffers")
local workspaces = require("wu.plugins.tabline.workspaces")
local palette = require("wu.plugins.statusline.palette")

local M = {}
local api = vim.api

local defaults = {
  -- 需要 Nerd Font；关闭后使用纯文本标记。
  icons = true,
}
local options = vim.deepcopy(defaults)
local colors
-- 已创建的动态高亮组，切换配色方案后失效。
local defined = {}

local MARKS = {
  -- left / right 为工作空间色块两端的圆角。
  icons = { file = "\u{f016}", modified = "●", close = "\u{f00d}", left = "\u{e0b6}", right = "\u{e0b4}" },
  text = { modified = "+", close = "x", left = "", right = "" },
}

-- 标签项之间的留白，以及栏两端的边距。
local GAP, PAD = "  ", " "

-- 点击区域只能调用全局函数，minwid 传 buffer 编号。
_G.WuTabline = {
  -- 左键切换，中键或右键关闭。
  open = function(bufnr, _, button)
    if button == "l" then buffers.open(bufnr) else buffers.close(bufnr) end
  end,
  close = function(bufnr) buffers.close(bufnr) end,
}

-- 按颜色组合生成高亮组，避免为每种组合手写定义。
local function hl(fg, bold, bg)
  bg = bg or colors.bar
  local name = ("LocalTabline_%s_%s%s"):format(fg:gsub("#", ""), bg:gsub("#", ""), bold and "_b" or "")
  if not defined[name] then
    api.nvim_set_hl(0, name, { fg = fg, bg = bg, bold = bold })
    defined[name] = true
  end
  return "%#" .. name .. "#"
end

-- 文件名等外部文本不能直接放进 tabline 格式串。
local function escape(text)
  return (text:gsub("%c", " "):gsub("%%", "%%%%"))
end

-- 文本块：{ 文本, fg = 前景色, bg = 背景色, bold = 是否加粗, click = 点击区域起始标记 }。
-- 拼成标签项时记下显示宽度，空间不足时据此取舍。
local function item(chunks)
  local parts, width = {}, 0
  for _, chunk in ipairs(chunks) do
    local text = hl(chunk.fg or colors.text, chunk.bold, chunk.bg) .. escape(chunk[1])
    parts[#parts + 1] = chunk.click and chunk.click .. text .. "%X" or text
    width = width + api.nvim_strwidth(chunk[1])
  end
  return { text = table.concat(parts), width = width }
end

local function join(items, first, last)
  local parts, width = {}, 0
  for i = first or 1, last or #items do
    parts[#parts + 1] = items[i].text
    width = width + items[i].width
  end
  return {
    text = table.concat(parts, hl(colors.text) .. GAP),
    width = width + math.max(0, #parts - 1) * #GAP,
  }
end

-- 当前工作空间的编号，包在强调色的圆角色块里；有多个工作空间时附上总数，例如 "2/3"。
local function workspace(marks)
  local number = api.nvim_tabpage_get_number(workspaces.current())
  local total = #workspaces.list()
  local fill = colors.modes.normal
  local chunks = {
    { marks.left, fg = fill },
    { " " .. number, fg = colors.base, bg = fill, bold = true },
  }
  if total > 1 then
    chunks[#chunks + 1] = { "/" .. total, fg = colors.base, bg = fill }
  end
  chunks[#chunks + 1] = { " ", bg = fill }
  chunks[#chunks + 1] = { marks.right, fg = fill }
  return item(chunks)
end

local devicons
local function icon(bufnr, marks)
  if devicons == nil then
    local ok, module = pcall(require, "nvim-web-devicons")
    devicons = ok and module or false
  end
  if devicons then
    local name = vim.fn.fnamemodify(api.nvim_buf_get_name(bufnr), ":t")
    local glyph, color = devicons.get_icon_color(name, vim.fn.fnamemodify(name, ":e"), { default = true })
    if glyph then return glyph, color end
  end
  return marks.file, colors.muted
end

-- 有诊断时用最严重一级的颜色给文件名着色，代替数字提示。
local function tint(bufnr, current)
  local counts = vim.diagnostic.count(bufnr)
  for _, name in ipairs({ "error", "warn" }) do
    if counts[vim.diagnostic.severity[name:upper()]] then return colors.diagnostics[name] end
  end
  return current and colors.text or colors.muted
end

-- 只有当前文件带图标颜色与关闭按钮，未保存的文件始终显示圆点。
local function buffer(bufnr, name, current, marks)
  local open = ("%%%d@v:lua.WuTabline.open@"):format(bufnr)
  local close = ("%%%d@v:lua.WuTabline.close@"):format(bufnr)
  local chunks = {}
  if options.icons then
    local glyph, color = icon(bufnr, marks)
    chunks[#chunks + 1] = { glyph .. " ", fg = current and color or colors.faint, click = open }
  end
  chunks[#chunks + 1] = { name, fg = tint(bufnr, current), bold = current, click = open }
  if vim.bo[bufnr].modified then
    chunks[#chunks + 1] = { " " .. marks.modified, fg = colors.modes.command, click = close }
  elseif current then
    chunks[#chunks + 1] = { " " .. marks.close, fg = colors.faint, click = close }
  end
  return item(chunks)
end

-- 焦点在浮动终端等工具窗口时，以上一个窗口里的文件为当前文件。
local function focused(list)
  local index = vim.fn.index(list, api.nvim_get_current_buf())
  if index < 0 then
    index = vim.fn.index(list, api.nvim_win_get_buf(vim.fn.win_getid(vim.fn.winnr("#"))))
  end
  return index >= 0 and index + 1 or nil
end

-- 空间不足时以当前文件为中心向两侧扩展，被省略的数量显示在两端。
local function fit(items, focus, room)
  local function span(first, last)
    local width = (last - first) * #GAP
    for i = first, last do width = width + items[i].width end
    if first > 1 then width = width + #tostring(first - 1) + 1 + #GAP end
    if last < #items then width = width + #tostring(#items - last) + 1 + #GAP end
    return width
  end

  local first, last = focus, focus
  local grew = true
  while grew do
    grew = false
    if last < #items and span(first, last + 1) <= room then last, grew = last + 1, true end
    if first > 1 and span(first - 1, last) <= room then first, grew = first - 1, true end
  end
  return first, last
end

-- 左侧贴边的文件树窗口；标签栏在它的上方留出同宽的区域。
local function sidebar()
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if vim.bo[api.nvim_win_get_buf(win)].filetype == "neo-tree"
      and api.nvim_win_get_config(win).relative == ""
      and api.nvim_win_get_position(win)[2] == 0 then
      return win
    end
  end
end

-- 文件树上方的区域：显示树的根目录名，末尾用分隔线接上窗口边框。
local function offset()
  local win = sidebar()
  if not win then return { text = "", width = 0 } end
  local width = api.nvim_win_get_width(win)
  local root = vim.fn.fnamemodify(vim.fn.getcwd(win), ":t")
  local title = vim.fn.strcharpart(" " .. root, 0, width)
  local fill = width - api.nvim_strwidth(title)
  return {
    text = hl(colors.muted, true) .. escape(title) .. hl(colors.text) .. (" "):rep(fill)
      .. hl(colors.faint) .. "│",
    width = width + 1,
  }
end

-- 被省略的文件数，before 为真时放在列表左侧。
local function more(count, before)
  if count == 0 then return "" end
  local mark, gap = hl(colors.faint) .. "+" .. count, hl(colors.text) .. GAP
  return before and mark .. gap or gap .. mark
end

function M.render()
  colors = colors or palette.resolve()
  local marks = MARKS[options.icons and "icons" or "text"]

  local right = workspace(marks)
  local tree = offset()

  local list = buffers.list()
  local names = buffers.names(list)
  local focus = focused(list)
  local left = {}
  for i, bufnr in ipairs(list) do
    left[i] = buffer(bufnr, names[bufnr], i == focus, marks)
  end

  local head = ""
  if #left > 0 then
    local room = vim.o.columns - tree.width - right.width - #PAD * 2 - #GAP
    local first, last = fit(left, focus or 1, room)
    head = more(first - 1, true) .. join(left, first, last).text .. more(#left - last, false)
  end

  local blank = hl(colors.text)
  return tree.text .. blank .. PAD .. head .. blank .. "%=" .. right.text .. blank .. PAD
end

-- 配色变化后丢弃缓存，下次渲染时重新取色。
local function refresh()
  colors, defined = palette.resolve(), {}
  api.nvim_set_hl(0, "TabLineFill", { bg = colors.bar })
end

function M.setup(opts)
  options = vim.tbl_deep_extend("force", defaults, opts or {})
  workspaces.setup()
  refresh()
  vim.o.showtabline = 2
  vim.o.tabline = "%!v:lua.require'wu.plugins.tabline'.render()"

  local group = api.nvim_create_augroup("LocalTabline", { clear = true })
  api.nvim_create_autocmd("ColorScheme", { group = group, callback = refresh })
  api.nvim_create_autocmd("OptionSet", { group = group, pattern = "background", callback = refresh })
  -- 窗口开合与尺寸变化时重新计算文件树上方的留白。
  api.nvim_create_autocmd({ "DirChanged", "DiagnosticChanged", "BufModifiedSet", "WinNew", "WinClosed", "WinResized", "BufWinEnter" }, {
    group = group,
    command = "redrawtabline",
  })
end

return M
