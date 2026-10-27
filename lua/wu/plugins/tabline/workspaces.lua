-- 工作空间：每个 tabpage 是一个工作空间，可以用 :tcd 设置各自的工作目录。
-- 记录每个工作空间里打开过的 buffer，标签栏只列出当前工作空间的文件。

local M = {}
local api = vim.api

-- tabpage -> { [bufnr] = true }
local members = {}

function M.list()
  return api.nvim_list_tabpages()
end

function M.current()
  return api.nvim_get_current_tabpage()
end

function M.track(tab, bufnr)
  members[tab] = members[tab] or {}
  members[tab][bufnr] = true
end

function M.leave(tab, bufnr)
  if members[tab] then members[tab][bufnr] = nil end
end

function M.forget(bufnr)
  for _, set in pairs(members) do set[bufnr] = nil end
end

-- 除 tab 之外是否还有工作空间打开着这个文件。
function M.shared(tab, bufnr)
  for other, set in pairs(members) do
    if other ~= tab and set[bufnr] and api.nvim_tabpage_is_valid(other) then return true end
  end
  return false
end

function M.prune()
  for tab in pairs(members) do
    if not api.nvim_tabpage_is_valid(tab) then members[tab] = nil end
  end
end

-- 没有被任何工作空间认领的 buffer（例如配置重新加载前就已打开的文件）归入当前工作空间，
-- 保证每个文件都能在标签栏里找到。
function M.contains(tab, bufnr)
  if members[tab] and members[tab][bufnr] then return true end
  return tab == M.current() and not M.shared(tab, bufnr)
end

function M.setup()
  members = {}
  for _, tab in ipairs(M.list()) do
    for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
      M.track(tab, api.nvim_win_get_buf(win))
    end
  end

  local group = api.nvim_create_augroup("LocalWorkspaces", { clear = true })
  -- BufAdd 覆盖只加载未显示的文件，BufEnter/BufWinEnter 覆盖在其他工作空间里再次打开的文件。
  api.nvim_create_autocmd({ "BufAdd", "BufEnter", "BufWinEnter" }, {
    group = group,
    callback = function(event) M.track(M.current(), event.buf) end,
  })
  api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function(event) M.forget(event.buf) end,
  })
  api.nvim_create_autocmd("TabClosed", { group = group, callback = M.prune })
end

return M
