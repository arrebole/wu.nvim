-- 顶部标签栏：由 tabby.nvim 渲染，左侧列出打开的文件，多个 tabpage 时右侧列出 tab 编号。
-- 颜色与状态栏共用调色板，背景跟随编辑区。
local buffers = require("wu.plugins.tabline.buffers")
local palette = require("wu.plugins.statusline.palette")

local M = {}
local api = vim.api

local defaults = {
  -- 需要 Nerd Font；关闭后使用纯文本标记。
  icons = true,
}
local options = vim.deepcopy(defaults)
local colors

local MARKS = {
  icons = { current = "▎", close = "\u{f00d}", modified = "●", error = "\u{f057} ", warn = "\u{f071} " },
  text = { current = "▎", close = "x", modified = "+", error = "e", warn = "w" },
}

-- 点击区域只能调用全局函数，minwid 传 buffer 编号。
_G.WuTabline = {
  -- 左键切换，中键或右键关闭。
  open = function(bufnr, _, button)
    if button == "l" then buffers.open(bufnr) else buffers.close(bufnr) end
  end,
  close = function(bufnr) buffers.close(bufnr) end,
}

local function clickable(handler, bufnr, node)
  return { ("%%%d@v:lua.WuTabline.%s@"):format(bufnr, handler), node, "%X" }
end

local function color(fg, bold)
  return { fg = fg, bg = colors.bar, style = bold and "bold" or nil }
end

-- 只提示最严重的一级诊断。
local function diagnostic(bufnr, marks)
  local counts = vim.diagnostic.count(bufnr)
  for _, name in ipairs({ "error", "warn" }) do
    local count = counts[vim.diagnostic.severity[name:upper()]]
    if count then return { " " .. marks[name] .. count, hl = color(colors.diagnostics[name]) } end
  end
  return ""
end

---@param buf TabbyBuf
local function buffer(buf, name, marks)
  local current = buf.is_current()
  name = name:gsub("%%", "%%%%")
  local label = {
    { current and marks.current or " ", hl = color(colors.modes.normal) },
    options.icons and " " .. buf.file_icon() .. " " or " ",
    name,
    diagnostic(buf.id, marks),
    " ",
    hl = color(current and colors.text or colors.muted, current),
  }
  local status = buf.is_changed() and { marks.modified, hl = color(colors.modes.command) }
    or { marks.close, hl = color(colors.faint) }
  return { clickable("open", buf.id, label), clickable("close", buf.id, status), " " }
end

---@param tab TabbyTab
local function tab(tab)
  local current = tab.is_current()
  return { " " .. tab.number() .. " ", hl = color(current and colors.modes.normal or colors.muted, current) }
end

---@param line TabbyLine
function M.render(line)
  colors = colors or palette.resolve()
  local marks = MARKS[options.icons and "icons" or "text"]
  local visible = line.bufs().filter(function(buf) return buffers.visible(buf.id) end).bufs
  local names = buffers.names(vim.tbl_map(function(buf) return buf.id end, visible))
  return {
    vim.tbl_map(function(buf) return buffer(buf, names[buf.id], marks) end, visible),
    line.spacer(),
    #line.api.get_tabs() > 1 and line.tabs().foreach(tab) or "",
    hl = color(colors.text),
  }
end

-- 配色变化后丢弃缓存，下次渲染时重新取色。
local function refresh()
  colors = palette.resolve()
  api.nvim_set_hl(0, "TabLineFill", { bg = colors.bar })
end

function M.setup(opts)
  options = vim.tbl_deep_extend("force", defaults, opts or {})
  refresh()
  vim.o.showtabline = 2

  require("tabby").setup({ line = M.render })

  local group = api.nvim_create_augroup("LocalTabline", { clear = true })
  api.nvim_create_autocmd("ColorScheme", { group = group, callback = refresh })
  api.nvim_create_autocmd("OptionSet", { group = group, pattern = "background", callback = refresh })
  api.nvim_create_autocmd({ "DiagnosticChanged", "BufModifiedSet" }, {
    group = group,
    command = "redrawtabline",
  })
end

return M
