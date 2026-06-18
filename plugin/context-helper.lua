if vim.g.loaded_context_helper then
  return
end
vim.g.loaded_context_helper = true

-- Plugin entry point. Calls setup with no args so users who don't call
-- require("context-helper").setup() still get defaults.
