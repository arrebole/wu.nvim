-- 路径显示名：默认只取最后一级，重名时逐级补上父目录直到能区分。
local M = {}

---@param list string[] 已格式化的路径，例如 "~/repos/wu.nvim" 或 "lua/wu/init.lua"
---@return string[] labels 与 list 一一对应的显示名
function M.unique(list)
  local parts, depth = {}, {}
  for i, path in ipairs(list) do
    parts[i] = vim.split(path, "/", { plain = true, trimempty = true })
    if #parts[i] == 0 then parts[i] = { path } end
    depth[i] = 1
  end

  local function label(i)
    return table.concat(parts[i], "/", #parts[i] - depth[i] + 1)
  end

  local changed = true
  while changed do
    changed = false
    local groups = {}
    for i in ipairs(list) do
      local key = label(i)
      groups[key] = groups[key] or {}
      table.insert(groups[key], i)
    end
    for _, group in pairs(groups) do
      if #group > 1 then
        for _, i in ipairs(group) do
          if depth[i] < #parts[i] then
            depth[i] = depth[i] + 1
            changed = true
          end
        end
      end
    end
  end

  local labels = {}
  for i in ipairs(list) do labels[i] = label(i) end
  return labels
end

return M
