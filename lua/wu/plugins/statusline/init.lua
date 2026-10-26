local components = require("wu.plugins.statusline.components")
local palette = require("wu.plugins.statusline.palette")

local M = {}
local api = vim.api

local defaults = {
  sections = {
    left = { "mode", "branch" },
    right = { "diagnostics", "filetype", "encoding", "position" },
  },
  -- 窗口宽度低于阈值时隐藏组件；未列出的组件始终显示。
  min_width = { branch = 60, diagnostics = 80, filetype = 60, encoding = 100 },
  separator = " · ",
  -- 需要 Nerd Font；关闭后使用纯文本标记。
  icons = true,
}
local options = vim.deepcopy(defaults)
local colors = nil
-- 已创建的动态高亮组，切换配色方案后失效。
local defined = {}

-- 按颜色组合生成高亮组，避免为每种组合手写定义。
local function hl(fg, bg, bold)
  bg = bg or colors.bar
  local name = ("LocalStatus_%s_%s%s"):format(fg:gsub("#", ""), bg:gsub("#", ""), bold and "_b" or "")
  if not defined[name] then
    api.nvim_set_hl(0, name, { fg = fg, bg = bg, bold = bold })
    defined[name] = true
  end
  return "%#" .. name .. "#"
end

local function paint(chunks)
  local parts = {}
  for _, chunk in ipairs(chunks) do
    parts[#parts + 1] = hl(chunk.fg or colors.text, chunk.bg, chunk.bold) .. chunk[1]
  end
  return table.concat(parts)
end

-- 依次渲染组件，跳过窗口过窄或无内容的组件，再用分隔符连接。
local function section(ctx, names)
  local parts = {}
  for _, name in ipairs(names) do
    local chunks = ctx.width >= (options.min_width[name] or 0) and components[name](ctx)
    if chunks then parts[#parts + 1] = paint(chunks) end
  end
  return table.concat(parts, hl(colors.faint) .. options.separator)
end

function M.render()
  local win = tonumber(vim.g.statusline_winid) or api.nvim_get_current_win()
  if not api.nvim_win_is_valid(win) then return "" end
  colors = colors or palette.resolve()
  local ctx = {
    buf = api.nvim_win_get_buf(win),
    width = vim.o.laststatus == 3 and vim.o.columns or api.nvim_win_get_width(win),
    icons = options.icons,
    palette = colors,
  }
  local blank = hl(colors.text)
  return section(ctx, options.sections.left)
    .. blank .. "%=" .. section(ctx, options.sections.right) .. blank .. " "
end

-- 配色变化后丢弃缓存，下次渲染时重新取色。
local function refresh()
  colors, defined = palette.resolve(), {}
  -- StatusLine 与编辑区同色，让状态栏看起来没有底色。
  api.nvim_set_hl(0, "StatusLine", { bg = colors.bar })
  api.nvim_set_hl(0, "StatusLineNC", { bg = colors.bar })
end

function M.setup(opts)
  options = vim.tbl_deep_extend("force", defaults, opts or {})
  for _, names in pairs(options.sections) do
    for _, name in ipairs(names) do
      assert(components[name], "statusline: unknown component '" .. name .. "'")
    end
  end

  refresh()
  vim.o.laststatus = 3
  vim.o.showmode = false
  vim.o.statusline = "%!v:lua.require'wu.plugins.statusline'.render()"

  local group = api.nvim_create_augroup("LocalStatusline", { clear = true })
  api.nvim_create_autocmd("ColorScheme", { group = group, callback = refresh })
  api.nvim_create_autocmd("OptionSet", { group = group, pattern = "background", callback = refresh })
  api.nvim_create_autocmd({ "ModeChanged", "DiagnosticChanged" }, {
    group = group,
    command = "redrawstatus",
  })
  api.nvim_create_autocmd("User", {
    group = group,
    pattern = "GitSignsUpdate",
    command = "redrawstatus",
  })
end

return M
