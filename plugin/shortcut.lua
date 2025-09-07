if vim.fn.has("nvim-0.7.0") == 0 then
  vim.api.nvim_err_writeln("shortcut.nvim requires at least nvim-0.7.0")
  return
end

if vim.g.loaded_shortcut == 1 then
  return
end
vim.g.loaded_shortcut = 1

local shortcut = require('shortcut')
local api = require('shortcut.api')

vim.api.nvim_create_user_command("ShortcutSearch", function(opts)
  local query = opts.args
  if query == "" then
    query = vim.fn.input("Search stories: ")
  end
  
  local stories, err = api.search_stories(query)
  if err then
    vim.notify("Error: " .. err, vim.log.levels.ERROR)
    return
  end
  
  if not stories or not stories.data then
    vim.notify("No stories found", vim.log.levels.INFO)
    return
  end
  
  local lines = {}
  for _, story in ipairs(stories.data) do
    table.insert(lines, string.format("[%s] %s - %s", story.id, story.name, story.workflow_state_id))
  end
  
  vim.cmd("new")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.bo.filetype = "shortcut"
end, { nargs = "?", desc = "Search Shortcut stories" })

vim.api.nvim_create_user_command("ShortcutWorkflows", function()
  local workflows, err = api.get_workflows()
  if err then
    vim.notify("Error: " .. err, vim.log.levels.ERROR)
    return
  end
  
  if not workflows then
    vim.notify("No workflows found", vim.log.levels.INFO)
    return
  end
  
  local lines = {}
  for _, workflow in ipairs(workflows) do
    table.insert(lines, string.format("Workflow: %s", workflow.name))
    for _, state in ipairs(workflow.states) do
      table.insert(lines, string.format("  [%d] %s (%s)", state.id, state.name, state.type))
    end
  end
  
  vim.cmd("new")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.bo.filetype = "shortcut"
end, { desc = "List Shortcut workflows" })

vim.api.nvim_create_user_command("ShortcutProjects", function()
  local projects, err = api.get_projects()
  if err then
    vim.notify("Error: " .. err, vim.log.levels.ERROR)
    return
  end
  
  if not projects then
    vim.notify("No projects found", vim.log.levels.INFO)
    return
  end
  
  local lines = {}
  for _, project in ipairs(projects) do
    table.insert(lines, string.format("[%d] %s - %s", project.id, project.name, project.description or ""))
  end
  
  vim.cmd("new")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.bo.filetype = "shortcut"
end, { desc = "List Shortcut projects" })

vim.api.nvim_create_user_command("ShortcutStory", function(opts)
  local story_id = opts.args
  if story_id == "" then
    story_id = vim.fn.input("Story ID: ")
  end
  
  local story, err = api.get_story(story_id)
  if err then
    vim.notify("Error: " .. err, vim.log.levels.ERROR)
    return
  end
  
  if not story then
    vim.notify("Story not found", vim.log.levels.INFO)
    return
  end
  
  local lines = {
    "Story: " .. story.name,
    "ID: " .. story.id,
    "Type: " .. story.story_type,
    "State: " .. (story.workflow_state_id or "Unknown"),
    "Estimate: " .. (story.estimate or "Not estimated"),
    "",
    "Description:",
  }
  
  if story.description then
    for line in story.description:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end
  else
    table.insert(lines, "  No description")
  end
  
  vim.cmd("new")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.bo.filetype = "shortcut"
end, { nargs = "?", desc = "View a Shortcut story" })