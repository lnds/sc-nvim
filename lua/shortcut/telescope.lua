local M = {}
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local api = require("shortcut.api")
local config = require("shortcut.config")

local function format_story_entry(story)
	local workflow_state = story.workflow_state_id and tostring(story.workflow_state_id) or "No State"
	local estimate = story.estimate and ("(" .. story.estimate .. "pts)") or ""
	return string.format("[%s] %s %s - %s", story.id, story.name, estimate, workflow_state)
end

local function create_story_previewer()
	return previewers.new_buffer_previewer({
		title = "Story Details",
		define_preview = function(self, entry, status)
			local story = entry.value
			local lines = {
				"# " .. story.name,
				"",
				"**ID:** " .. story.id,
				"**Type:** " .. (story.story_type or "Unknown"),
				"**State:** " .. (story.workflow_state_id or "No State"),
				"**Estimate:** " .. (story.estimate and tostring(story.estimate) .. " points" or "Not estimated"),
				"**Created:** " .. (story.created_at or "Unknown"),
				"",
				"## Description",
				"",
			}

			if story.description then
				for line in story.description:gmatch("[^\r\n]+") do
					table.insert(lines, line)
				end
			else
				table.insert(lines, "_No description_")
			end

			if story.labels and #story.labels > 0 then
				table.insert(lines, "")
				table.insert(lines, "## Labels")
				for _, label in ipairs(story.labels) do
					table.insert(lines, "- " .. label.name)
				end
			end

			if story.tasks and #story.tasks > 0 then
				table.insert(lines, "")
				table.insert(lines, "## Tasks")
				for _, task in ipairs(story.tasks) do
					local checkbox = task.complete and "[x]" or "[ ]"
					table.insert(lines, checkbox .. " " .. task.description)
				end
			end

			if story.comments and #story.comments > 0 then
				table.insert(lines, "")
				table.insert(lines, "## Comments")
				for _, comment in ipairs(story.comments) do
					table.insert(lines, "")
					table.insert(lines, "**" .. (comment.author_id or "Unknown") .. ":** " .. comment.text)
				end
			end

			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
			vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
		end,
	})
end

function M.search_stories(opts)
	opts = opts or {}

	if not config.is_configured() then
		M.prompt_for_api_key()
		return
	end

	local query = opts.query or vim.fn.input("Search stories: ")
	if query == "" then
		return
	end

	local stories, err = api.search_stories(query)
	if err then
		vim.notify("Error searching stories: " .. err, vim.log.levels.ERROR)
		return
	end

	if not stories or not stories.data then
		vim.notify("No stories found", vim.log.levels.INFO)
		return
	end

	pickers
		.new(opts, {
			prompt_title = "Shortcut Stories",
			finder = finders.new_table({
				results = stories.data,
				entry_maker = function(story)
					return {
						value = story,
						display = format_story_entry(story),
						ordinal = story.name .. " " .. (story.description or ""),
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			previewer = create_story_previewer(),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if selection then
						M.open_story_detail(selection.value)
					end
				end)
				return true
			end,
		})
		:find()
end

function M.my_stories(opts)
	opts = opts or {}

	if not config.is_configured() then
		M.prompt_for_api_key()
		return
	end

	-- Get current user info first
	local members, err = api.get_members()
	if err then
		vim.notify("Error fetching members: " .. err, vim.log.levels.ERROR)
		return
	end

	-- Find current user (simplified - in production you'd match by email or have a config option)
	local current_user_id = nil
	if members and #members > 0 then
		-- For now, we'll need to configure this or prompt
		vim.notify("Please search with owner:<your-username> for now", vim.log.levels.INFO)
		return
	end

	local query = "owner:me state:started,unstarted"
	local stories, err = api.search_stories(query)
	if err then
		vim.notify("Error fetching stories: " .. err, vim.log.levels.ERROR)
		return
	end

	if not stories or not stories.data then
		vim.notify("No assigned stories found", vim.log.levels.INFO)
		return
	end

	pickers
		.new(opts, {
			prompt_title = "My Shortcut Stories",
			finder = finders.new_table({
				results = stories.data,
				entry_maker = function(story)
					return {
						value = story,
						display = format_story_entry(story),
						ordinal = story.name .. " " .. (story.description or ""),
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			previewer = create_story_previewer(),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if selection then
						M.open_story_detail(selection.value)
					end
				end)
				return true
			end,
		})
		:find()
end

function M.prompt_for_api_key()
	vim.ui.input({
		prompt = "Enter your Shortcut API token: ",
		default = "",
	}, function(input)
		if input and input ~= "" then
			require("shortcut").setup({
				api_token = input,
			})
			vim.notify("API token configured successfully", vim.log.levels.INFO)
			-- Optionally save to a local config file
			M.save_api_key(input)
		end
	end)
end

function M.save_api_key(token)
	local config_path = vim.fn.stdpath("config") .. "/shortcut_config.lua"
	local config_content = string.format(
		[[-- Shortcut API Configuration
return {
  api_token = "%s"
}]],
		token
	)
	vim.fn.writefile(vim.split(config_content, "\n"), config_path)
end

function M.open_story_detail(story)
	-- Create a new buffer for the story detail
	vim.cmd("vsplit")
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, buf)

	local lines = {
		"# " .. story.name,
		"",
		"ID: " .. story.id,
		"Type: " .. (story.story_type or "Unknown"),
		"State: " .. (story.workflow_state_id or "No State"),
		"Estimate: " .. (story.estimate and tostring(story.estimate) .. " points" or "Not estimated"),
		"",
		"## Description",
		"",
	}

	if story.description then
		for line in story.description:gmatch("[^\r\n]+") do
			table.insert(lines, line)
		end
	else
		table.insert(lines, "No description")
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_name(buf, "Shortcut: " .. story.name)
end

return M