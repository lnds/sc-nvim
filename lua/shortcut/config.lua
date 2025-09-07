local M = {}

M.config = {
	api_token = nil,
	base_url = "https://api.app.shortcut.com/api/v3",
	timeout = 10000,
	default_query_limit = 25,
	username = nil,
}

function M.setup(opts)
	opts = opts or {}

	-- Load saved config synchronously but safely
	local saved_config = M.load_saved_config()
	
	-- Merge configs: defaults < saved < provided opts
	if saved_config then
		M.config = vim.tbl_deep_extend("force", M.config, saved_config, opts)
	else
		M.config = vim.tbl_deep_extend("force", M.config, opts)
	end
end

function M.load_saved_config()
	local config_path = vim.fn.stdpath("data") .. "/shortcut_config.lua"
	
	if vim.fn.filereadable(config_path) == 1 then
		local ok, saved = pcall(dofile, config_path)
		if ok and saved then
			return saved
		end
	end
	return nil
end

function M.save_config(token, username)
	local config_path = vim.fn.stdpath("data") .. "/shortcut_config.lua"
	local config_content = string.format(
		[[-- Shortcut API Configuration
return {
  api_token = %q,
  username = %q
}]],
		token or "",
		username or ""
	)
	
	-- Remove verbose logging during normal operation
	
	-- Ensure data directory exists
	local data_dir = vim.fn.stdpath("data")
	if vim.fn.isdirectory(data_dir) == 0 then
		vim.fn.mkdir(data_dir, "p")
	end
	
	-- Write file synchronously for immediate persistence
	local ok, err = pcall(function()
		vim.fn.writefile(vim.split(config_content, "\n"), config_path)
	end)
	
	if ok then
		-- Also update the current config immediately
		M.config.api_token = token
		if username and username ~= "" then
			M.config.username = username
		end
	else
		vim.notify("Failed to save Shortcut config: " .. tostring(err), vim.log.levels.ERROR)
	end
end

function M.get()
	return M.config
end

function M.is_configured()
	-- Try to load saved config if no token is set
	if not M.config.api_token then
		local saved_config = M.load_saved_config()
		if saved_config and saved_config.api_token then
			M.config = vim.tbl_deep_extend("force", M.config, saved_config)
		end
	end
	return M.config.api_token ~= nil
end

return M

