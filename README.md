# check.nvim

Anti-hallucination firewall for Neovim. Validates commands before execution.

## Install

### lazy.nvim
```lua
{ "golproductions/check.nvim",
  config = function()
    require("check").setup({ client_id = "YOUR_CLIENT_ID" })
  end
}
```

### packer
```lua
use { "golproductions/check.nvim",
  config = function()
    require("check").setup({ client_id = "YOUR_CLIENT_ID" })
  end
}
```

Or set `GOL_CLIENT_ID` environment variable instead.

## Commands

- `:Check <command>` — validate a shell command
- `:CheckSelection` — validate visually selected text
- `:CheckSetup` — set your Client ID interactively

## Get a Client ID

Free at [golproductions.com/check](https://www.golproductions.com/check.html)
