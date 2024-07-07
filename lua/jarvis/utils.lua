local _G = {}

function _G.stream_table_to_buffer(bufnr, table)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        error("Invalid buffer number: " .. bufnr)
        return
    end
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    print("lc", line_count)
    vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, table)
end

function _G.stream_text_to_buffer(bufnr, text)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        error("Invalid buffer number: " .. bufnr)
        return
    end
    local lines = vim.split(text, '\n')
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, lines)
end

function _G.get_lines_until_cursor(window, bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        error("Invalid buffer number: " .. bufnr)
        return
    end
    local cursor_position = vim.api.nvim_win_get_cursor(window)
    local row = cursor_position[1]

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, row, true)

    return table.concat(lines, '\n')
end

function _G.get_visual_selection(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        error("Invalid buffer number: " .. bufnr)
        return
    end
    local _, srow, scol = unpack(vim.fn.getpos 'v')
    local _, erow, ecol = unpack(vim.fn.getpos '.')

    if vim.fn.mode() == 'V' then
        if srow > erow then
            return vim.api.nvim_buf_get_lines(bufnr, erow - 1, srow, true)
        else
            return vim.api.nvim_buf_get_lines(bufnr, srow - 1, erow, true)
        end
    end

    if vim.fn.mode() == 'v' then
        if srow < erow or (srow == erow and scol <= ecol) then
            return vim.api.nvim_buf_get_text(bufnr, srow - 1, scol - 1, erow - 1, ecol, {})
        else
            return vim.api.nvim_buf_get_text(bufnr, erow - 1, ecol - 1, srow - 1, scol, {})
        end
    end

    if vim.fn.mode() == '\22' then
        local lines = {}
        if srow > erow then
            srow, erow = erow, srow
        end
        if scol > ecol then
            scol, ecol = ecol, scol
        end
        for i = srow, erow do
            table.insert(lines,
            vim.api.nvim_buf_get_text(bufnr, i - 1, math.min(scol - 1, ecol), i - 1, math.max(scol - 1, ecol), {})[1])
        end
        return lines
    end
    return nil
end

return _G
