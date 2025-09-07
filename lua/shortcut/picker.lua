local M = {}

-- Check if telescope is available
local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
	return M  -- Return empty module if telescope is not available
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local api = require("shortcut.api")
local config = require("shortcut.config")
local utils = require("shortcut.utils")

M.workflows = nil -- Cache workflows

local function get_workflows()
	if not M.workflows then
		M.workflows = api.get_workflows()
	end
	return M.workflows
end

local function make_entry(story)
	local workflows = get_workflows()
	local state_name = utils.format_workflow_state(workflows, story.workflow_state_id)
	
	-- Handle estimate field safely - it might be userdata/null from JSON
	local estimate = ""
	if story.estimate and type(story.estimate) == "number" then
		estimate = "[" .. tostring(story.estimate) .. "]"
	elseif story.estimate and type(story.estimate) == "string" and story.estimate ~= "" then
		estimate = "[" .. story.estimate .. "]"
	end
	
	local branch_name = utils.create_branch_name(story)

	return {
		value = story,
		branch_name = branch_name,
		display = string.format("sc-%s %s %s", 
			tostring(story.id or ""), 
			estimate, 
			utils.truncate(story.name or "Untitled", 60)
		),
		ordinal = (story.name or "") .. " " .. (story.description or "") .. " " .. tostring(story.id or ""),
		description = state_name,
	}
end

