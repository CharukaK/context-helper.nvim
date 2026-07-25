# [WIP] context-helper.nvim

A Neovim plugin for annotating locations in your code with short comments,
then exporting those annotations as context for AI tools and prompts.

## Requirements

- Neovim 0.10+ (uses `vim.fn.getregionpos()`)

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "CharukaK/context-helper.nvim",
  cmd = {
    "AddAnnotation",
    "AnnotateLine",
    "AnnotateFile",
    "ListAnnotations",
    "ShowAnnotations",
    "ExportAnnotations",
    "CopyAnnotations",
    "ResetAnnotations",
    "NewAnnotationSession",
    "OpenSession",
  },
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
  "CharukaK/context-helper.nvim",
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
  -- called by :OpenSession with the current annotation list (see below)
  on_open_session = function(annotations)
    -- e.g. hand `annotations` off to another tool or workflow
  end,
})
```

## Commands

- `:AddAnnotation` — prompt for a comment and attach it to the visual selection.
- `:AnnotateLine` — prompt for a comment and attach it to the current line (no selection needed).
- `:AnnotateFile` — prompt for a comment and attach it to the entire current file.
- `:ListAnnotations` — populate the quickfix list with all annotations.
- `:ShowAnnotations` — open a read-only floating window listing all annotations (`q`/`<Esc>` to close).
- `:ExportAnnotations [target] [path]` — export to `clipboard`, `file [path]`, a format name, or the configured default. `file` with no `path` writes a timestamped file (`annotations-YYYYMMDD-HHMMSS.md`) in the current directory.
- `:CopyAnnotations` — shorthand for `:ExportAnnotations clipboard`.
- `:ResetAnnotations` — clear all annotations after confirmation; `:ResetAnnotations!` skips the prompt.
- `:NewAnnotationSession` — clear all annotations instantly, no prompt.
- `:OpenSession` — invoke the `on_open_session` callback with the current annotations. Warns and does nothing if there are no annotations yet, or if no `on_open_session` callback is configured.

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
