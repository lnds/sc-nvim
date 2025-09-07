local M = {}

-- OS detection
function M.get_os()
	local os_name = vim.loop.os_uname().sysname
	if os_name == "Darwin" then
		return "mac"
	elseif os_name == "Linux" then
		return "linux"
	elseif os_name:match("Windows") then
		return "windows"
	end
	return "unknown"
end

-- Open URL in browser
function M.open_url(url)
	local os_type = M.get_os()
	local cmd

	if os_type == "mac" then
		cmd = "open"
	elseif os_type == "linux" then
		cmd = "xdg-open"
	elseif os_type == "windows" then
		cmd = "start"
	else
		vim.notify("Unable to detect OS for opening URL", vim.log.levels.ERROR)
		return
	end

	vim.fn.jobstart({ cmd, url }, { detach = true })
end

-- Copy to clipboard
function M.copy_to_clipboard(text)
	vim.fn.setreg("+", text)
	vim.notify("Copied: " .. text, vim.log.levels.INFO)
end

-- Format story for display
function M.format_story_display(story)
	local id = story.id or "?"
	local name = story.name or "Untitled"
	local estimate = story.estimate and ("[" .. story.estimate .. "pts]") or ""
	return string.format("sc-%s %s %s", id, estimate, name)
end

-- Format story details
function M.format_story_details(story)
	local lines = {}
	local function add_line(label, value)
		if value and value ~= "" then
			table.insert(lines, string.format("%-12s: %s", label, value))
		end
	end

	add_line("ID", story.id)
	add_line("Type", story.story_type)
	add_line("State", story.workflow_state_id)
	add_line("Estimate", story.estimate and tostring(story.estimate) .. " points")
	add_line("Created", story.created_at and story.created_at:sub(1, 10))
	add_line("Updated", story.updated_at and story.updated_at:sub(1, 10))

	if story.owner_ids and #story.owner_ids > 0 then
		add_line("Owners", table.concat(story.owner_ids, ", "))
	end

	if story.labels and #story.labels > 0 then
		local label_names = vim.tbl_map(function(l)
			return l.name
		end, story.labels)
		add_line("Labels", table.concat(label_names, ", "))
	end

	return lines
end

-- Get visual selection
function M.get_visual_selection()
	local s_start = vim.fn.getpos("'<")
	local s_end = vim.fn.getpos("'>")
	local n_lines = math.abs(s_end[2] - s_start[2]) + 1
	local lines = vim.api.nvim_buf_get_lines(0, s_start[2] - 1, s_end[2], false)
	lines[1] = string.sub(lines[1], s_start[3], -1)
	if n_lines == 1 then
		lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3] - s_start[3] + 1)
	else
		lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3])
	end
	return table.concat(lines, "\n")
end

-- Create floating window
function M.create_floating_window(opts)
	opts = opts or {}
	local width = opts.width or math.floor(vim.o.columns * 0.8)
	local height = opts.height or math.floor(vim.o.lines * 0.8)
	local row = opts.row or math.floor((vim.o.lines - height) / 2)
	local col = opts.col or math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = opts.border or "rounded",
		title = opts.title,
		title_pos = "center",
	})

	-- Set buffer options
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)

	-- Set window options
	vim.api.nvim_win_set_option(win, "wrap", false)
	vim.api.nvim_win_set_option(win, "cursorline", true)

	return buf, win
end

-- Parse story ID from text
function M.parse_story_id(text)
	-- Match patterns like sc-123, #123, or just 123
	local patterns = { "sc%-(%d+)", "#(%d+)", "^(%d+)$" }
	for _, pattern in ipairs(patterns) do
		local id = text:match(pattern)
		if id then
			return id
		end
	end
	return nil
end

-- Format workflow state
function M.format_workflow_state(workflows, state_id)
	if not workflows or not state_id then
		return "Unknown"
	end

	for _, workflow in ipairs(workflows) do
		for _, state in ipairs(workflow.states or {}) do
			if state.id == state_id then
				return state.name
			end
		end
	end
	return tostring(state_id)
end

-- URL encode a string
function M.url_encode(str)
	if not str then
		return ""
	end
	-- Replace special characters with their URL encoded equivalents
	str = string.gsub(str, "([^%w%-%.%_%~])", function(c)
		return string.format("%%%02X", string.byte(c))
	end)
	return str
end

-- Truncate string
function M.truncate(str, max_len)
	if not str then
		return ""
	end
	if #str <= max_len then
		return str
	end
	return str:sub(1, max_len - 3) .. "..."
end

-- Create branch name from story
function M.create_branch_name(story)
	if not story then
		return nil
	end
	local name = story.name or "untitled"
	-- Replace spaces and special chars with hyphens
	name = name:gsub("[^%w%-_]", "-"):gsub("%-+", "-"):lower()
	-- Remove leading/trailing hyphens
	name = name:gsub("^%-", ""):gsub("%-$", "")
	-- Truncate if too long
	name = M.truncate(name, 50)
	return string.format("sc-%s-%s", story.id, name)
end

return M