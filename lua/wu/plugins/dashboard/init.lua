-- 启动面板：列出最近打开的目录，参考 dashboard-nvim 的设计，本地独立实现。
-- 面板内容整体居中；j/k 移动选中行，Enter 或数字键打开目录，d 删除记录。
local history = require("wu.plugins.dashboard.history")

local M = {}
local api = vim.api
-- 文字高亮与选中行高亮分开，移动选中行时不必重绘整个面板。
local ns = api.nvim_create_namespace("LocalDashboard")
local selection_ns = api.nvim_create_namespace("LocalDashboardSelection")

local defaults = {
  -- 面板内容的最大宽度。
  width = 72,
  -- 最多列出的目录数；数字键只覆盖前 9 个。
  recent_limit = 9,
  -- 需要 Nerd Font；关闭后不显示目录图标。
  icons = true,
}
local options = vim.deepcopy(defaults)
local FOLDER = "\u{f07b}"

-- 当前面板：{ buf, windows = 窗口原有选项, rows = 可选中的行, selected, chrome = 隐藏前的栏位设置 }。
local state
local stdin_seen = false

-- 面板窗口的外观，进入时记下原值，离开时还原。选中行由 extmark 绘制，不用 cursorline。
local window_options = {
  number = false, relativenumber = false, signcolumn = "no", foldcolumn = "0",
  cursorline = false, cursorcolumn = false, wrap = false, list = false,
  spell = false, colorcolumn = "", winbar = "", statuscolumn = "",
}

-- 全部链接到配色方案已有的组，切换主题后自动跟随；default 让用户可以覆盖。
local function highlights()
  for name, link in pairs({
    Title = "Title",
    Muted = "Comment",
    Section = "Directory",
    Rule = "NonText",
    Index = "Comment",
    Icon = "Directory",
    Name = "Normal",
    Path = "Comment",
    Key = "Special",
    Selected = "CursorLine",
    Cursor = "Function",
  }) do
    api.nvim_set_hl(0, "Dashboard" .. name, { link = link, default = true })
  end
end

-- 没有名字也没有内容的普通 buffer，即启动时 nvim 或文件树自动留下的空白文件。
local function blank(buf)
  return vim.bo[buf].buftype == "" and not vim.bo[buf].modified and api.nvim_buf_get_name(buf) == ""
    and api.nvim_buf_line_count(buf) == 1 and api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

local width_of = vim.fn.strdisplaywidth

-- 截断到指定显示宽度，超出部分用省略号代替；tail 为真时保留结尾，用于路径。
local function truncate(text, width, tail)
  text = tostring(text):gsub("%c", " ")
  if width_of(text) <= width then return text end
  if width < 1 then return "" end
  local chars = vim.fn.strchars(text)
  local function keep(n)
    return tail and vim.fn.strcharpart(text, chars - n) or vim.fn.strcharpart(text, 0, n)
  end
  local n = chars
  while n > 0 and width_of(keep(n)) > width - 1 do n = n - 1 end
  return tail and "…" .. keep(n) or keep(n) .. "…"
end

---------------------------------------------------------------------------
-- 窗口外观
---------------------------------------------------------------------------

local function show_chrome()
  if state and state.chrome then
    vim.o.laststatus, vim.o.showtabline = state.chrome.laststatus, state.chrome.showtabline
    state.chrome = nil
  end
end

-- 面板独占屏幕时隐藏标签栏与状态栏；与文件树等窗口并排时保留，
-- 这样焦点在窗口间切换不会让布局上下跳动。
local function sync_chrome()
  if not state then return end
  local editors = vim.tbl_filter(function(win)
    return api.nvim_win_get_config(win).relative == ""
  end, api.nvim_tabpage_list_wins(0))
  if vim.fn.bufwinid(state.buf) == -1 or #editors > 1 then return show_chrome() end
  if not state.chrome then
    state.chrome = { laststatus = vim.o.laststatus, showtabline = vim.o.showtabline }
    vim.o.laststatus, vim.o.showtabline = 0, 0
  end
end

local function decorate(win)
  sync_chrome()
  if not state.windows[win] then
    local saved = {}
    for name in pairs(window_options) do saved[name] = vim.wo[win][name] end
    state.windows[win] = saved
  end
  for name, value in pairs(window_options) do vim.wo[win][name] = value end
