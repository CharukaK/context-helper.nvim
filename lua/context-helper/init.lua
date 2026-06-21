local M = {}

---@class ContextHelperConfig
-- Add configuration fields here as the plugin grows

---@class AnnotationMetadata
---@field buf_id integer Buffer handle the annotation belongs to
---@field file string Absolute path of the annotated file
---@field mark_id integer Extmark ID returned by nvim_buf_set_extmark
---@field comment string User-provided annotation text

---@type ContextHelperConfig
M.config = {
  -- default configuration options
}

---@type AnnotationMetadata[]
local annotations = {}

---@type integer
local ns = vim.api.nvim_create_namespace("context-helper")

---Setup function to initialize the plugin
---@param opts ContextHelperConfig|nil Optional configuration overrides
---@return nil
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  vim.api.nvim_create_user_command("NewAnnotationSession", M.new_session, {})
  vim.api.nvim_create_user_command("AddAnnotation", M.prompt_for_comment, {})
  vim.api.nvim_create_user_command("ResetAnnotations", M.reset, {})
end

---Start a new annotation session, clearing all existing annotations
---@return nil
function M.new_session()
  M.reset()
end

---Delete all extmarks and clear the annotations list
---@return nil
function M.reset()
  for _, value in ipairs(annotations) do
    print(value.buf_id, ns, value.mark_id)
    vim.api.nvim_buf_del_extmark(value.buf_id, ns, value.mark_id)
  end
  annotations = {}
end

---Prompt the user for a comment and attach it as a virtual-text extmark
---over the current visual selection
---@return nil
function M.prompt_for_comment()
  ---@type {[1]: integer[], [2]: integer[]}[]
  local positions = vim.fn.getregionpos(vim.fn.getpos("v"), vim.fn.getpos("."))

  vim.ui.input({
    prompt = "Comment: ",
  }, function(input)
    if input == nil then
      return
    end

    local ext_mark_id = vim.api.nvim_buf_set_extmark(0, ns, positions[1][1][2] - 1, positions[1][1][3] - 1, {
      virt_text = {
        { " 💬 ", "Comment" },
      },
      end_line = positions[#positions][2][2] - 1,
      end_col = positions[#positions][2][3] - 1,
    })

    ---@type AnnotationMetadata
    local metadata = {
      buf_id = vim.api.nvim_get_current_buf(),
      file = vim.api.nvim_buf_get_name(0),
      mark_id = ext_mark_id,
      comment = input,
    }

    table.insert(annotations, metadata)
  end)
end

return M
