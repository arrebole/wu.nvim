-- 侧边栏文件树：在 neo-tree 之上统一处理光标的去留。
-- 进入文件树前记下所在的编辑窗口，离开或关闭时光标回到那里。
local M = {}
local api = vim.api

-- tabpage -> 进入文件树前所在的编辑窗口
local origins = {}

local function state()
  return require("neo-tree.sources.manager").get_state("filesystem")
end

local function visible()
  return require("neo-tree.ui.renderer").window_exists(state())
end

local function focused()
  return vim.bo.filetype == "neo-tree"
end

local function editable(win)
  return win and api.nvim_win_is_valid(win)
    and api.nvim_win_get_tabpage(win) == api.nvim_get_current_tabpage()
    and api.nvim_win_get_config(win).relative == ""
    and vim.bo[api.nvim_win_get_buf(win)].filetype ~= "neo-tree"
end

-- 光标还在编辑区时记下当前窗口。
local function remember()
  if not focused() then origins[api.nvim_get_current_tabpage()] = api.nvim_get_current_win() end
end

-- 回到进入文件树前的窗口；它已关闭时退回 neo-tree 记录的最近窗口。
local function back()
  local win = origins[api.nvim_get_current_tabpage()]
  if not editable(win) then win = require("neo-tree").get_prior_window() end
  if editable(win) then api.nvim_set_current_win(win) end
end

-- 打开文件树并聚焦。根目录默认为当前工作空间的目录，
-- 当前文件在根目录之内时展开并定位到它，不在时不切换目录。
function M.open(dir)
  remember()
  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = dir or vim.fn.getcwd(),
    reveal = dir == nil,
  })
end

-- 关闭文件树；光标在树里时回到进入前的编辑窗口。
function M.close()
  if not visible() then return end
  local inside = focused()
  require("neo-tree.ui.renderer").close(state(), false)
  if inside then back() end
end

-- 未打开 → 打开；已打开 → 关闭。
function M.toggle()
  if visible() then M.close() else M.open() end
end

-- 在文件树和编辑窗口之间切换光标，文件树保持打开；未打开时先打开。
function M.focus()
  if not visible() then
    M.open()
  elseif focused() then
    back()
  else
    remember()
    api.nvim_set_current_win(state().winid)
  end
end

return M
