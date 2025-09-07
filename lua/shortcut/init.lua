local M = {}

local config = require("shortcut.config")
local api = require("shortcut.api")

function M.setup(opts)
	config.setup(opts)
end

function M.get_stories()
	return api.get_stories()
end

function M.get_workflows()
	return api.get_workflows()
end

function M.search_stories(query)
	return api.search_stories(query)
end

return M

