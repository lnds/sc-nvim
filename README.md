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
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (for the UI picker interface)

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'lnds/sc-nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim'
  },
  config = function()
    require('shortcut').setup({
      api_token = 'your-shortcut-api-token',
      username = 'your-username' -- Optional
    })
  end
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'lnds/sc-nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim'
  },
  config = function()
    require('shortcut').setup({
      api_token = 'your-shortcut-api-token',
      username = 'your-username' -- Optional
    })
  end
}
```

## Configuration

```lua
require('shortcut').setup({
  api_token = 'your-shortcut-api-token', -- Required
  username = 'your-shortcut-username', -- Optional, for filtering your assigned issues
  base_url = 'https://api.app.shortcut.com/api/v3', -- Optional, default shown
  timeout = 10000, -- Optional, request timeout in ms
  default_query_limit = 25, -- Optional, default number of results for searches
  skip_dependency_check = false, -- Optional, skip checking for required plugins
})
```

The plugin will prompt for your API token (and optionally username) on first use if not configured. The configuration is saved to `~/.local/share/nvim/shortcut_config.lua` for persistence.

**Note:** The plugin will check for required dependencies (plenary.nvim and telescope.nvim) on setup and notify you if any are missing.

### Getting your API Token

1. Log in to your Shortcut account
2. Go to Settings → API Tokens
3. Generate a new API token
4. Copy the token and use it in your configuration

## Commands

### Main Commands
- `:Shortcut` - Open your assigned stories in Telescope picker
- `:ShortcutMyStories` - View your assigned stories
- `:ShortcutSearchTelescope [query]` - Search stories using Telescope picker
- `:ShortcutCreate` - Create a new story (visual mode: use selection as description)

### Picker Key Mappings
Inside the Telescope picker:
- `<CR>` - Copy branch name to clipboard
- `<C-b>` - Copy branch name to clipboard
- `<C-y>` - Copy branch name to clipboard (alternative)
- `<C-o>` - Open story in browser
- `<C-d>` - Copy story ID to clipboard
- `<C-c>` - Add comment to story

### Legacy Commands
- `:ShortcutSearch [query]` - Basic search (without Telescope)
- `:ShortcutWorkflows` - List all workflows and their states
- `:ShortcutProjects` - List all projects
- `:ShortcutStory [id]` - View story details in buffer

### Default Keymaps
- `<leader>mm` - Open Shortcut UI (shows my stories)
- `<leader>ms` - Search stories
- `<leader>mc` - Create new story (visual mode: use selection)

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

-- Open the UI
shortcut.open()
```

## UI Features

The plugin provides a Telescope-based UI similar to Linear.nvim:
- **Smart Entry Display**: Shows story ID, estimate, and truncated title
- **Rich Preview**: Displays full story details, tasks, comments, and metadata
- **Branch Name Generation**: Automatically creates git-friendly branch names
- **Quick Actions**: Copy branch names, open in browser, add comments
- **Visual Mode Support**: Create stories from selected text

## License

MIT