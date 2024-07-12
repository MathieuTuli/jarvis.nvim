local _G = {}
local _L = {}
local Utils = require("jarvis.utils")
local IO = require("jarvis.io")
local LLM = require("jarvis.llm")
local Layout = require("nui.layout")
local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

_L.history_lines_to_clear = { first = nil, last = nil }

function _G.setup(opts)
    if IO.session_timestamp == nil then
        IO.session_timestamp = os.date("%Y-%m-%d %H:%M:%S")
    end
    -- TODO this doesn't do anything right now
    if opts.cache_limit then IO.cache_limit = opts.cache_limit end
    if opts.prune_after then IO.prune_after = opts.prune_after end
    if opts.persistent_prompt_history then IO.persistent_prompt_history = opts.persistent_prompt_history end
    if opts.data_handler then LLM.data_handler = opts.data_handler end
    if opts.make_curl_args then LLM.make_curl_args = opts.make_curl_args end
    assert(type(IO.cache_limit) == "number", "cache_limit must be a number")
    assert(type(IO.prune_after) == "number", "prune_after must be a number")
    assert(type(opts.data_handler) == "function", "data_handler must be a function")
    assert(type(opts.make_curl_args) == "function", "make_curl_args must be a function")
end

function _L.close()
    Utils.clear_changes(_L.history_popup.winid)
    vim.api.nvim_buf_delete(_L.history_popup.bufnr, { force = true })
    _L.history_popup.bufnr = nil
    _L.layout:unmount()
end

function _L.open_history_buffer(fname)
    vim.cmd("badd " .. fname)
    local new_bufnr = vim.fn.bufnr(fname)
    -- Depending on when this gets executed, this may not be open yet
    if _L.history_popup ~= nil and _L.history_popup.winid ~= nil then
        _L.history_popup.bufnr = new_bufnr
        vim.api.nvim_win_set_buf(_L.history_popup.winid, new_bufnr)
    end
    return new_bufnr
end

function _L.get_current_interaction(type)
    local fname = nil
    if type == "chat" then
        fname = IO.get_stored_chat_filename()
        print(fname)
        if fname == nil then
            fname = IO.new_chat_filename()
        end
        -- _L.history_popup.bufnr = vim.fn.bufnr(fname)
    elseif type == "prompt" then
        fname = IO.get_prompt_history_filename(_L.parent_bufnr)
    else
        return nil
    end
    return _L.open_history_buffer(fname)
end

function _L.forward()
    LLM.get_response_and_stream_to_buffer(
        _L.history_popup.winid, _L.history_popup.bufnr,
        _L.prompt_popup.winid, _L.prompt_popup.bufnr)
    _L.history_lines_to_clear.first = nil
    _L.history_lines_to_clear.last = nil
end

function _G.interact(type)
    _L.parent_bufnr = vim.api.nvim_get_current_buf()
    _L.parent_window = vim.api.nvim_get_current_win()
    _L.history_lines_to_clear.first = nil
    _L.history_lines_to_clear.last = nil
    _L.parent_visual_selection = Utils.get_visual_selection(_L.parent_bufnr)
    local curr_history_bufnr = _L.get_current_interaction(type)

    local fname = Utils.get_buffer_fname(_L.parent_bufnr)

    _L.history_popup = Popup({
        border = {
            style = "rounded",
            padding = { 0, 0 },
            text = {
                top = type == "chat" and "/Chat History/" or "/../" .. fname .. " History/",
                top_align = "center",
            },
        },
        -- PASS THE BUFNR OF THE MD FILE CURRENTLY LOADED
        bufnr = curr_history_bufnr, -- vim.api.nvim_get_current_buf(),
        focusable = true,
        buf_options = {
            modifiable = true,
            readonly = false,
        },
        win_options = {
            winhighlight = "Normal:Normal,FloatBorder:Normal",
        },
    })
    vim.bo[curr_history_bufnr].filetype = "markdown"
    _L.prompt_popup = Popup({
        enter = true,
        focusable = true,
        border = {
            style = "rounded",
            padding = { 0, 0 },
            text = {
                top = "/Prompt/",
                top_align = "center",
            },
        },
        buf_options = {
            modifiable = true,
            readonly = false,
        },
        win_options = {
            winhighlight = "Normal:Normal,FloatBorder:Normal",
        },
    })
    _L.layout = Layout(
        {
            position = "50%",
            relative = "editor",
            size = {
                width = "90%",
                height = "90%",
            },
        },
        Layout.Box({
            Layout.Box(_L.history_popup, { size = "90%" }),
            Layout.Box(_L.prompt_popup, { size = "10%" }),
        }, { dir = "col" })
    )

    _L.layout:mount()

    if _L.parent_visual_selection then
        local lines_altered = Utils.stream_to_buffer(_L.history_popup.bufnr, "\n# Context")
        _L.history_lines_to_clear.first = lines_altered.first
        lines_altered = Utils.stream_to_buffer(_L.history_popup.bufnr, _L.parent_visual_selection)
        _L.history_lines_to_clear.last = lines_altered.last
    elseif "your" == "mom" then
        Utils.stream_to_buffer(_L.history_popup.bufnr,
            Utils.get_lines_until_cursor(_L.parent_window, _L.parent_bufnr))
    end

    Utils.move_cursor_to_bottom(_L.history_popup.winid, _L.history_popup.bufnr)

    -- PROMPT COMMANDS
    _L.prompt_popup:map("n", "<esc>", function(bufnr) _L.close() end, { noremap = true })

    _L.prompt_popup:map("n", "<C-s>", function(bufnr) vim.api.nvim_set_current_win(_L.history_popup.winid) end,
        { noremap = true })
    _L.prompt_popup:map("i", "<C-s>", function(bufnr) vim.api.nvim_set_current_win(_L.history_popup.winid) end,
        { noremap = true })

    _L.history_popup:map("n", "<C-s>", function(bufnr) vim.api.nvim_set_current_win(_L.prompt_popup.winid) end,
        { noremap = true })
    _L.history_popup:map("i", "<C-s>", function(bufnr) vim.api.nvim_set_current_win(_L.prompt_popup.winid) end,
        { noremap = true })

    _L.prompt_popup:map("n", "<C-e>", function(bufnr) _L.forward() end, { noremap = true })
    _L.prompt_popup:map("v", "<C-e>", function(bufnr) _L.forward() end, { noremap = true })
    _L.prompt_popup:map("i", "<C-e>", function(bufnr) _L.forward() end, { noremap = true })

    _L.prompt_popup:map("n", "<C-n>", function(bufnr) _L.open_history_buffer(IO.new_chat_filename()) end,
        { noremap = true })

    -- _L.prompt_popup:map("n", "<C-y>", function(bufnr) _L.layout:unmount() end, { noremap = true })
    _L.history_popup:map("v", "<C-y>", function(bufnr)
        Utils.copy_to_clipboard(Utils.get_visual_selection(_L.history_popup.bufnr))
        _L.layout:unmount()
    end, { noremap = true })
    -- unmount component when cursor leaves buffer BufWinLeav BufHidden
    _L.history_popup:on(event.BufHidden, function()
        Utils.clear_changes(_L.history_popup.winid)
    end)
end

return _G
