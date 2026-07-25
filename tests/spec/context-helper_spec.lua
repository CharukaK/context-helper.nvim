local plugin = require("context-helper")

---Create and switch to a named, listed buffer with the given lines
---@param lines string[]|nil
---@return integer buf_id
local function open_buffer(lines)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or { "line 1", "line 2", "line 3" })
  vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. ".lua")
  vim.api.nvim_set_current_buf(buf)
  return buf
end

---Temporarily replace vim.ui.input to answer with a fixed value
---@param answer string|nil
---@return fun(opts: table, on_confirm: fun(input: string|nil)) original vim.ui.input
local function stub_input(answer)
  local orig = vim.ui.input
  vim.ui.input = function(_, on_confirm)
    on_confirm(answer)
  end
  return orig
end

---Temporarily replace vim.notify to record calls instead of printing
---@return fun(msg: string, level: integer|nil) original vim.notify
---@return {msg: string, level: integer|nil}[] calls
local function stub_notify()
  local calls = {}
  local orig = vim.notify
  vim.notify = function(msg, level)
    table.insert(calls, { msg = msg, level = level })
  end
  return orig, calls
end

describe("context-helper", function()
  before_each(function()
    plugin.reset()
    plugin.setup({})
  end)

  it("can be required", function()
    assert.is_not_nil(plugin)
  end)

  it("has a setup function", function()
    assert.is_function(plugin.setup)
  end)

  it("setup merges config", function()
    plugin.setup({ foo = "bar" })
    assert.equal("bar", plugin.config.foo)
  end)

  it("has a get_annotations function", function()
    assert.is_function(plugin.get_annotations)
  end)

  it("get_annotations returns an empty table initially", function()
    assert.are.same({}, plugin.get_annotations())
  end)

  it("get_annotations returns a copy, not a reference", function()
    local result = plugin.get_annotations()
    result.test = true
    assert.are.same({}, plugin.get_annotations())
  end)

  it("setup registers the OpenSession command", function()
    local commands = vim.api.nvim_get_commands({})
    assert.is_not_nil(commands["OpenSession"])
  end)

  it("has a format_annotations function", function()
    assert.is_function(plugin.format_annotations)
  end)

  it("has a format_position function", function()
    assert.is_function(plugin.format_position)
  end)

  it("format_position returns empty for annotations without position", function()
    assert.equals("", plugin.format_position({}))
  end)

  it("format_position shows single line when start == end", function()
    local result = plugin.format_position({ start_row = 10, end_row = 10 })
    assert.equals("10", result)
  end)

  it("format_position shows range when start != end", function()
    local result = plugin.format_position({ start_row = 3, end_row = 7 })
    assert.equals("3-7", result)
  end)

  it("format_annotations produces markdown by default", function()
    local anns = {
      { file = "/a.lua", comment = "fix this" },
      { file = "/a.lua", comment = "and this" },
    }
    local result = plugin.format_annotations(anns)
    assert.match("# Annotations", result)
    assert.match("## /a.lua", result)
    assert.match("- fix this", result)
    assert.match("- and this", result)
  end)

  it("format_annotations includes position in markdown when available", function()
    local anns = {
      { file = "/a.lua", comment = "fix this", start_row = 10, end_row = 15 },
    }
    local result = plugin.format_annotations(anns, "markdown")
    assert.match("- Lines 10%-15: fix this", result)
  end)

  it("format_annotations produces structured text format", function()
    local anns = {
      { file = "/a.lua", comment = "fix this", start_row = 10, end_row = 15 },
    }
    local result = plugin.format_annotations(anns, "text")
    assert.match("/a.lua\n  %[10%-15%] fix this", result)
  end)

  it("format_annotations handles annotations without position in text format", function()
    local anns = {
      { file = "/a.lua", comment = "fix this" },
    }
    local result = plugin.format_annotations(anns, "text")
    assert.match("/a.lua\n  fix this", result)
  end)

  it("format_annotations produces json format", function()
    local anns = {
      { file = "/a.lua", comment = "fix this" },
    }
    local result = plugin.format_annotations(anns, "json")
    local decoded = vim.json.decode(result)
    assert.are.same(anns, decoded)
  end)

  it("format_annotations groups by file with position", function()
    local anns = {
      { file = "/a.lua", comment = "a1", start_row = 1, end_row = 3 },
      { file = "/b.lua", comment = "b1", start_row = 5, end_row = 5 },
      { file = "/a.lua", comment = "a2", start_row = 10, end_row = 12 },
    }
    local result = plugin.format_annotations(anns, "text")
    assert.match("/a.lua\n  %[1%-3%] a1\n  %[10%-12%] a2\n\n/b.lua\n  %[5%] b1", result)
  end)

  it("setup registers the ListAnnotations command", function()
    local commands = vim.api.nvim_get_commands({})
    assert.is_not_nil(commands["ListAnnotations"])
  end)

  it("has an open_quickfix_list function", function()
    assert.is_function(plugin.open_quickfix_list)
  end)

  it("open_quickfix_list warns when no annotations exist", function()
    local notified = false
    local orig_notify = vim.notify
    vim.notify = function(msg, level)
      if level == vim.log.levels.WARN then
        notified = true
      end
    end
    plugin.open_quickfix_list()
    vim.notify = orig_notify
    assert.is_true(notified)
  end)

  it("calls on_open_session callback with annotations", function()
    local called = false
    local result = nil
    plugin.setup({
      on_open_session = function(ann)
        called = true
        result = ann
      end,
    })
    plugin.config.on_open_session({ { file = "test.lua", comment = "hello" } })
    assert.is_true(called)
    assert.are.same({ { file = "test.lua", comment = "hello" } }, result)
  end)

  describe("input methods", function()
    it("has an annotate_line function", function()
      assert.is_function(plugin.annotate_line)
    end)

    it("has an annotate_file function", function()
      assert.is_function(plugin.annotate_file)
    end)

    it("annotate_line rejects a nil comment (Esc)", function()
      open_buffer()
      local orig = stub_input(nil)
      plugin.annotate_line()
      vim.ui.input = orig
      assert.are.same({}, plugin.get_annotations())
    end)

    it("annotate_line rejects an empty comment", function()
      open_buffer()
      local orig = stub_input("")
      plugin.annotate_line()
      vim.ui.input = orig
      assert.are.same({}, plugin.get_annotations())
    end)

    it("annotate_file rejects an empty comment", function()
      open_buffer()
      local orig = stub_input("")
      plugin.annotate_file()
      vim.ui.input = orig
      assert.are.same({}, plugin.get_annotations())
    end)

    it("annotate_line adds an annotation for the current line without a visual selection", function()
      open_buffer({ "one", "two", "three" })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      local orig = stub_input("second line")
      plugin.annotate_line()
      vim.ui.input = orig

      local anns = plugin.get_annotations()
      assert.equals(1, #anns)
      assert.equals("second line", anns[1].comment)
      assert.equals(2, anns[1].start_row)
      assert.equals(2, anns[1].end_row)
    end)

    it("annotate_file adds an annotation spanning the whole file", function()
      open_buffer({ "one", "two", "three" })
      local orig = stub_input("whole file comment")
      plugin.annotate_file()
      vim.ui.input = orig

      local anns = plugin.get_annotations()
      assert.equals(1, #anns)
      assert.equals(1, anns[1].start_row)
      assert.equals(3, anns[1].end_row)
    end)

    it("warns and does not annotate an unnamed buffer", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(buf)
      local orig_notify, calls = stub_notify()
      local orig_input = stub_input("a comment")
      plugin.annotate_line()
      vim.ui.input = orig_input
      vim.notify = orig_notify

      assert.are.same({}, plugin.get_annotations())
      assert.is_true(#calls > 0)
    end)

    it("open_quickfix_list populates quickfix list once annotations exist", function()
      open_buffer({ "one", "two" })
      local orig = stub_input("fix this")
      plugin.annotate_line()
      vim.ui.input = orig

      plugin.open_quickfix_list()
      local qf = vim.fn.getqflist()
      assert.equals(1, #qf)
      assert.equals("fix this", qf[1].text)
    end)
  end)

  describe("export_annotations", function()
    before_each(function()
      open_buffer({ "one", "two" })
      local orig = stub_input("exported comment")
      plugin.annotate_line()
      vim.ui.input = orig
    end)

    it("warns and does nothing when there are no annotations", function()
      plugin.reset()
      local orig_notify, calls = stub_notify()
      plugin.export_annotations(nil)
      vim.notify = orig_notify
      assert.is_true(#calls > 0)
    end)

    it("copies to clipboard when target is 'clipboard'", function()
      local orig_setreg = vim.fn.setreg
      local reg_calls = {}
      vim.fn.setreg = function(reg, val)
        table.insert(reg_calls, { reg = reg, val = val })
      end
      plugin.export_annotations("clipboard")
      vim.fn.setreg = orig_setreg

      assert.equals(1, #reg_calls)
      assert.equals("+", reg_calls[1].reg)
      assert.match("exported comment", reg_calls[1].val)
    end)

    it("writing to a file never also copies to clipboard", function()
      plugin.setup({ export = { clipboard_on_export = true } })
      local orig_setreg = vim.fn.setreg
      local setreg_called = false
      vim.fn.setreg = function()
        setreg_called = true
      end
      local orig_writefile = vim.fn.writefile
      local written_path = nil
      vim.fn.writefile = function(_, path)
        written_path = path
        return 0
      end

      plugin.export_annotations("file /tmp/context-helper-test-export.md")

      vim.fn.setreg = orig_setreg
      vim.fn.writefile = orig_writefile

      assert.is_false(setreg_called)
      assert.equals("/tmp/context-helper-test-export.md", written_path)
    end)

    it("bare export respects clipboard_on_export = true", function()
      plugin.setup({ export = { clipboard_on_export = true } })
      local orig_setreg = vim.fn.setreg
      local setreg_called = false
      vim.fn.setreg = function()
        setreg_called = true
      end
      plugin.export_annotations(nil)
      vim.fn.setreg = orig_setreg
      assert.is_true(setreg_called)
    end)

    it("bare export respects clipboard_on_export = false", function()
      plugin.setup({ export = { clipboard_on_export = false } })
      local orig_setreg = vim.fn.setreg
      local setreg_called = false
      vim.fn.setreg = function()
        setreg_called = true
      end
      plugin.export_annotations(nil)
      vim.fn.setreg = orig_setreg
      assert.is_false(setreg_called)
    end)

    it("copy_annotations_to_clipboard always copies regardless of config", function()
      plugin.setup({ export = { clipboard_on_export = false } })
      local orig_setreg = vim.fn.setreg
      local setreg_called = false
      vim.fn.setreg = function()
        setreg_called = true
      end
      plugin.copy_annotations_to_clipboard()
      vim.fn.setreg = orig_setreg
      assert.is_true(setreg_called)
    end)
  end)

  describe("show_overview", function()
    it("warns and does not open a window when there are no annotations", function()
      local orig_notify, calls = stub_notify()
      plugin.show_overview()
      vim.notify = orig_notify
      assert.is_true(#calls > 0)
    end)

    it("opens a read-only floating window with q/<Esc> close keymaps", function()
      open_buffer()
      local orig = stub_input("overview comment")
      plugin.annotate_line()
      vim.ui.input = orig

      plugin.show_overview()
      local win = vim.api.nvim_get_current_win()
      local buf = vim.api.nvim_win_get_buf(win)

      assert.is_false(vim.bo[buf].modifiable)
      local keymaps = vim.api.nvim_buf_get_keymap(buf, "n")
      local keys = {}
      for _, km in ipairs(keymaps) do
        keys[km.lhs] = true
      end
      assert.is_true(keys["q"] ~= nil)

      vim.api.nvim_win_close(win, true)
    end)

    it("re-focuses an existing overview window instead of opening a duplicate", function()
      open_buffer()
      local orig = stub_input("overview comment")
      plugin.annotate_line()
      vim.ui.input = orig

      plugin.show_overview()
      local first_win = vim.api.nvim_get_current_win()
      local wins_before = #vim.api.nvim_list_wins()

      plugin.show_overview()
      local second_win = vim.api.nvim_get_current_win()

      assert.equals(first_win, second_win)
      assert.equals(wins_before, #vim.api.nvim_list_wins())

      vim.api.nvim_win_close(first_win, true)
    end)
  end)

  describe("reset confirmation", function()
    it("plugin.reset() never prompts", function()
      local orig_confirm = vim.fn.confirm
      local confirm_called = false
      vim.fn.confirm = function()
        confirm_called = true
        return 1
      end
      plugin.reset()
      vim.fn.confirm = orig_confirm
      assert.is_false(confirm_called)
    end)

    it("confirm_reset skips the prompt and resets when there are no annotations", function()
      local orig_confirm = vim.fn.confirm
      local confirm_called = false
      vim.fn.confirm = function()
        confirm_called = true
        return 1
      end
      plugin.confirm_reset(false)
      vim.fn.confirm = orig_confirm
      assert.is_false(confirm_called)
    end)

    it("confirm_reset(true) (bang) skips the prompt", function()
      open_buffer()
      local orig = stub_input("to be wiped")
      plugin.annotate_line()
      vim.ui.input = orig

      local orig_confirm = vim.fn.confirm
      local confirm_called = false
      vim.fn.confirm = function()
        confirm_called = true
        return 1
      end
      plugin.confirm_reset(true)
      vim.fn.confirm = orig_confirm

      assert.is_false(confirm_called)
      assert.are.same({}, plugin.get_annotations())
    end)

    it("confirm_reset(false) prompts and clears on Yes", function()
      open_buffer()
      local orig = stub_input("to be wiped")
      plugin.annotate_line()
      vim.ui.input = orig

      local orig_confirm = vim.fn.confirm
      vim.fn.confirm = function()
        return 1
      end
      plugin.confirm_reset(false)
      vim.fn.confirm = orig_confirm

      assert.are.same({}, plugin.get_annotations())
    end)

    it("confirm_reset(false) prompts and keeps annotations on No", function()
      open_buffer()
      local orig = stub_input("kept")
      plugin.annotate_line()
      vim.ui.input = orig

      local orig_confirm = vim.fn.confirm
      vim.fn.confirm = function()
        return 2
      end
      plugin.confirm_reset(false)
      vim.fn.confirm = orig_confirm

      assert.equals(1, #plugin.get_annotations())
      plugin.reset()
    end)
  end)

  describe("config merge", function()
    it("setup merges export config", function()
      plugin.setup({ export = { default_format = "json", clipboard_on_export = false } })
      assert.equals("json", plugin.config.export.default_format)
      assert.is_false(plugin.config.export.clipboard_on_export)
    end)

    it("setup merges ui config", function()
      plugin.setup({ ui = { overview = { height = 20 } } })
      assert.equals(20, plugin.config.ui.overview.height)
    end)
  end)

  describe("command registration", function()
    it("registers all commands", function()
      local commands = vim.api.nvim_get_commands({})
      assert.is_not_nil(commands["AnnotateLine"])
      assert.is_not_nil(commands["AnnotateFile"])
      assert.is_not_nil(commands["ExportAnnotations"])
      assert.is_not_nil(commands["CopyAnnotations"])
      assert.is_not_nil(commands["ShowAnnotations"])
      assert.is_not_nil(commands["ResetAnnotations"])
      assert.is_not_nil(commands["NewAnnotationSession"])
    end)
  end)
end)