local function create_previewer()
	return previewers.new_buffer_previewer({
		title = "Story Details",
		define_preview = function(self, entry, status)
			local story = entry.value
			local lines = {}

			-- Header
			table.insert(lines, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			table.insert(lines, "  " .. story.name)
			table.insert(lines, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			table.insert(lines, "")

			-- Details
			local details = utils.format_story_details(story)
			for _, line in ipairs(details) do
				table.insert(lines, line)
			end

			-- Description
			if story.description and story.description ~= "" then
				table.insert(lines, "")
				table.insert(lines, "Description:")
				table.insert(lines, "────────────")
				for line in story.description:gmatch("[^\r\n]+") do
					table.insert(lines, line)
				end
			end

			-- Tasks
			if story.tasks and #story.tasks > 0 then
				table.insert(lines, "")
				table.insert(lines, "Tasks:")
				table.insert(lines, "──────")
				for _, task in ipairs(story.tasks) do
					local checkbox = task.complete and "✓" or "○"
					table.insert(lines, string.format("  %s %s", checkbox, task.description))
				end
			end

			-- Comments
			if story.comments and #story.comments > 0 then
				table.insert(lines, "")
				table.insert(lines, "Recent Comments:")
				table.insert(lines, "────────────────")
				for i, comment in ipairs(story.comments) do
					if i > 3 then
						break
					end -- Show only recent 3
					table.insert(lines, "")
					table.insert(lines, "  • " .. utils.truncate(comment.text, 70))
				end
			end

			-- Branch name
			table.insert(lines, "")
			table.insert(lines, "Branch: " .. (entry.branch_name or "N/A"))

			-- URL
			if story.app_url then
				table.insert(lines, "URL: " .. story.app_url)
			end

			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
			vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
		end,
	})
end

local function attach_mappings(prompt_bufnr, map, opts)
	opts = opts or {}

	-- Copy branch name
	map("i", "<C-b>", function()
		local selection = action_state.get_selected_entry()
		if selection and selection.branch_name then
			utils.copy_to_clipboard(selection.branch_name)
		end
	end)

	map("n", "<C-b>", function()
		local selection = action_state.get_selected_entry()
		if selection and selection.branch_name then
			utils.copy_to_clipboard(selection.branch_name)
		end
	end)

	-- Open in browser
	map("i", "<C-o>", function()
		local selection = action_state.get_selected_entry()
		if selection and selection.value.app_url then
			utils.open_url(selection.value.app_url)
		end
	end)

	map("n", "<C-o>", function()
		local selection = action_state.get_selected_entry()
		if selection and selection.value.app_url then
			utils.open_url(selection.value.app_url)
		end
	end)

	-- Copy story ID
	map("i", "<C-y>", function()
		local selection = action_state.get_selected_entry()
		if selection then
			utils.copy_to_clipboard("sc-" .. selection.value.id)
		end
	end)

	map("n", "<C-y>", function()
		local selection = action_state.get_selected_entry()
		if selection then
			utils.copy_to_clipboard("sc-" .. selection.value.id)
		end
	end)

	-- Create comment
	map("i", "<C-c>", function()
		local selection = action_state.get_selected_entry()
		if selection then
			actions.close(prompt_bufnr)
			M.create_comment(selection.value)
		end
	end)

	map("n", "<C-c>", function()
		local selection = action_state.get_selected_entry()
		if selection then
			actions.close(prompt_bufnr)
			M.create_comment(selection.value)
		end
	end)

	-- Default action - copy branch name
	actions.select_default:replace(function()
		local selection = action_state.get_selected_entry()
		actions.close(prompt_bufnr)
		if selection and selection.branch_name then
			utils.copy_to_clipboard(selection.branch_name)
		end
	end)

	return true
end

function M.show_stories(stories, opts)
	opts = opts or {}
	opts.prompt_title = opts.prompt_title or "Shortcut Stories"

	pickers
		.new(opts, {
			prompt_title = opts.prompt_title,
			finder = finders.new_table({
				results = stories,
				entry_maker = make_entry,
			}),
			sorter = conf.generic_sorter(opts),
			previewer = create_previewer(),
			attach_mappings = function(prompt_bufnr, map)
				return attach_mappings(prompt_bufnr, map, opts)
			end,
		})
		:find()
end

function M.prompt_for_api_key(callback)
	-- Use vim.schedule to ensure non-blocking execution
	vim.schedule(function()
		vim.ui.input({
			prompt = "Enter your Shortcut API token: ",
			default = "",
		}, function(token)
			if not token or token == "" then
				vim.notify("Shortcut setup cancelled", vim.log.levels.INFO)
				return
			end
			
			-- Schedule the username prompt to avoid blocking
			vim.schedule(function()
				vim.ui.input({
					prompt = "Enter your Shortcut username (optional, press Enter to skip): ",
					default = "",
				}, function(username)
					-- Process the configuration in a scheduled callback
					vim.schedule(function()
						-- Trim and validate username
						if username then
							username = vim.trim(username)
							if username == "" then
								username = nil
							end
						end
						
						local setup_opts = { api_token = token }
						if username then
							setup_opts.username = username
						end
						
						-- Don't call setup again if we're already in setup
						local cfg = config.get()
						cfg.api_token = token
						if username then
							cfg.username = username
						end
						
						config.save_config(token, username or "")
						vim.notify("Shortcut configured successfully", vim.log.levels.INFO)
						
						if callback then
							vim.schedule(callback)
						end
					end)
				end)
			end)
		end)
	end)
end

function M.search_stories(opts)
	opts = opts or {}

	if not config.is_configured() then
		M.prompt_for_api_key(function()
			M.search_stories(opts)
		end)
		return
	end

	local query = opts.query
	if not query then
		vim.ui.input({ prompt = "Search stories: " }, function(input)
			if input and input ~= "" then
				opts.query = input
				M.search_stories(opts)
			end
		end)
		return
	end

	local stories, err = api.search_stories(query)
	if err then
		vim.notify("Error: " .. err, vim.log.levels.ERROR)
		return
	end

	if not stories or not stories.data or #stories.data == 0 then
		vim.notify("No stories found", vim.log.levels.INFO)
		return
	end

	opts.prompt_title = string.format("Search: %s (%d results)", query, #stories.data)
	M.show_stories(stories.data, opts)
end

function M.my_stories(opts)
	opts = opts or {}

	if not config.is_configured() then
		M.prompt_for_api_key(function()
			M.my_stories(opts)
		end)
		return
	end

	local cfg = config.get()
	
	local username = cfg.username and vim.trim(cfg.username) or nil
	
	-- Start with just the owner filter, no state filter initially
	local query
	if username and username ~= "" then
		query = "owner:" .. username
	else
		-- If no username, get recent stories
		query = ""
	end

	local stories, err = api.search_stories(query)
	if err then
		vim.notify("Error searching stories: " .. err, vim.log.levels.ERROR)
		return
	end

	if not stories or not stories.data or #stories.data == 0 then
		if username then
			vim.notify("No stories found for owner: " .. username, vim.log.levels.INFO)
		else
			vim.notify("No stories found", vim.log.levels.INFO)
		end
		return
	end

	opts.prompt_title = string.format("My Stories (%d)", #stories.data)
	M.show_stories(stories.data, opts)
end

function M.create_comment(story)
	vim.ui.input({ prompt = "Add comment to story sc-" .. story.id .. ": " }, function(input)
		if input and input ~= "" then
			local comment, err = api.create_comment(story.id, input)
			if err then
				vim.notify("Error creating comment: " .. err, vim.log.levels.ERROR)
			else
				vim.notify("Comment added successfully", vim.log.levels.INFO)
			end
		end
	end)
end

function M.create_story(opts)
	opts = opts or {}

	if not config.is_configured() then
		M.prompt_for_api_key(function()
			M.create_story(opts)
		end)
		return
	end

	-- Get selection if in visual mode
	local description = ""
	if opts.visual then
		description = utils.get_visual_selection()
	end

	vim.ui.input({ prompt = "Story title: " }, function(title)
		if not title or title == "" then
			return
		end

		vim.ui.select({ "feature", "bug", "chore" }, {
			prompt = "Story type:",
		}, function(story_type)
			if not story_type then
				return
			end

			-- Get projects
			local projects, err = api.get_projects()
			if err or not projects then
				vim.notify("Error fetching projects", vim.log.levels.ERROR)
				return
			end

			local project_names = vim.tbl_map(function(p)
				return p.name
			end, projects)

			vim.ui.select(project_names, {
				prompt = "Select project:",
			}, function(selected_project_name)
				if not selected_project_name then
					return
				end

				-- Find project ID
				local project_id
				for _, p in ipairs(projects) do
					if p.name == selected_project_name then
						project_id = p.id
						break
					end
				end

				local story_data = {
					name = title,
					description = description,
					project_id = project_id,
					story_type = story_type,
				}

				local story, err = api.create_story(story_data)
				if err then
					vim.notify("Error creating story: " .. err, vim.log.levels.ERROR)
				else
					vim.notify("Story created: sc-" .. story.id, vim.log.levels.INFO)
					local branch_name = utils.create_branch_name(story)
					utils.copy_to_clipboard(branch_name)
				end
			end)
		end)
	end)
end

return M