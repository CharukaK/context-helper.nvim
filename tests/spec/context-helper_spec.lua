local plugin = require("context-helper")

describe("context-helper", function()
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
end)
