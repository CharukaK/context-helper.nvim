local M = {}

M.config = {
	-- default configuration options
}

---Setup function to initialize the plugin
---@param opts table|nil Optional configuration overrides
function M.setup(opts)
	local annotations = {}
	local ns = vim.api.nvim_create_namespace("context-helper")

	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	M.new_session = function()
		annotations = {}
	end

	M.reset = function()
		annotations = {}
	end

	M.prompt_for_comment = function()
		local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
		vim.api.nvim_feedkeys(esc, "x", false)
		local start_pos = vim.fn.getpos("'<")
		local end_pos = vim.fn.getpos("'>")

		vim.ui.input({
			prompt = "Comment: ",
		}, function(input)
			if input == nil then
				return
			end

			local metadata = {
				file = vim.api.nvim_buf_get_name(0),
				start_line = start_pos[2],
				start_col = start_pos[3],
				end_line = end_pos[2],
				end_col = end_pos[3],
				comment = input,
			}

			table.insert(annotations, metadata)

			vim.api.nvim_buf_set_extmark(0, ns, metadata.start_line - 1, metadata.start_col - 1, {
				virt_text = {
					{ " 💬 ", "Comment" },
				},
			})

			vim.notify(
				start_pos[1] .. "  " .. start_pos[2] .. "  " .. start_pos[3] .. "  " .. start_pos[3] .. " " .. input,
				0,
				{}
			)
		end)
	end

	vim.api.nvim_create_user_command("NewAnnotationSession", M.new_session, {})
	vim.api.nvim_create_user_command("AddAnnotation", M.prompt_for_comment, {})
	vim.api.nvim_create_user_command("ResetAnnotations", M.prompt_for_comment, {})
end

return M