end

local function restore()
  if not state then return end
  show_chrome()
  for win, saved in pairs(state.windows) do
    if api.nvim_win_is_valid(win) then
      for name, value in pairs(saved) do vim.wo[win][name] = value end
    end
  end
  state.windows = {}
end

---------------------------------------------------------------------------
-- 版面：先按内容宽度排出一组行，再统一放进 buffer
-- 一行是若干文本段 { 文本, 高亮组 }；align = "center" 表示整行居中，path 表示这是可选中的目录行。
---------------------------------------------------------------------------

local HINTS = { { "↵", "打开" }, { "1-9", "快速打开" }, { "d", "删除记录" }, { "q", "退出" } }

local function measure(line)
  local width = 0
  for _, segment in ipairs(line) do width = width + width_of(segment[1]) end
  return width
end

local function gap(width)
  return { (" "):rep(math.max(0, width)) }
end

-- 左右两端对齐的一行。
local function justify(left, right, width)
  return { left, gap(width - width_of(left[1]) - width_of(right[1])), right }
end

-- 目录行：序号、图标、目录名靠左，缩短后的上级路径靠右；末尾留一格，让选中底色左右对称。
local function entry(index, path, width)
  local line = { { ("%2d"):format(index), "DashboardIndex" }, { "  " } }
  if options.icons then vim.list_extend(line, { { FOLDER, "DashboardIcon" }, { " " } }) end
  local name = vim.fn.fnamemodify(path, ":t")
  if name == "" then name = path end
  local parent = vim.fn.fnamemodify(path, ":~:h")
  if parent == path or parent == "." then parent = "" end

  local used = measure(line)
  name = truncate(name, width - used)
  used = used + width_of(name)
  -- 上级路径至少要留出几个字符才有意义，否则不显示。
  local room = width - used - 2
  parent = room >= 6 and truncate(parent, room, true) or ""
  vim.list_extend(line, {
    { name, "DashboardName" },
    gap(width - used - width_of(parent)),
    { parent, "DashboardPath" },
    { " " },
  })
  line.path = path
  return line
end

