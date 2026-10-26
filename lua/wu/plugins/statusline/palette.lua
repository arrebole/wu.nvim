-- 状态栏调色板：从当前配色方案取色，切换主题后重新计算。
local M = {}

local function get(name, attr)
  return vim.api.nvim_get_hl(0, { name = name, link = false })[attr]
end

local function hex(rgb)
  return string.format("#%06x", rgb)
end

-- 按 alpha 比例混合前景色与背景色，用于生成弱化色。
local function blend(fg, bg, alpha)
  local rgb = 0
  for _, shift in ipairs({ 65536, 256, 1 }) do
    local a = math.floor(fg / shift) % 256
    local b = math.floor(bg / shift) % 256
    rgb = rgb + math.floor(a * alpha + b * (1 - alpha) + 0.5) * shift
  end
  return rgb
end

function M.resolve()
  local dark = vim.o.background == "dark"
  local normal_bg = get("Normal", "bg")
  local bg = normal_bg or (dark and 0x1e1e2e or 0xeff1f5)
  local fg = get("Normal", "fg") or (dark and 0xcdd6f4 or 0x4c4f69)
  local function accent(name, fallback)
    return hex(get(name, "fg") or fallback)
  end

  return {
    -- 底栏与编辑区同色；透明背景时跟随终端。
    bar = normal_bg and hex(bg) or "NONE",
    text = hex(fg),
    -- 模式色块上的文字。
    base = hex(bg),
    muted = hex(blend(fg, bg, 0.5)),
    -- 分隔符比弱化文字再淡一些。
    faint = hex(blend(fg, bg, 0.25)),
    modes = {
      normal = accent("DiagnosticInfo", 0x89b4fa),
      insert = accent("DiagnosticOk", 0xa6e3a1),
      visual = accent("Statement", 0xcba6f7),
      replace = accent("DiagnosticError", 0xf38ba8),
      command = accent("DiagnosticWarn", 0xf9e2af),
      terminal = accent("DiagnosticHint", 0x94e2d5),
    },
    diagnostics = {
      error = accent("DiagnosticError", 0xf38ba8),
      warn = accent("DiagnosticWarn", 0xf9e2af),
      info = accent("DiagnosticInfo", 0x89b4fa),
      hint = accent("DiagnosticHint", 0x94e2d5),
    },
  }
end

return M
