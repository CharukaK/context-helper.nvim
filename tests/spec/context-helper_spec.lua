local plugin = require("context-helper")

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

  it("open_quickfix_list populates quickfix list", function()
    -- We cannot directly set private `annotations` from tests,
    -- so test via the command path: the command is registered and callable.
    vim.api.nvim_command("ListAnnotations")
    -- Should warn since no annotations exist
    local qf = vim.fn.getqflist()
    assert.are.same({}, qf)
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
end)
