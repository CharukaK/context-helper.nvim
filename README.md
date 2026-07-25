# [WIP] context-helper.nvim

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

`setup()` is never called automatically — call it yourself so you control
config timing:

```lua
require("context-helper").setup({
  export = {
    default_format = "markdown", -- "markdown" | "text" | "json"
    clipboard_on_export = true,  -- also copy to clipboard on a bare :ExportAnnotations
  },
  ui = {
    overview = { width = 80, height = 15, border = "rounded" },
  },
})
```

## Commands

- `:AddAnnotation` — prompt for a comment and attach it to the visual selection.
- `:AnnotateLine` — prompt for a comment and attach it to the current line (no selection needed).
- `:AnnotateFile` — prompt for a comment and attach it to the entire current file.
- `:ListAnnotations` — populate the quickfix list with all annotations.
- `:ShowAnnotations` — open a read-only floating window listing all annotations (`q`/`<Esc>` to close).
- `:ExportAnnotations [target] [path]` — export to `clipboard`, `file [path]`, a format name, or the configured default.
- `:CopyAnnotations` — shorthand for `:ExportAnnotations clipboard`.
- `:ResetAnnotations` — clear all annotations after confirmation; `:ResetAnnotations!` skips the prompt.
- `:NewAnnotationSession` — clear all annotations instantly, no prompt.
- `:OpenSession` — invoke the `on_open_session` callback with the current annotations.

Annotations live in memory for the current session only — there is no persistence to disk.

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
