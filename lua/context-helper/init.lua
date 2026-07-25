local M = {}

---@class ContextHelperConfig
---@field on_open_session fun(annotations: AnnotationMetadata[])|nil
---@field export ExportConfig
---@field ui UIConfig

---@class AnnotationMetadata
---@field buf_id integer Buffer handle the annotation belongs to
---@field file string Absolute path of the annotated file
---@field mark_id integer Extmark ID returned by nvim_buf_set_extmark
---@field comment string User-provided annotation text
---@field start_row integer? Start line (1-indexed)
---@field start_col integer? Start column (1-indexed)
---@field end_row integer? End line (1-indexed)
---@field end_col integer? End column (1-indexed)

---@class ExportConfig
---@field default_format "markdown"|"text"|"json" Format used when no explicit target/format is given
---@field clipboard_on_export boolean Whether a bare `:ExportAnnotations` (no args) also copies to the clipboard

---@class UIConfig
---@field overview OverviewConfig

---@class OverviewConfig
---@field width integer Max width of the :ShowAnnotations floating window
---@field height integer Max height of the :ShowAnnotations floating window
---@field border string Border style, passed to nvim_open_win

---@type ContextHelperConfig
M.config = {
  on_open_session = nil,
  export = {
    default_format = "markdown",
    clipboard_on_export = true,
  },
  ui = {
    overview = {
      width = 80,
      height = 15,
      border = "rounded",
    },
  },
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

  vim.api.nvim_create_user_command("NewAnnotationSession", M.reset, {})
  vim.api.nvim_create_user_command("AddAnnotation", M.prompt_for_comment, {})
  vim.api.nvim_create_user_command("AnnotateLine", M.annotate_line, {})
  vim.api.nvim_create_user_command("AnnotateFile", M.annotate_file, {})
  vim.api.nvim_create_user_command("ResetAnnotations", function(cmd_opts)
    M.confirm_reset(cmd_opts.bang)
  end, { bang = true })
  vim.api.nvim_create_user_command("ListAnnotations", M.open_quickfix_list, {})
  vim.api.nvim_create_user_command("ExportAnnotations", function(cmd_opts)
    M.export_annotations(cmd_opts.args)
  end, { nargs = "*" })
  vim.api.nvim_create_user_command("CopyAnnotations", M.copy_annotations_to_clipboard, {})
  vim.api.nvim_create_user_command("ShowAnnotations", M.show_overview, {})
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

---Delete all extmarks and clear the annotations list
---@return nil
function M.reset()
  for _, value in ipairs(annotations) do
    pcall(vim.api.nvim_buf_del_extmark, value.buf_id, ns, value.mark_id)
  end
  annotations = {}
end

---Reset annotations, prompting for confirmation unless bang-forced or already empty
---@param bang boolean? Skip the confirmation prompt
---@return nil
function M.confirm_reset(bang)
  if bang or #annotations == 0 then
    M.reset()
    return
  end

  local choice =
    vim.fn.confirm(string.format("Delete all %d annotation(s)? This cannot be undone.", #annotations), "&Yes\n&No", 2)
  if choice == 1 then
    M.reset()
  else
    vim.notify("Reset cancelled", vim.log.levels.INFO)
  end
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

---Create an extmark over the given range and record it as an annotation
---@param start_row integer Start line (1-indexed)
---@param start_col integer Start column (1-indexed)
---@param end_row integer End line (1-indexed)
---@param end_col integer End column (1-indexed)
---@param virt_text string Virtual text label rendered over the range
---@param comment string User-provided annotation text
---@return nil
local function add_annotation(start_row, start_col, end_row, end_col, virt_text, comment)
  local buf_id = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf_id)
  if file == "" then
    vim.notify("context-helper: cannot annotate an unnamed buffer", vim.log.levels.WARN)
    return
  end

  local ext_mark_id = vim.api.nvim_buf_set_extmark(buf_id, ns, start_row - 1, start_col - 1, {
    virt_text = { { virt_text, "Comment" } },
    end_line = end_row - 1,
    end_col = end_col - 1,
  })

  ---@type AnnotationMetadata
  local metadata = {
    buf_id = buf_id,
    file = file,
    mark_id = ext_mark_id,
    comment = comment,
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
  }

  table.insert(annotations, metadata)
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
    if input == nil or input == "" then
      return
    end

    add_annotation(
      positions[1][1][2],
      positions[1][1][3],
      positions[#positions][2][2],
      positions[#positions][2][3],
      " 💬 ",
      input
    )
  end)
end

---Prompt the user for a comment and attach it to the current line, without
---requiring a visual selection
---@return nil
function M.annotate_line()
  local line = vim.fn.line(".")
  local line_text = vim.api.nvim_get_current_line()
  local end_col = #line_text + 1

  vim.ui.input({ prompt = "Comment: " }, function(input)
    if input == nil or input == "" then
      return
    end

    add_annotation(line, 1, line, end_col, " 💬 ", input)
  end)
end

---Prompt the user for a comment and attach it to the entire current file
---@return nil
function M.annotate_file()
  local buf_id = vim.api.nvim_get_current_buf()
  local line_count = vim.api.nvim_buf_line_count(buf_id)
  local last_line = vim.api.nvim_buf_get_lines(buf_id, line_count - 1, line_count, false)[1] or ""
  local end_col = #last_line + 1

  vim.ui.input({ prompt = "Comment for entire file: " }, function(input)
    if input == nil or input == "" then
      return
    end

    add_annotation(1, 1, line_count, end_col, " 💬 File", input)
  end)
end

---Export annotations to the clipboard, a file, or stdout
---@param args string|nil Space-separated `target format` where target is
---"clipboard", "file", "file <path>", or omitted to use the default format
---@return nil
function M.export_annotations(args)
  local anns = M.get_annotations()
  if #anns == 0 then
    vim.notify("No annotations to export", vim.log.levels.WARN)
    return
  end

  local parts = vim.split(args or "", "%s+", { trimempty = true })
  local target = parts[1]

  if target == "file" then
    local path = parts[2] or ("annotations-" .. os.date("%Y%m%d-%H%M%S") .. ".md")
    local output = M.format_annotations(anns, M.config.export.default_format)
    local ok = pcall(vim.fn.writefile, vim.split(output, "\n"), path)
    if ok then
      vim.notify("Annotations saved to " .. path, vim.log.levels.INFO)
    else
      vim.notify("Failed to write " .. path, vim.log.levels.ERROR)
    end
    return
  end

  local format = (target and target ~= "clipboard") and target or M.config.export.default_format
  local output = M.format_annotations(anns, format)

  if target == "clipboard" or (target == nil and M.config.export.clipboard_on_export) then
    vim.fn.setreg("+", output)
    vim.notify("Annotations copied to clipboard", vim.log.levels.INFO)
  else
    print(output)
  end
end

---Copy annotations to the clipboard using the configured default format
---@return nil
function M.copy_annotations_to_clipboard()
  M.export_annotations("clipboard")
end

---@type integer|nil
local overview_buf
---@type integer|nil
local overview_win

---Show all annotations in a read-only floating window
---@return nil
function M.show_overview()
  local anns = M.get_annotations()
  if #anns == 0 then
    vim.notify("No annotations to show", vim.log.levels.WARN)
    return
  end

  if overview_win and vim.api.nvim_win_is_valid(overview_win) then
    vim.api.nvim_set_current_win(overview_win)
    return
  end

  local lines = vim.split(M.format_annotations(anns, "markdown"), "\n")

  overview_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(overview_buf, 0, -1, false, lines)
  vim.bo[overview_buf].modifiable = false
  vim.bo[overview_buf].filetype = "markdown"

  local cfg = M.config.ui.overview
  local width = math.min(vim.o.columns - 4, cfg.width)
  local height = math.min(#lines, cfg.height)

  overview_win = vim.api.nvim_open_win(overview_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = cfg.border,
  })

  local close = function()
    if overview_win and vim.api.nvim_win_is_valid(overview_win) then
      vim.api.nvim_win_close(overview_win, true)
    end
  end
  vim.keymap.set("n", "q", close, { buffer = overview_buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = overview_buf, nowait = true, silent = true })
end

return M
