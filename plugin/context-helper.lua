if vim.g.loaded_context_helper then
  return
end
vim.g.loaded_context_helper = true

-- Plugin entry point. Deliberately does NOT call setup() here so users
-- control config timing; call require("context-helper").setup() yourself.
