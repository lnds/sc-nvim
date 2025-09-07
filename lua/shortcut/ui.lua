local M = {}
local api = require("shortcut.api")
local config = require("shortcut.config")

M.current_stories = {}
M.list_buf = nil
M.detail_buf = nil
M.list_win = nil
M.detail_win = nil

local function format_story_line(story, index)
	local estimate = story.estimate and ("(" .. story.estimate .. ")") or ""
	local state = story.workflow_state_id and tostring(story.workflow_state_id) or "?"
	return string.format("%2d. [%s] %s %s %s", index, story.id, story.name, estimate, state)
end

local function show_story_detail(story)
	if not M.detail_buf or not vim.api.nvim_buf_is_valid(M.detail_buf) then
		return
	end

	-- Fetch full story details
	local full_story, err = api.get_story(story.id)
	if err then
		vim.notify("Error fetching story details: " .. err, vim.log.levels.ERROR)
		return
	end

	story = full_story or story

	local lines = {
		"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
		"  " .. story.name,
		"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
		"",
		"ID:       " .. story.id,
		"Type:     " .. (story.story_type or "Unknown"),
		"State:    " .. (story.workflow_state_id or "No State"),
		"Estimate: " .. (story.estimate and tostring(story.estimate) .. " points" or "Not estimated"),
		"Created:  " .. (story.created_at and story.created_at:sub(1, 10) or "Unknown"),
		"",
		"──────────────────────────────────────────",
		"Description",
		"──────────────────────────────────────────",
		"",
	}

	if story.description then
		for line in story.description:gmatch("[^\r\n]+") do
			table.insert(lines, line)
		end
	else
		table.insert(lines, "(No description)")
	end

	if story.labels and #story.labels > 0 then
		table.insert(lines, "")
		table.insert(lines, "──────────────────────────────────────────")
		table.insert(lines, "Labels")
		table.insert(lines, "──────────────────────────────────────────")
		for _, label in ipairs(story.labels) do
			table.insert(lines, "• " .. label.name)
		end
	end

	if story.tasks and #story.tasks > 0 then
		table.insert(lines, "")
		table.insert(lines, "──────────────────────────────────────────")
		table.insert(lines, "Tasks")
		table.insert(lines, "──────────────────────────────────────────")
		for _, task in ipairs(story.tasks) do
			local checkbox = task.complete and "☑" or "☐"
			table.insert(lines, checkbox .. " " .. task.description)
		end
	end

	vim.api.nvim_buf_set_option(M.detail_buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(M.detail_buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(M.detail_buf, "modifiable", false)
end

local function create_list_buffer()
	M.list_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(M.list_buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(M.list_buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(M.list_buf, "swapfile", false)
	vim.api.nvim_buf_set_name(M.list_buf, "Shortcut Stories")

	-- Set keymaps
	vim.api.nvim_buf_set_keymap(M.list_buf, "n", "<CR>", "", {
		callback = function()
			local line = vim.api.nvim_win_get_cursor(M.list_win)[1]
			if M.current_stories[line] then
				show_story_detail(M.current_stories[line])
			end
		end,
		noremap = true,
		silent = true,
	})

	vim.api.nvim_buf_set_keymap(M.list_buf, "n", "j", "", {
		callback = function()
			local line = vim.api.nvim_win_get_cursor(M.list_win)[1]
			if line < #M.current_stories then
				vim.api.nvim_win_set_cursor(M.list_win, { line + 1, 0 })
				show_story_detail(M.current_stories[line + 1])
			end
		end,
		noremap = true,
		silent = true,
	})

	vim.api.nvim_buf_set_keymap(M.list_buf, "n", "k", "", {
		callback = function()
			local line = vim.api.nvim_win_get_cursor(M.list_win)[1]
			if line > 1 then
				vim.api.nvim_win_set_cursor(M.list_win, { line - 1, 0 })
				show_story_detail(M.current_stories[line - 1])
			end
		end,
		noremap = true,
		silent = true,
	})

	vim.api.nvim_buf_set_keymap(M.list_buf, "n", "q", "", {
		callback = function()
			M.close()
		end,
		noremap = true,
		silent = true,
	})

	vim.api.nvim_buf_set_keymap(M.list_buf, "n", "r", "", {
		callback = function()
			M.refresh()
		end,
		noremap = true,
		silent = true,
	})

	vim.api.nvim_buf_set_keymap(M.list_buf, "n", "/", "", {
		callback = function()
			M.search()
		end,
		noremap = true,
		silent = true,
	})
end

local function create_detail_buffer()
	M.detail_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(M.detail_buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(M.detail_buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(M.detail_buf, "swapfile", false)
	vim.api.nvim_buf_set_option(M.detail_buf, "modifiable", false)
	vim.api.nvim_buf_set_name(M.detail_buf, "Story Details")
end

function M.open()
	if not config.is_configured() then
		M.prompt_for_api_key(function()
			M.open()
		end)
		return
	end

	-- Create new tab
	vim.cmd("tabnew")

	-- Create list window (left side)
	M.list_win = vim.api.nvim_get_current_win()
	create_list_buffer()
	vim.api.nvim_win_set_buf(M.list_win, M.list_buf)
	vim.api.nvim_win_set_width(M.list_win, 50)

	-- Create detail window (right side)
	vim.cmd("vsplit")
	M.detail_win = vim.api.nvim_get_current_win()
	create_detail_buffer()
	vim.api.nvim_win_set_buf(M.detail_win, M.detail_buf)

	-- Move focus back to list
	vim.api.nvim_set_current_win(M.list_win)

	-- Load initial data
	M.load_my_stories()
end

function M.load_my_stories()
	vim.api.nvim_buf_set_option(M.list_buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(M.list_buf, 0, -1, false, { "Loading stories..." })
	vim.api.nvim_buf_set_option(M.list_buf, "modifiable", false)

	-- Get username from config or prompt for it
	local cfg = config.get()
	local query = "state:unstarted,started"
	
	if cfg.username then
		query = "owner:" .. cfg.username .. " state:unstarted,started"
	end
	
	local stories, err = api.search_stories(query)

	if err then
		vim.notify("Error loading stories: " .. err, vim.log.levels.ERROR)
		return
	end

	if not stories or not stories.data or #stories.data == 0 then
		vim.api.nvim_buf_set_option(M.list_buf, "modifiable", true)
		vim.api.nvim_buf_set_lines(M.list_buf, 0, -1, false, { "No stories found" })
		vim.api.nvim_buf_set_option(M.list_buf, "modifiable", false)
		return
	end

	M.current_stories = {}
	local lines = {}

	for i, story in ipairs(stories.data) do
		M.current_stories[i] = story
		table.insert(lines, format_story_line(story, i))
	end

	vim.api.nvim_buf_set_option(M.list_buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(M.list_buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(M.list_buf, "modifiable", false)

	-- Show first story detail
	if #M.current_stories > 0 then
		show_story_detail(M.current_stories[1])
	end
end

function M.search()
	vim.ui.input({
		prompt = "Search stories: ",
		default = "",
	}, function(input)
		if input and input ~= "" then
			vim.api.nvim_buf_set_option(M.list_buf, "modifiable", true)
			vim.api.nvim_buf_set_lines(M.list_buf, 0, -1, false, { "Searching..." })
			vim.api.nvim_buf_set_option(M.list_buf, "modifiable", false)

			local stories, err = api.search_stories(input)
			if err then
				vim.notify("Error searching: " .. err, vim.log.levels.ERROR)
				return
			end

			if not stories or not stories.data or #stories.data == 0 then
				vim.api.nvim_buf_set_option(M.list_buf, "modifiable", true)
				vim.api.nvim_buf_set_lines(M.list_buf, 0, -1, false, { "No stories found" })
				vim.api.nvim_buf_set_option(M.list_buf, "modifiable", false)
				return
			end

			M.current_stories = {}
			local lines = {}

			for i, story in ipairs(stories.data) do
				M.current_stories[i] = story
				table.insert(lines, format_story_line(story, i))
			end

			vim.api.nvim_buf_set_option(M.list_buf, "modifiable", true)
			vim.api.nvim_buf_set_lines(M.list_buf, 0, -1, false, lines)
			vim.api.nvim_buf_set_option(M.list_buf, "modifiable", false)

			if #M.current_stories > 0 then
				show_story_detail(M.current_stories[1])
			end
		end
	end)
end

function M.refresh()
	M.load_my_stories()
end

function M.close()
	if M.list_win and vim.api.nvim_win_is_valid(M.list_win) then
		vim.api.nvim_win_close(M.list_win, true)
	end
	if M.detail_win and vim.api.nvim_win_is_valid(M.detail_win) then
		vim.api.nvim_win_close(M.detail_win, true)
	end
	M.list_buf = nil
	M.detail_buf = nil
	M.list_win = nil
	M.detail_win = nil
	M.current_stories = {}
end

function M.prompt_for_api_key(callback)
	vim.ui.input({
		prompt = "Enter your Shortcut API token: ",
		default = "",
	}, function(token)
		if token and token ~= "" then
			-- Also prompt for username
			vim.ui.input({
				prompt = "Enter your Shortcut username (for filtering your issues): ",
				default = "",
			}, function(username)
				local setup_opts = { api_token = token }
				if username and username ~= "" then
					setup_opts.username = username
				end
				
				require("shortcut").setup(setup_opts)
				vim.notify("Shortcut configured", vim.log.levels.INFO)

				-- Save to config file
				local config_path = vim.fn.stdpath("config") .. "/shortcut_config.lua"
				local config_content = string.format(
					[[-- Shortcut API Configuration
return {
  api_token = "%s",
  username = "%s"
}]],
					token,
					username or ""
				)
				vim.fn.writefile(vim.split(config_content, "\n"), config_path)

				if callback then
					callback()
				end
			end)
		end
	end)
end

return M