local actions = require('telescope.actions')
local state = require('telescope.actions.state')

local Terminal = require("toggleterm.terminal").Terminal

local next_id = require("project_cli_commands.term_utils").next_id
local getEnvTable = require("project_cli_commands.file").getEnvTable


local M = {}

M.execute_script_with_params = function(prompt_bufnr, with_params, direction, size)
  direction = direction or "horizontal"

  local selection = state.get_selected_entry()
  actions.close(prompt_bufnr)

  local params = ''
  if with_params then
    params = ' ' .. vim.fn.input(selection.code .. ' ')
  end

  local cmdLine = selection.value .. params

  local function run_terminal(finalCmd)
    -- Get the current buffer's full path
    local current_buffer_path = vim.fn.expand('%:p')

    -- Replace `${currentBuffer}` with the current buffer's path
    finalCmd = finalCmd:gsub("%${currentBuffer}", current_buffer_path)

    local termParams = {
      id            = next_id(),
      cmd           = finalCmd,
      hidden        = true,
      close_on_exit = false,
    }

    local env
    if selection.env then
      -- Resolve per-command env file relative to the config that defined
      -- this command (global or project).
      env = getEnvTable(selection.env, selection.env_base_dir)
    end

    if not env then
      env = require('project_cli_commands').envTable
    end

    if env then
      termParams.env = env
    end

    local cmdTerm = Terminal:new(termParams)

    if selection.after then
      cmdTerm.on_exit = function()
        vim.cmd(selection.after)
      end
    end

    cmdTerm:toggle(size, direction)
  end

  if not with_params and selection.placeholders then
    require('project_cli_commands.placeholders').resolve(cmdLine, selection.placeholders, run_terminal)
  else
    run_terminal(cmdLine)
  end
end

M.execute_script = function(prompt_bufnr, direction, size)
  M.execute_script_with_params(prompt_bufnr, false, direction, size)
end

M.execute_script_vertical = function(prompt_bufnr)
  M.execute_script_with_params(prompt_bufnr, false, "vertical", math.floor(vim.o.columns / 2.5))
end

M.execute_script_float = function(prompt_bufnr)
  M.execute_script_with_params(prompt_bufnr, false, "float")
end

M.execute_script_with_input = function(prompt_bufnr)
  M.execute_script_with_params(prompt_bufnr, true)
end

M.copy_command_clipboard = function(prompt_bufnr)
  local selection = state.get_selected_entry()
  actions.close(prompt_bufnr)

  vim.fn.setreg('+', selection.code)
end

return M
