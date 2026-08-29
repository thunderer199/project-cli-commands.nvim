local M = {}

-- `--dump-format json` was gated behind `--unstable` on older just releases,
-- and `--summary` is the last resort when neither dump works.
local jsonDumpArgs = { "just", "--dump", "--dump-format", "json" }
local unstableDumpArgs = { "just", "--unstable", "--dump", "--dump-format", "json" }
local summaryArgs = { "just", "--summary" }

local notifyError = function(message)
  vim.notify(message, vim.log.levels.ERROR)
end

-- just performs its own upward search for a justfile, so running it from the
-- current working directory keeps the listed recipes and the recipe that
-- actually runs in agreement.
local run = function(args)
  local output = vim.fn.system(args)
  if vim.v.shell_error ~= 0 then
    return nil, output or ""
  end

  return output, nil
end

-- The wording is capitalised on older just releases and lowercase on newer ones.
local isMissingJustfile = function(message)
  return message:lower():find("no justfile found", 1, true) ~= nil
end

local decodeDump = function(output)
  local ok, decoded = pcall(vim.fn.json_decode, output)
  if not ok or type(decoded) ~= "table" or type(decoded.recipes) ~= "table" then
    return nil
  end

  return decoded
end

local isPrivate = function(recipe)
  if recipe.private == true then
    return true
  end

  if type(recipe.name) == "string" and recipe.name:sub(1, 1) == "_" then
    return true
  end

  if type(recipe.attributes) == "table" then
    for _, attribute in ipairs(recipe.attributes) do
      -- Attributes are plain strings on older releases and tables on newer ones.
      if attribute == "private" or (type(attribute) == "table" and attribute.private ~= nil) then
        return true
      end
    end
  end

  return false
end

-- A recipe can't run bare when a parameter has no default. `star` parameters
-- are variadic and accept zero arguments, so they don't count.
local requiresArguments = function(recipe)
  if type(recipe.parameters) ~= "table" then
    return false
  end

  for _, parameter in ipairs(recipe.parameters) do
    local default = parameter.default
    local hasDefault = default ~= nil and default ~= vim.NIL
    if not hasDefault and parameter.kind ~= "star" then
      return true
    end
  end

  return false
end

local docOf = function(recipe)
  local doc = recipe.doc
  if type(doc) ~= "string" or doc == "" then
    return nil
  end

  return doc
end

-- Recipe bodies come back as a list of lines, each line a list of literal
-- string fragments and interpolations.
local firstBodyLine = function(recipe)
  if type(recipe.body) ~= "table" or type(recipe.body[1]) ~= "table" then
    return nil
  end

  local parts = {}
  for _, fragment in ipairs(recipe.body[1]) do
    if type(fragment) == "string" then
      table.insert(parts, fragment)
    else
      table.insert(parts, "{{...}}")
    end
  end

  local line = vim.trim(table.concat(parts))
  if line == "" then
    return nil
  end

  return line
end

local newCommand = function(recipeName, description, requires_args)
  local cmd = "just " .. recipeName

  return {
    command_key = cmd,
    -- The name column is the literal invocation, which keeps `just build`
    -- distinct from a config command named `build` without extra decoration.
    name = cmd,
    description = description or cmd,
    cmd = cmd,
    -- Marks the entry as coming from the justfile so env injection is skipped;
    -- a justfile handles its own dotenv loading.
    source = "just",
    requires_args = requires_args or false,
  }
end

local function collectRecipes(node, commands)
  if type(node) ~= "table" then
    return
  end

  if type(node.recipes) == "table" then
    for name, recipe in pairs(node.recipes) do
      if type(recipe) == "table" and not isPrivate(recipe) then
        -- `namepath` carries the module prefix for imported submodules.
        local recipeName = (type(recipe.namepath) == "string" and recipe.namepath) or name
        table.insert(
          commands,
          newCommand(recipeName, docOf(recipe) or firstBodyLine(recipe), requiresArguments(recipe))
        )
      end
    end
  end

  if type(node.modules) == "table" then
    for _, module in pairs(node.modules) do
      collectRecipes(module, commands)
    end
  end
end

-- `--summary` prints public recipe names only, with no docs or parameters.
local commandsFromSummary = function(output)
  local commands = {}
  for name in output:gmatch("%S+") do
    table.insert(commands, newCommand(name))
  end

  return commands
end

local sortByName = function(commands)
  table.sort(commands, function(a, b)
    return a.name < b.name
  end)

  return commands
end

M.getCommands = function(config)
  if config ~= nil and config.enabled == false then
    return {}
  end

  if vim.fn.executable("just") == 0 then
    return {}
  end

  local output, stderr = run(jsonDumpArgs)

  -- A project without a justfile is the common case, not something to report,
  -- and bailing here avoids running the fallbacks for nothing.
  if output == nil and isMissingJustfile(stderr) then
    return {}
  end

  local dump = output and decodeDump(output)

  if dump == nil then
    local unstableOutput, unstableStderr = run(unstableDumpArgs)
    dump = unstableOutput and decodeDump(unstableOutput)
    stderr = stderr or unstableStderr
  end

  if dump ~= nil then
    local commands = {}
    collectRecipes(dump, commands)

    return sortByName(commands)
  end

  local summaryOutput, summaryStderr = run(summaryArgs)
  if summaryOutput ~= nil then
    return sortByName(commandsFromSummary(summaryOutput))
  end

  local message = vim.trim(summaryStderr or stderr or "")
  if message ~= "" and not isMissingJustfile(message) then
    notifyError("project-cli-commands: " .. message)
  end

  return {}
end

return M
