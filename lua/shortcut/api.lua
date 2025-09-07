local M = {}
local config = require("shortcut.config")
local curl = require("plenary.curl")
local utils = require("shortcut.utils")

local function make_request(endpoint, method, body)
	local cfg = config.get()

	if not config.is_configured() then
		vim.notify("Shortcut: API token not configured", vim.log.levels.ERROR)
		return nil, "API token not configured"
	end

	local url = cfg.base_url .. endpoint
	local headers = {
		["Shortcut-Token"] = cfg.api_token,
		["Content-Type"] = "application/json",
	}

	local opts = {
		url = url,
		method = method or "GET",
		headers = headers,
		timeout = cfg.timeout,
	}

	if body then
		opts.body = vim.fn.json_encode(body)
	end

	local response = curl.request(opts)

	if response.status ~= 200 and response.status ~= 201 then
		return nil, "API request failed: " .. (response.body or "Unknown error")
	end

	-- Use vim.json.decode if available (Neovim 0.7+), fallback to vim.fn.json_decode
	local ok, decoded
	if vim.json and vim.json.decode then
		ok, decoded = pcall(vim.json.decode, response.body)
	else
		ok, decoded = pcall(vim.fn.json_decode, response.body)
	end
	
	if not ok then
		return nil, "Failed to decode JSON response: " .. tostring(decoded)
	end
	
	return decoded, nil
end

function M.get_workflows()
	return make_request("/workflows", "GET")
end

function M.get_stories(project_id)
	local endpoint = "/stories"
	if project_id then
		endpoint = "/projects/" .. project_id .. "/stories"
	end
	return make_request(endpoint, "GET")
end

function M.search_stories(query)
	local cfg = config.get()
	-- Properly URL encode the query parameter
	local encoded_query = utils.url_encode(query)
	local endpoint = "/search/stories?query=" .. encoded_query .. "&page_size=" .. cfg.default_query_limit
	return make_request(endpoint, "GET")
end

function M.get_story(story_id)
	return make_request("/stories/" .. story_id, "GET")
end

function M.create_story(story_data)
	return make_request("/stories", "POST", story_data)
end

function M.update_story(story_id, updates)
	return make_request("/stories/" .. story_id, "PUT", updates)
end

function M.create_comment(story_id, text)
	local comment_data = {
		text = text,
	}
	return make_request("/stories/" .. story_id .. "/comments", "POST", comment_data)
end

function M.get_members()
	return make_request("/members", "GET")
end

function M.get_projects()
	return make_request("/projects", "GET")
end

function M.get_epics()
	return make_request("/epics", "GET")
end

function M.get_labels()
	return make_request("/labels", "GET")
end

return M

