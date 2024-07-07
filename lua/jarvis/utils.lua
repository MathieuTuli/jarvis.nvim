local _G = {}

function _G.stream_to_buffer_at_cursor(winid, content)
    local cursor_position = vim.api.nvim_win_get_cursor(winid)
    local row, col = cursor_position[1], cursor_position[2]

    local lines = vim.split(content, '\n')
    vim.api.nvim_put(lines, 'c', true, true)

    local num_lines = #lines
    local last_line_length = #lines[num_lines]
    vim.api.nvim_win_set_cursor(winid, { row + num_lines - 1, col + last_line_length })
end

function _G.stream_to_buffer(bufnr, content)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        error("Invalid buffer number: " .. bufnr)
        return { first = nil, last = nil }
    end
    if type(content) == "string" then
        content = vim.split(content, '\n')
    end
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    -- TODO : this is dangerous af idk
    --      : as long as my shit is always > 1 lines
    if line_count == 1 then
        line_count = 0
    end
    vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, content)
    return {
        first = line_count,
        last = vim.api.nvim_buf_line_count(bufnr)
    }
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
                vim.api.nvim_buf_get_text(bufnr, i - 1, math.min(scol - 1, ecol), i - 1, math.max(scol - 1, ecol), {})
                [1])
        end
        return lines
    end
    return nil
end

function _G.copy_to_clipboard(content)
    if content then
        if type(content) == "table" then
            content = table.concat(content, "\n")
        end
        vim.fn.setreg('+', content)
    end
end

function _G.clear_changes(winid)
    local current_win = vim.api.nvim_get_current_win()
    local current_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_win(winid)
    vim.cmd('edit!')
    vim.api.nvim_set_current_win(current_win)
    vim.api.nvim_set_current_buf(current_buf)
end

function _G.clear_buffer(bufnr)
    local first = 0
    local last = vim.api.nvim_buf_line_count(bufnr)
    if bufnr ~= nil then
        vim.api.nvim_buf_set_lines(bufnr, first, last, false, {})
    end
end

function _G.save_buffer(bufnr)
    local current_bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_command('write')
    vim.api.nvim_set_current_buf(current_bufnr)
end

function _G.move_cursor_to_bottom(winid, bufnr)
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    vim.api.nvim_win_set_cursor(winid, { line_count, 0 })
end

return _G
