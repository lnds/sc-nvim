local M = {}

local config = require("shortcut.config")
local api = require("shortcut.api")

local function check_dependencies()
	local missing_deps = {}
	
	-- Check for plenary
	local has_plenary = pcall(require, "plenary")
	if not has_plenary then
		table.insert(missing_deps, "nvim-lua/plenary.nvim")
	end
	
	-- Check for telescope
	local has_telescope = pcall(require, "telescope")
	if not has_telescope then
		table.insert(missing_deps, "nvim-telescope/telescope.nvim")
	end
	
	if #missing_deps > 0 then
		local msg = "Shortcut.nvim requires the following plugins:\n"
		for _, dep in ipairs(missing_deps) do
			msg = msg .. "  - " .. dep .. "\n"
		end
		msg = msg .. "\nPlease install them for the plugin to work properly."
		
		vim.defer_fn(function()
			vim.notify(msg, vim.log.levels.ERROR)
		end, 100)
		return false
	end
	
	return true
end

function M.setup(opts)
	opts = opts or {}
	
	-- Setup config without blocking
	config.setup(opts)
	
	-- Defer dependency check to avoid blocking startup
	if not opts.skip_dependency_check then
		vim.defer_fn(function()
			check_dependencies()
		end, 100)
	end
end

-- Public API
function M.get_stories()
	return api.get_stories()
end

function M.get_workflows()
	return api.get_workflows()
end

function M.search_stories(query)
	return api.search_stories(query)
end

function M.create_story(data)
	return api.create_story(data)
end

function M.update_story(id, data)
	return api.update_story(id, data)
end

-- Picker UI (requires telescope)
function M.open()
	local has_telescope = pcall(require, "telescope")
	if has_telescope then
		require("shortcut.picker").my_stories()
	else
		vim.notify("Telescope is required for the UI. Please install nvim-telescope/telescope.nvim", vim.log.levels.ERROR)
	end
end

return M

