-- 标签栏里的文件列表与切换、关闭操作。
local paths = require("wu.plugins.tabline.paths")
local workspaces = require("wu.plugins.tabline.workspaces")

local M = {}
local api = vim.api

-- 只列出普通文件。没有名字也没有内容的空白 buffer（启动或打开目录时 nvim 自动留下的）不显示，
-- 一旦输入内容就会出现在标签栏里。
function M.visible(bufnr)
  local bo = vim.bo[bufnr]
  if not bo.buflisted or bo.buftype ~= "" then return false end
  local blank = api.nvim_buf_get_name(bufnr) == "" and not bo.modified
    and api.nvim_buf_line_count(bufnr) == 1
    and api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""
  return not blank
end

-- 当前工作空间里的文件，按 buffer 编号排序，与标签栏显示顺序一致。
function M.list()
  local tab = workspaces.current()
  return vim.tbl_filter(function(bufnr)
    return M.visible(bufnr) and workspaces.contains(tab, bufnr)
  end, api.nvim_list_bufs())
end

-- 显示名相对工作目录，重名时补上父目录。
function M.names(list)
  local labels = paths.unique(vim.tbl_map(function(bufnr)
    local path = api.nvim_buf_get_name(bufnr)
    return path == "" and "[No Name]" or vim.fs.normalize(vim.fn.fnamemodify(path, ":~:."))
  end, list))
  local names = {}
  for i, bufnr in ipairs(list) do names[bufnr] = labels[i] end
  return names
end

-- 切换文件时回到普通编辑窗口，避免替换浮动终端；从浮动窗口发起时优先回到上一个窗口。
local function editor()
  local win = api.nvim_get_current_win()
  if api.nvim_win_get_config(win).relative ~= "" then
    win = vim.fn.win_getid(vim.fn.winnr("#"))
  end
  return require("wu.plugins.files").editor(win)
end

function M.open(bufnr)
  local win = editor()
  api.nvim_set_current_win(win)
  api.nvim_win_set_buf(win, bufnr)
end

-- 按标签栏顺序循环切换，首尾相接。
function M.cycle(direction)
  local list = M.list()
  if #list == 0 then return end
  local index = vim.fn.index(list, api.nvim_win_get_buf(editor()))
  local target = index < 0 and list[direction > 0 and 1 or #list]
    or list[(index + direction) % #list + 1]
  M.open(target)
end

-- 当前工作空间里最近使用的另一个文件，用来顶替被关闭的文件。
local function replacement(tab, bufnr)
  local buffers = vim.fn.getbufinfo({ buflisted = 1 })
  table.sort(buffers, function(a, b) return a.lastused > b.lastused end)
  for _, buf in ipairs(buffers) do
    if buf.bufnr ~= bufnr
      and workspaces.contains(tab, buf.bufnr)
      and vim.bo[buf.bufnr].buftype == ""
      and (buf.name ~= "" or vim.bo[buf.bufnr].modified)
      and vim.fn.isdirectory(buf.name) == 0
    then
      return buf.bufnr
    end
  end
end

-- 先替换窗口里的内容，防止 bdelete 连同窗口一起关闭；
-- 最后一个文件关闭后保留编辑窗口，显示空白缓冲区。
local function vacate(tab, bufnr, wins)
  local substitute = replacement(tab, bufnr)
  for _, win in ipairs(wins) do
    substitute = substitute or api.nvim_create_buf(true, false)
    api.nvim_win_set_buf(win, substitute)
  end
end

-- 关闭文件时保留编辑窗口和焦点，同时保护未保存的修改。
-- 文件仍属于其他工作空间时只从当前工作空间移出，不删除 buffer。
function M.close(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then return end
  local current, tab = api.nvim_get_current_win(), workspaces.current()

  if workspaces.shared(tab, bufnr) then
    local wins = vim.tbl_filter(function(win)
      return api.nvim_win_get_tabpage(win) == tab
    end, vim.fn.win_findbuf(bufnr))
    vacate(tab, bufnr, wins)
    workspaces.leave(tab, bufnr)
  else
    if vim.bo[bufnr].modified then
      vim.notify("文件有未保存的修改，请保存后再关闭。", vim.log.levels.WARN)
      return
    end
    vacate(tab, bufnr, vim.fn.win_findbuf(bufnr))
    local ok, err = pcall(api.nvim_buf_delete, bufnr, { force = false })
    if not ok then vim.notify(err, vim.log.levels.ERROR) end
  end

  if api.nvim_win_is_valid(current) then api.nvim_set_current_win(current) end
  vim.cmd.redrawtabline()
end

return M
