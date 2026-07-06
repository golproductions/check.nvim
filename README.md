# check.nvim

> **This is a thin wrapper.** The one location for Check (install, hook mode, MCP, CLI, and the HTTP contract) is [check.golproductions.com](https://check.golproductions.com) · [golproductions/check](https://github.com/golproductions/check). Integrate from there.

The anti-hallucination layer for Neovim.

## Install

### lazy.nvim
```lua
{ "golproductions/check.nvim",
  config = function()
    require("check").setup()
  end
}
```

### packer
```lua
use { "golproductions/check.nvim",
  config = function()
    require("check").setup()
  end
}
```

Check activates a free key on first run. No signup, no key to paste.

## Commands

- `:Check <command>`
- `:CheckSelection`
- `:CheckSetup`

## Bring your own key (optional)

A key is minted for you automatically. To reuse an existing Client ID, pass it to setup or set the `GOL_CLIENT_ID` environment variable:

```lua
require("check").setup({ client_id = "your_key" })
```

## Pricing

120 free checks every day. Then $0.0068 AUD per check. Credits never expire.
