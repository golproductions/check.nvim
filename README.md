# check.nvim

The universal anti-hallucination engine for Neovim.

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

- `:Check <command>`
- `:CheckSelection`
- `:CheckSetup`

## Get a Client ID

Free at [golproductions.com/check](https://www.golproductions.com/check.html)
