-- Minimal init.lua for running tests with `nvim --headless`
-- Usage: nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/spec/ {minimal_init = 'tests/minimal_init.lua'}"

local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"

if not vim.loop.fs_stat(plenary_path) then
  vim.fn.system({
    "git",
    "clone",
    "--depth=1",
    "https://github.com/nvim-lua/plenary.nvim",
    plenary_path,
  })
end

vim.opt.rtp:prepend(plenary_path)
vim.opt.rtp:prepend(vim.fn.getcwd())

vim.cmd("runtime plugin/plenary.vim")
