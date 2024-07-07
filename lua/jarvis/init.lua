print("Loading Jarvis")
local _G = {}
local _L = {}
local Utils = require("jarvis.utils")
local IO = require("jarvis.io")
local LLM = require("jarvis.llm")
local Layout = require("nui.layout")
local Popup = require("nui.popup")
local Job = require('plenary.job')
local Input = require("nui.input")
local event = require("nui.utils.autocmd").event

_L.history_bufnr = nil
_L.history_winid = nil
_L.session_type = nil
_L.session_timestamp = nil

function _G.setup()
    if _L.session_timestamp == nil then
        _L.session_timestamp = os.date("%Y-%m-%d %H:%M:%S")
    end
    print(_L.session_timestamp)
end

-- TODO : don't close buffer for optimization
-- TODO : bug where if you open prompt session, prompt, the :q from history, the next interaction is cleared (duh)
--      : to fix, only clear the latest text added to the buffer, not the whole buffer
function _L.clear_history()
    if _L.history_bufnr ~= nil and _L.session_type == "prompt" then
        local line_count = vim.api.nvim_buf_line_count(_L.history_bufnr)
        vim.api.nvim_buf_set_lines(_L.history_bufnr, 0, line_count, false, {})
    end
end

function _L.close()
    _L.clear_history()
    vim.api.nvim_buf_delete(_L.history_bufnr, { force = true })
    _L.layout:unmount()
end

function _L.get_current_interaction(type)
    local fname = nil
    _L.session_type = type
    if type == "chat" then
        print("Chatting...")
        if IO.file_exists(IO.config_path) then
            fname = _L.get_stored_chat_filename()
        else
            fname = IO.create_new_chat()
        end
        _L.history_bufnr = vim.fn.bufnr(fname)
    elseif type == "prompt" then
        print("Asking...")
        fname = IO.get_prompt_history(_L.session_timestamp, _L.parent_bufnr)
        _L.history_bufnr = vim.fn.bufnr(fname)
    else
        error("Unknown interaction type")
        return nil
    end
    return _L.history_bufnr
end

function _L.save_buffer(bufnr)
    local current_bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_command('write')
    vim.api.nvim_set_current_buf(current_bufnr)
end

function _L.forward(history_bufnr, prompt_bufnr)
    local response = LLM.forward(history_bufnr, prompt_bufnr)
    Utils.stream_table_to_buffer(history_bufnr, response)
    _L.save_buffer(history_bufnr)
    _L.refresh_display()
end

function _L.refresh_display()
    local line_count = vim.api.nvim_buf_line_count(_L.history_bufnr)
    vim.api.nvim_win_set_cursor(_L.history_winid, {line_count, 0})
end

function _G.interact(type)
    _L.parent_bufnr = vim.api.nvim_get_current_buf()
    _L.parent_window = vim.api.nvim_get_current_win()
    _L.parent_visual_selection = Utils.get_visual_selection(_L.parent_bufnr)
    local curr_history_bufnr = _L.get_current_interaction(type)
    local history = Popup({
        border = {
            style = "rounded",
            padding = { 0, 0 },
            text = {
                top = "/History/",
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
    local prompt = Popup({
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
                width = "70%",
                height = "80%",
            },
        },
        Layout.Box({
            Layout.Box(history, { size = "90%" }),
            Layout.Box(prompt, { size = "10%" }),
        }, { dir = "col" })
    )

    _L.layout:mount()
    _L.history_winid = history.winid
    _L.refresh_display()
    if type == "prompt" then
        if _L.parent_visual_selection ~= nil then
            Utils.stream_table_to_buffer(_L.history_bufnr, _L.parent_visual_selection)
        else
            Utils.stream_text_to_buffer(_L.history_bufnr, Utils.get_lines_until_cursor(_L.parent_window, _L.parent_bufnr))
        end
    end
    -- unmount component when cursor leaves buffer BufWinLeav BufHidden
    history:on(event.BufHidden, function()
        _L.clear_history()
    end)

    -- PROMPT COMMANDS
    prompt:map("n", "<esc>", function(bufnr)
        print("ESC pressed in Normal mode!")
        _L.close()
    end, { noremap = true })

    prompt:map("n", "<C-s>", function(bufnr)
        vim.api.nvim_set_current_win(history.winid)
    end, { noremap = true })
    prompt:map("i", "<C-s>", function(bufnr)
        vim.api.nvim_set_current_win(history.winid)
    end, { noremap = true })

    prompt:map("n", "<C-x>", function(bufnr)
        print("Prompting LLM")
        -- 1. prompt LLM
        --      1. either use chat history + up to cursor
        --      2. either have selected text from orginal buffer
        --          a. if this, create new chat? i.e. clear old buffer
        --      3. either have selected text from buffer in chat history
        -- 2. clear popup buffer
        -- 3. append stream to buffer of chat
        -- 4. if <C-y> - paste latest stream to original buffer
        _L.forward(_L.history_bufnr, prompt.bufnr)
        vim.api.nvim_set_current_win(history.winid)
        -- layout:unmount()
    end, { noremap = true })
    prompt:map("v", "<C-x>", function(bufnr)
        print("Prompting LLM")
        _L.forward(_L.history_bufnr, prompt.bufnr)
        vim.api.nvim_set_current_win(history.winid)
        -- layout:unmount()
    end, { noremap = true })
    prompt:map("i", "<C-x>", function(bufnr)
        print("Prompting LLM")
        _L.forward(_L.history_bufnr, prompt.bufnr)
        vim.api.nvim_set_current_win(history.winid)
        -- layout:unmount()
    end, { noremap = true })

    prompt:map("n", "<C-y>", function(bufnr)
        print("Paste results LLM")
        _L.layout:unmount()
    end, { noremap = true })

    -- HISTORY COMMANDS
    -- chat:map("n", "<esc>", function(bufnr)
    --     print("ESC pressed in Normal mode!")
    --     layout:unmount()
    -- end, { noremap = true })
    history:map("n", "<C-s>", function(bufnr)
        vim.api.nvim_set_current_win(prompt.winid)
    end, { noremap = true })
    history:map("i", "<C-s>", function(bufnr)
        vim.api.nvim_set_current_win(prompt.winid)
    end, { noremap = true })

    history:map("v", "<C-y>", function(bufnr)
        print("Paste results LLM")
        _L.layout:unmount()
    end, { noremap = true })
end

return _G
