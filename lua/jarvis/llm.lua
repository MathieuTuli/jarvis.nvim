local _G = {}

function _G.forward(history_bufnr, prompt_bufnr)
    local history_lines = vim.api.nvim_buf_get_lines(history_bufnr, 0, -1, false)
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_bufnr, 0, -1, false)
    return prompt_lines
end

return _G
