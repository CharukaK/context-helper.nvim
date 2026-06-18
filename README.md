# context-helper.nvim

A Neovim plugin.

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-username/context-helper.nvim",
  config = function()
    require("context-helper").setup({
      -- your options
    })
  end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "your-username/context-helper.nvim",
  config = function()
    require("context-helper").setup({})
  end,
}
```

## Configuration

```lua
require("context-helper").setup({
  -- options
})
```

## Development

### Running tests

```sh
nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/spec/ {minimal_init = 'tests/minimal_init.lua'}" \
  +qa
```

### Linting

```sh
stylua --check lua/
```

## License

MIT
