local M = {}

M.config = {
	api_token = nil,
	base_url = "https://api.app.shortcut.com/api/v3",
	timeout = 10000,
	default_query_limit = 25,
}

function M.setup(opts)
	opts = opts or {}

	if not opts.api_token then
		vim.notify(
			"Shortcut: API token is required. Set it with require('shortcut').setup({ api_token = 'your-token' })",
			vim.log.levels.ERROR
		)
	end

	M.config = vim.tbl_deep_extend("force", M.config, opts)
end

function M.get()
	return M.config
end

function M.is_configured()
	return M.config.api_token ~= nil
end

return M

