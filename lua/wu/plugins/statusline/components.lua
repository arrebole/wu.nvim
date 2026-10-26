-- 状态栏组件。
-- 每个组件接收渲染上下文 ctx，返回文本块列表；返回 nil 表示不显示。
-- 文本块格式：{ 文本, fg = 前景色, bg = 背景色, bold = 是否加粗 }，颜色缺省跟随底栏。
local M = {}

-- 先按两字符匹配（如 "no"），再退回首字符。
local MODES = {
  n = { "normal", "normal" },
  no = { "pending", "normal" },
  i = { "insert", "insert" },
  R = { "replace", "replace" },
  v = { "visual", "visual" },
  V = { "v-line", "visual" },
  ["\22"] = { "v-block", "visual" },
  s = { "select", "visual" },
  S = { "s-line", "visual" },
  ["\19"] = { "s-block", "visual" },
  c = { "command", "command" },
  r = { "prompt", "command" },
  ["!"] = { "shell", "command" },
  t = { "terminal", "terminal" },
}

local DIAGNOSTICS = {
  { "error", vim.diagnostic.severity.ERROR, "\u{f057}", "e" },
  { "warn", vim.diagnostic.severity.WARN, "\u{f071}", "w" },
  { "info", vim.diagnostic.severity.INFO, "\u{f05a}", "i" },
  { "hint", vim.diagnostic.severity.HINT, "\u{f0eb}", "h" },
}

local BRANCH_ICON = "\u{e0a0} "

-- 分支名等外部文本不能直接放进 statusline 格式串。
local function escape(text)
  return (tostring(text):gsub("%c", " "):gsub("%%", "%%%%"))
end

-- 模式色块是状态栏里唯一的强调色。
function M.mode(ctx)
  local mode = vim.api.nvim_get_mode().mode
  local entry = MODES[mode:sub(1, 2)] or MODES[mode:sub(1, 1)] or MODES.n
  local color = ctx.palette.modes[entry[2]]
  return { { " " .. entry[1] .. " ", fg = ctx.palette.base, bg = color, bold = true } }
end

-- 分支信息来自 gitsigns：优先当前 buffer，其次工作目录所在仓库。
function M.branch(ctx)
  local head = vim.b[ctx.buf].gitsigns_head or vim.g.gitsigns_head
  if not head or head == "" then return nil end
  return { { ctx.icons and BRANCH_ICON or "", fg = ctx.palette.muted }, { escape(head) } }
end

function M.diagnostics(ctx)
  local counts = vim.diagnostic.count(ctx.buf)
  local chunks = {}
  for _, item in ipairs(DIAGNOSTICS) do
    local name, count = item[1], counts[item[2]]
    if count then
      local label = ctx.icons and item[3] .. " " or item[4]
      local gap = #chunks > 0 and "  " or ""
      chunks[#chunks + 1] = { gap .. label .. count, fg = ctx.palette.diagnostics[name] }
    end
  end
  if #chunks > 0 then return chunks end
end

function M.filetype(ctx)
  local filetype = vim.bo[ctx.buf].filetype
  if filetype == "" then return nil end
  return { { escape(filetype), fg = ctx.palette.muted } }
end

-- 编码统一小写；换行符只在不是 unix 时标出，例如 "utf-8 crlf"。
function M.encoding(ctx)
  local bo = vim.bo[ctx.buf]
  if bo.buftype ~= "" then return nil end
  local text = bo.fileencoding ~= "" and bo.fileencoding or vim.o.encoding
  if bo.bomb then text = text .. " bom" end
  if bo.fileformat ~= "unix" then text = text .. " " .. bo.fileformat end
  return { { escape(text:lower()), fg = ctx.palette.muted } }
end

-- %v 为显示列，中文等宽字符按实际占位计算。
function M.position()
  return { { "%l:%v" } }
end

return M