-- 按键提示；放不下时从末尾开始省略。
local function footer(width)
  for count = #HINTS, 1, -1 do
    local line = { align = "center" }
    for i = 1, count do
      if i > 1 then line[#line + 1] = { "    " } end
      vim.list_extend(line, { { HINTS[i][1], "DashboardKey" }, { " " .. HINTS[i][2], "DashboardMuted" } })
    end
    if measure(line) <= width or count == 1 then return line end
  end
end

-- 标题、目录列表和按键提示。窗口太矮时省掉标题，优先保证列表完整。
local function build(width, height)
  local paths = history.list()
  local count = math.min(options.recent_limit, #paths, math.max(1, height - 5))
  local lines = {}
  local function add(line) lines[#lines + 1] = line or {} end

  if height >= count + 10 then
    add({ { "wu.nvim", "DashboardTitle" }, align = "center" })
    add({ { ("NVIM v%d.%d.%d"):format(vim.version().major, vim.version().minor, vim.version().patch), "DashboardMuted" }, align = "center" })
    add()
    add()
  end
  local total = count < #paths and ("%d / %d"):format(count, #paths) or tostring(#paths)
  add(justify({ "Recent", "DashboardSection" }, { total, "DashboardMuted" }, width))
  add({ { ("─"):rep(width), "DashboardRule" } })
  add()
  for i = 1, count do add(entry(i, paths[i], width)) end
  if #paths == 0 then add({ { "  暂无记录，打开目录或文件后会出现在这里", "DashboardMuted" } }) end
  add()
  add()
  add(footer(width))
  return lines
end

---------------------------------------------------------------------------
-- 绘制与交互
---------------------------------------------------------------------------

-- 选中一个目录行：内容区域铺一层底色、序号换成强调色，光标停在行首。
-- 用 extmark 而不是 cursorline，是为了只高亮内容区域，不铺满整个窗口宽度。
local function choose(index)
  if not state or not api.nvim_buf_is_valid(state.buf) then return end
  api.nvim_buf_clear_namespace(state.buf, selection_ns, 0, -1)
  local row = state.rows[index]
  if not row then return end
  state.selected = index
  api.nvim_buf_set_extmark(state.buf, selection_ns, row.line - 1, row.start, {
    end_col = row.stop, hl_group = "DashboardSelected", priority = 200,
  })
  api.nvim_buf_set_extmark(state.buf, selection_ns, row.line - 1, row.start, {
    end_col = row.start + 2, hl_group = "DashboardCursor", priority = 201,
  })
  local win = vim.fn.bufwinid(state.buf)
  if win ~= -1 then api.nvim_win_set_cursor(win, { row.line, row.start }) end
end

-- 把排好的行放进窗口：横向按内容宽度居中，纵向整体居中。
-- 高亮与可选中行的位置都记成字节列，因为图标和中文是多字节字符。
local function render()
  if not state or not api.nvim_buf_is_valid(state.buf) then return end
  local win = vim.fn.bufwinid(state.buf)
  if win == -1 then return end
  local win_width, win_height = api.nvim_win_get_width(win), api.nvim_win_get_height(win)
  local width = math.max(16, math.min(options.width, win_width - 4))
  local lines = build(width, win_height)

  local body, marks, rows = {}, {}, {}
  for _ = 1, math.max(0, math.floor((win_height - #lines) / 2)) do body[#body + 1] = "" end
  for _, line in ipairs(lines) do
    local content = line.align == "center" and measure(line) or width
    local text = #line > 0 and (" "):rep(math.max(0, math.floor((win_width - content) / 2))) or ""
    local start = #text
    for _, segment in ipairs(line) do
      if segment[2] then
        marks[#marks + 1] = { #body, #text, #text + #segment[1], segment[2] }
      end
      text = text .. segment[1]
    end
    body[#body + 1] = text
    if line.path then rows[#rows + 1] = { line = #body, start = start, stop = #text, path = line.path } end
  end

  vim.bo[state.buf].modifiable = true
  api.nvim_buf_set_lines(state.buf, 0, -1, false, body)
  vim.bo[state.buf].modifiable = false
  api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    api.nvim_buf_set_extmark(state.buf, ns, m[1], m[2], { end_col = m[3], hl_group = m[4] })
  end
  state.rows = rows
  choose(math.max(1, math.min(state.selected, #rows)))
end

local function move(direction)
  if not state or #state.rows == 0 then return end
  choose((state.selected - 1 + direction) % #state.rows + 1)
end

local function open_selected()
  local row = state and state.rows[state.selected]
  if row then M.open_directory(row.path) end
end

-- 删掉选中的目录记录；选中位置尽量保持不动。
local function remove_selected()
  local row = state and state.rows[state.selected]
  if not row then return end
  history.forget(row.path)
  state.selected = math.min(state.selected, #state.rows - 1)
  render()
end

function M.open_directory(path)
  if vim.fn.isdirectory(path) ~= 1 then
    vim.notify("目录已不存在：" .. path, vim.log.levels.WARN)
    return
  end
  api.nvim_cmd({ cmd = "cd", args = { path }, magic = { file = false } }, {})
  history.remember(path)
  require("wu.plugins.neo-tree").open(path)
end

local function keys(buf)
  local function bind(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, desc = desc })
  end
  bind("q", "<Cmd>confirm qall<CR>", "退出")
  bind("<CR>", open_selected, "打开所选目录")
  bind("d", remove_selected, "删除最近目录记录")
  for key, direction in pairs({ j = 1, k = -1, ["<Down>"] = 1, ["<Up>"] = -1, ["<Tab>"] = 1, ["<S-Tab>"] = -1 }) do
    bind(key, function() move(direction) end)
  end
  for i = 1, math.min(9, options.recent_limit) do
    bind(tostring(i), function()
      if state and state.rows[i] then M.open_directory(state.rows[i].path) end
    end, "打开第 " .. i .. " 个目录")
  end
  bind("<2-LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    if mouse.winid ~= api.nvim_get_current_win() or mouse.line <= 0 then return end
    for i, row in ipairs(state.rows) do
      if row.line == mouse.line then choose(i); return open_selected() end
    end
  end, "打开点击的目录")
  -- 鼠标单击、gg、G 等方式移动光标时，选中离光标最近的目录行。
  api.nvim_create_autocmd("CursorMoved", { buffer = buf, callback = function()
    if #state.rows == 0 then return end
    local line, nearest = api.nvim_win_get_cursor(0)[1], 1
    for i, row in ipairs(state.rows) do
      if math.abs(row.line - line) < math.abs(state.rows[nearest].line - line) then nearest = i end
    end
    choose(nearest)
  end })
end

function M.open()
  if state and api.nvim_buf_is_valid(state.buf) then
    local win = vim.fn.bufwinid(state.buf)
    if win ~= -1 then api.nvim_set_current_win(win); return end
  end
  local win = require("wu.plugins.files").editor()
  local previous = api.nvim_win_get_buf(win)
  local buf = api.nvim_create_buf(false, true)
  state = { buf = buf, windows = {}, rows = {}, selected = 1 }
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].undolevels = -1
  vim.b[buf].miniindentscope_disable = true
  vim.bo[buf].filetype = "dashboard"
  api.nvim_buf_set_name(buf, "dashboard://start")
  api.nvim_win_set_buf(win, buf)
  api.nvim_set_current_win(win)
  decorate(win)
  keys(buf)
  render()
  -- 启动时留下的空白 buffer 不进入最近文件和标签栏。
  if api.nvim_buf_is_valid(previous) and previous ~= buf and blank(previous)
    and #vim.fn.win_findbuf(previous) == 0 then
    api.nvim_buf_delete(previous, { force = false })
  end
end

function M.setup(opts)
  options = vim.tbl_extend("force", defaults, opts or {})
  history.setup(options.history_file)
  highlights()
  local group = api.nvim_create_augroup("LocalDashboard", { clear = true })
  api.nvim_create_user_command("Dashboard", M.open, { desc = "打开本地启动面板" })
  api.nvim_create_autocmd("StdinReadPre", { group = group, callback = function() stdin_seen = true end })
  api.nvim_create_autocmd("VimEnter", { group = group, once = true, callback = function()
    vim.schedule(function()
      if not stdin_seen and #api.nvim_list_uis() > 0 then
        local entry = vim.fn.argv(0)
        if type(entry) == "string" and entry ~= "" then
          entry = vim.fs.abspath(entry)
          history.remember(vim.fn.isdirectory(entry) == 1 and entry or history.project(entry))
        elseif vim.v.this_session ~= "" then history.remember(vim.fn.getcwd()) end
      end
      if stdin_seen or #api.nvim_list_uis() == 0 or vim.v.this_session ~= "" then return end
      -- 目录启动交给 neo-tree，在当前窗口打开文件树，不显示面板。
      if vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1 then return end
      if vim.fn.argc() ~= 0 or #api.nvim_list_wins() ~= 1 or not blank(0) then return end
      M.open()
    end)
  end })
  -- 只在面板离开或进入窗口时还原、装饰窗口选项；单纯的焦点切换不处理。
  api.nvim_create_autocmd("BufWinLeave", { group = group, callback = function(event)
    if state and event.buf == state.buf then restore() end
  end })
  api.nvim_create_autocmd("BufWinEnter", { group = group, callback = function(event)
    if state and event.buf == state.buf then decorate(api.nvim_get_current_win()); render() end
  end })
  -- 窗口增减或切换工作空间后，重新判断面板是否独占屏幕；WinClosed 时窗口尚未移除，延后处理。
  api.nvim_create_autocmd({ "WinNew", "WinClosed", "TabEnter" }, { group = group, callback = function()
    vim.schedule(sync_chrome)
  end })
  api.nvim_create_autocmd("BufWipeout", { group = group, callback = function(event)
    if state and event.buf == state.buf then restore(); state = nil end
  end })
  api.nvim_create_autocmd({ "VimResized", "WinResized" }, { group = group, callback = render })
  api.nvim_create_autocmd("DirChanged", { group = group, callback = function()
    if #api.nvim_list_uis() > 0 then history.remember(vim.fn.getcwd()) end
    render()
  end })
  api.nvim_create_autocmd("BufReadPost", { group = group, callback = function(event)
    if #api.nvim_list_uis() > 0 and vim.bo[event.buf].buftype == "" and vim.fn.filereadable(event.file) == 1 then
      history.remember(history.project(event.file))
    end
  end })
  api.nvim_create_autocmd("ColorScheme", { group = group, callback = function() highlights(); render() end })
end

return M
