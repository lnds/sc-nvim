# sc-nvim

A Neovim plugin for interacting with Shortcut (formerly Clubhouse) project management tool.

## Features

- Search stories
- View workflows and their states
- List projects
- View story details
- Create and update stories (API support included)
- Add comments to stories

## Requirements

- Neovim 0.7.0+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (for HTTP requests)

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'lnds/sc-nvim',
  requires = {'nvim-lua/plenary.nvim'},
  config = function()
    require('shortcut').setup({
      api_token = 'your-shortcut-api-token'
    })
  end
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'lnds/sc-nvim',
  dependencies = {'nvim-lua/plenary.nvim'},
  config = function()
    require('shortcut').setup({
      api_token = 'your-shortcut-api-token'
    })
  end
}
```

## Configuration

```lua
require('shortcut').setup({
  api_token = 'your-shortcut-api-token', -- Required
  base_url = 'https://api.app.shortcut.com/api/v3', -- Optional, default shown
  timeout = 10000, -- Optional, request timeout in ms
  default_query_limit = 25, -- Optional, default number of results for searches
})
```

### Getting your API Token

1. Log in to your Shortcut account
2. Go to Settings → API Tokens
3. Generate a new API token
4. Copy the token and use it in your configuration

## Commands

- `:ShortcutSearch [query]` - Search for stories (prompts for query if not provided)
- `:ShortcutWorkflows` - List all workflows and their states
- `:ShortcutProjects` - List all projects
- `:ShortcutStory [id]` - View details of a specific story (prompts for ID if not provided)

## API Usage

You can also use the plugin programmatically:

```lua
local shortcut = require('shortcut')
local api = require('shortcut.api')

-- Search stories
local stories, err = api.search_stories("bug in login")

-- Get workflows
local workflows, err = api.get_workflows()

-- Get a specific story
local story, err = api.get_story("12345")

-- Create a new story
local new_story, err = api.create_story({
  name = "New feature",
  description = "Description here",
  project_id = 123,
  story_type = "feature"
})

-- Update a story
local updated, err = api.update_story("12345", {
  name = "Updated name",
  estimate = 3
})

-- Add a comment
local comment, err = api.create_comment("12345", "This is a comment")
```

## License

MIT