-- 标签栏里的文件列表与切换、关闭操作，不依赖具体的标签栏插件。
local M = {}
local api = vim.api

-- 只列出普通文件；遗留的空白 buffer 不在窗口中显示时隐藏，含未保存内容的仍显示。
function M.visible(bufnr)
  local bo = vim.bo[bufnr]
  if not bo.buflisted or bo.buftype ~= "" then return false end
  local blank = api.nvim_buf_get_name(bufnr) == "" and not bo.modified
    and api.nvim_buf_line_count(bufnr) == 1
    and api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""
  return not blank or #vim.fn.win_findbuf(bufnr) > 0
end

-- 按 buffer 编号排序，与标签栏显示顺序一致。
function M.list()
  return vim.tbl_filter(M.visible, api.nvim_list_bufs())
end

-- 为每个 buffer 生成显示名：默认只显示文件名，重名时逐级补上父目录直到能区分。
function M.names(list)
  local parts, depth = {}, {}
  for _, bufnr in ipairs(list) do
    local path = api.nvim_buf_get_name(bufnr)
    parts[bufnr] = path == "" and { "[No Name]" } or vim.split(vim.fs.normalize(vim.fn.fnamemodify(path, ":~:.")), "/", { plain = true })
    depth[bufnr] = 1
  end
  local function label(bufnr)
    local p = parts[bufnr]
    return table.concat(p, "/", math.max(1, #p - depth[bufnr] + 1))
  end

  local changed = true
  while changed do
    changed = false
    local groups = {}
    for _, bufnr in ipairs(list) do
      local key = label(bufnr)
      groups[key] = groups[key] or {}
      table.insert(groups[key], bufnr)
    end
    for _, group in pairs(groups) do
      if #group > 1 then
        for _, bufnr in ipairs(group) do
          if depth[bufnr] < #parts[bufnr] then
            depth[bufnr] = depth[bufnr] + 1
            changed = true
          end
        end
      end
    end
  end

  local names = {}
  for _, bufnr in ipairs(list) do names[bufnr] = label(bufnr) end
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

-- 关闭文件时保留编辑窗口和焦点，同时保护未保存的修改。
function M.close(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end
  if vim.bo[bufnr].modified then
    vim.notify("文件有未保存的修改，请保存后再关闭。", vim.log.levels.WARN)
    return
  end

  local current = api.nvim_get_current_win()
  local buffers = vim.fn.getbufinfo({ buflisted = 1 })
  table.sort(buffers, function(a, b)
    return a.lastused > b.lastused
  end)
  local replacement
  for _, buf in ipairs(buffers) do
    if buf.bufnr ~= bufnr
      and vim.bo[buf.bufnr].buftype == ""
      and (buf.name ~= "" or vim.bo[buf.bufnr].modified)
      and vim.fn.isdirectory(buf.name) == 0
    then
      replacement = buf.bufnr
      break
    end
  end

  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    -- 先替换窗口里的内容，防止 bdelete 连同窗口一起关闭；
    -- 最后一个文件关闭后保留编辑窗口，显示空白缓冲区。
    replacement = replacement or api.nvim_create_buf(true, false)
    api.nvim_win_set_buf(win, replacement)
  end

  local ok, err = pcall(api.nvim_buf_delete, bufnr, { force = false })
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
  end
  if api.nvim_win_is_valid(current) then
    api.nvim_set_current_win(current)
  end
end

return M
