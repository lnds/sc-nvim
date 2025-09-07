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
		if ok then
			return saved
		end
	end
	return nil
end

function M.save_config(token, username)
	-- Save config asynchronously to avoid blocking
	vim.schedule(function()
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
		
		-- Ensure data directory exists
		local data_dir = vim.fn.stdpath("data")
		if vim.fn.isdirectory(data_dir) == 0 then
			vim.fn.mkdir(data_dir, "p")
		end
		
		-- Write file
		local ok, err = pcall(function()
			vim.fn.writefile(vim.split(config_content, "\n"), config_path)
		end)
		
		if not ok then
			vim.notify("Failed to save config: " .. tostring(err), vim.log.levels.WARN)
		end
	end)
end

function M.get()
	return M.config
end

function M.is_configured()
	return M.config.api_token ~= nil
end

return M

