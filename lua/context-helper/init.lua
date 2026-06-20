local M = {}

M.config = {
  -- default configuration options
}

local annotations = {}
local ns = vim.api.nvim_create_namespace("context-helper")

---Setup function to initialize the plugin
---@param opts table|nil Optional configuration overrides
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  vim.api.nvim_create_user_command("NewAnnotationSession", M.new_session, {})
  vim.api.nvim_create_user_command("AddAnnotation", M.prompt_for_comment, {})
  vim.api.nvim_create_user_command("ResetAnnotations", M.reset, {})
end

function M.new_session()
  for _, value in ipairs(annotations) do
    print(value.buf_id, ns, value.mark_id)
    vim.api.nvim_buf_del_extmark(value.buf_id, ns, value.mark_id)
  end
  annotations = {}
end

function M.reset()
  for _, value in ipairs(annotations) do
    print(value.buf_id, ns, value.mark_id)
    vim.api.nvim_buf_del_extmark(value.buf_id, ns, value.mark_id)
  end
  annotations = {}
end

function M.prompt_for_comment()
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

    local metadata = {
      buf_id = vim.api.nvim_get_current_buf(),
      file = vim.api.nvim_buf_get_name(0),
      mark_id = ext_mark_id,
      comment = input,
    }

    table.insert(annotations, metadata)

    -- vim.notify(
    --   start_pos[1] .. "  " .. start_pos[2] .. "  " .. start_pos[3] .. "  " .. start_pos[3] .. " " .. input,
    --   0,
    --   {}
    -- )
  end)
end

return M
