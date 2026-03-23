local actions = require('telescope.actions')
local state = require('telescope.actions.state')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')

local M = {}

local function extract_placeholder_names(cmd)
  local seen = {}
  local names = {}
  for name in cmd:gmatch("%${([^}]+)}") do
    if name ~= "currentBuffer" and not seen[name] then
      seen[name] = true
      table.insert(names, name)
    end
  end
  return names
end

local function validate(cmd, placeholders)
  local cmd_names = extract_placeholder_names(cmd)

  for _, name in ipairs(cmd_names) do
    if not placeholders[name] then
      return "placeholder '${" .. name .. "}' in cmd has no entry in placeholders"
    end
  end

  local cmd_names_set = {}
  for _, name in ipairs(cmd_names) do
    cmd_names_set[name] = true
  end

  for name, _ in pairs(placeholders) do
    if not cmd_names_set[name] then
      return "placeholders key '" .. name .. "' has no matching '${" .. name .. "}' in cmd"
    end
  end

  return nil
end

local function resolve_sequential(cmd, placeholders, resolved, names, index, callback)
  if index > #names then
    local result = cmd
    for name, value in pairs(resolved) do
      result = result:gsub("%${" .. vim.pesc(name) .. "}", value)
    end
    callback(result)
    return
  end

  local name = names[index]
  local values = placeholders[name]

  pickers.new({}, {
    prompt_title = "Select " .. name .. ":",
    finder = finders.new_table {
      results = values,
      entry_maker = function(item)
        return {
          value = item,
          display = item,
          ordinal = item,
        }
      end,
    },
    sorter = sorters.get_generic_fuzzy_sorter(),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        local selection = state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          resolved[name] = selection.value
          resolve_sequential(cmd, placeholders, resolved, names, index + 1, callback)
        end
      end)
      return true
    end,
  }):find()
end

M.resolve = function(cmd, placeholders, callback)
  local err = validate(cmd, placeholders)
  if err then
    vim.notify("project-cli-commands: " .. err, vim.log.levels.WARN)
    return
  end

  local names = extract_placeholder_names(cmd)

  if #names == 0 then
    callback(cmd)
    return
  end

  resolve_sequential(cmd, placeholders, {}, names, 1, callback)
end

return M
