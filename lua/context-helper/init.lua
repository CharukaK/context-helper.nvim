local M = {}

---@class ContextHelperConfig
---@field on_open_session fun(annotations: AnnotationMetadata[])|nil
-- Add configuration fields here as the plugin grows

---@class AnnotationMetadata
---@field buf_id integer Buffer handle the annotation belongs to
---@field file string Absolute path of the annotated file
---@field mark_id integer Extmark ID returned by nvim_buf_set_extmark
---@field comment string User-provided annotation text
---@field start_row integer? Start line (1-indexed)
---@field start_col integer? Start column (1-indexed)
---@field end_row integer? End line (1-indexed)
---@field end_col integer? End column (1-indexed)

---@type ContextHelperConfig
M.config = {
  on_open_session = nil,
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
  vim.api.nvim_create_user_command("ListAnnotations", M.open_quickfix_list, {})
  vim.api.nvim_create_user_command("OpenSession", function()
    if #annotations == 0 then
      vim.notify("No annotations to open", vim.log.levels.WARN)
      return
    end
    if M.config.on_open_session then
      M.config.on_open_session(M.get_annotations())
    else
      vim.notify("No on_open_session callback configured", vim.log.levels.WARN)
    end
  end, {})
end

---Return a copy of all current annotations
---@return AnnotationMetadata[]
function M.get_annotations()
  return vim.deepcopy(annotations)
end

---Build a position string like "10-15" or "42" from annotation metadata
---@param ann AnnotationMetadata
---@return string
function M.format_position(ann)
  if not ann.start_row then
    return ""
  end
  if ann.start_row == ann.end_row then
    return tostring(ann.start_row)
  end
  return ann.start_row .. "-" .. ann.end_row
end

---Format annotations into a string grouped by file
---@param anns AnnotationMetadata[]
---@param format "markdown"|"text"|"json"|nil
---@return string
function M.format_annotations(anns, format)
  format = format or "markdown"

  if format == "json" then
    return vim.json.encode(anns)
  end

  local by_file = {}
  for _, ann in ipairs(anns) do
    by_file[ann.file] = by_file[ann.file] or {}
    table.insert(by_file[ann.file], ann)
  end

  if format == "text" then
    local lines = {}
    for file, file_anns in pairs(by_file) do
      table.insert(lines, file)
      for _, ann in ipairs(file_anns) do
        local pos = M.format_position(ann)
        if pos ~= "" then
          table.insert(lines, "  [" .. pos .. "] " .. ann.comment)
        else
          table.insert(lines, "  " .. ann.comment)
        end
      end
      table.insert(lines, "")
    end
    return table.concat(lines, "\n")
  end

  local parts = { "# Annotations\n" }
  for file, file_anns in pairs(by_file) do
    table.insert(parts, "## " .. file .. "\n")
    for _, ann in ipairs(file_anns) do
      local pos = M.format_position(ann)
      if pos ~= "" then
        table.insert(parts, "- Lines " .. pos .. ": " .. ann.comment .. "\n")
      else
        table.insert(parts, "- " .. ann.comment .. "\n")
      end
    end
    table.insert(parts, "")
  end
  return table.concat(parts, "\n")
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
    vim.api.nvim_buf_del_extmark(value.buf_id, ns, value.mark_id)
  end
  annotations = {}
end

---Populate the quickfix list with all annotations and open the quickfix window
---@return nil
function M.open_quickfix_list()
  local anns = M.get_annotations()
  if #anns == 0 then
    vim.notify("No annotations to list", vim.log.levels.WARN)
    return
  end

  local qf_entries = {}
  for _, ann in ipairs(anns) do
    table.insert(qf_entries, {
      filename = ann.file,
      lnum = ann.start_row or 1,
      col = ann.start_col or 1,
      text = ann.comment,
    })
  end

  vim.fn.setqflist(qf_entries, "r")
  vim.cmd("copen")
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
      start_row = positions[1][1][2],
      start_col = positions[1][1][3],
      end_row = positions[#positions][2][2],
      end_col = positions[#positions][2][3],
    }

    table.insert(annotations, metadata)
  end)
end

return M
