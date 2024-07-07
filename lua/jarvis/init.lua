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
_L.history_lines_to_clear = { first = nil, last = nil }

function _G.setup()
    if _L.session_timestamp == nil then
        _L.session_timestamp = os.date("%Y-%m-%d %H:%M:%S")
    end
end

-- TODO : don't close buffer for optimization?
-- ~~TODO : first line of copied visual block is empty - annoying me
--          : okay but I hacked a solution - check on that
-- TODO : cleanup name of prompt/history bufnr/winid?
-- TODO : cache cleanup
-- TODO : format the context/prompt/response shit (based on models? xml? json? md?)
-- TODO : actually fill the llm backend
-- ~~TODO : function to create a new chat
-- TODO : copy/paste/confirm response
-- TODO : look at the link for how to unmount and clean everything
function _L.clear_buffer(bufnr, bAll)
    local first, last = 0, 0
    if bAll then
        last = vim.api.nvim_buf_line_count(bufnr)
    elseif _L.history_lines_to_clear.first == nil or _L.history_lines_to_clear.last == nil then
        return
    end
    if (_L.history_bufnr ~= nil and _L.session_type == "prompt") then
        vim.api.nvim_buf_set_lines(bufnr, first, last, false, {})
    end
end

function _L.close()
    _L.clear_buffer(_L.history_bufnr, false)
    vim.api.nvim_buf_delete(_L.history_bufnr, { force = true })
    _L.history_bufnr = nil
    _L.layout:unmount()
end

function _L.open_history_buffer(fname)
    -- local fname = IO.new_chat_filename()
    vim.cmd("badd " .. fname)
    local new_bufnr = vim.fn.bufnr(fname)
    -- Depending on when this gets executed, this may not be open yet
    if _L.history_popup ~= nil and _L.history_popup.winid ~= nil then
        _L.history_popup.bufnr = new_bufnr
        vim.api.nvim_win_set_buf(_L.history_popup.winid, new_bufnr)
    end
    -- if _L.history_bufnr ~= nil then
    --     _L.clear_buffer(_L.history_bufnr, false)
    --     vim.api.nvim_buf_delete(_L.history_bufnr, { force = true })
    -- end
    _L.history_bufnr = new_bufnr
end

function _L.get_current_interaction(type)
    local fname = nil
    _L.session_type = type
    if type == "chat" then
        fname = IO.get_stored_chat_filename()
        print("stored", fname)
        if fname == nil then
            fname = IO.new_chat_filename()
            print("was nil so", fname)
        end
        -- _L.history_bufnr = vim.fn.bufnr(fname)
    elseif type == "prompt" then
        fname = IO.get_prompt_history_filename(_L.session_timestamp, _L.parent_bufnr)
        print("prompt", fname)
        -- _L.history_bufnr = vim.fn.bufnr(fname)
    else
        error("Unknown interaction type")
        return nil
    end
    print("final", fname)
    _L.open_history_buffer(fname)
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
    Utils.stream_to_buffer(history_bufnr, "\n# Response")
    Utils.stream_to_buffer(history_bufnr, response)
    _L.history_lines_to_clear.first = nil
    _L.history_lines_to_clear.last = nil
    _L.clear_buffer(prompt_bufnr, true)
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
    _L.history_popup = Popup({
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
    local prompt_popup = Popup({
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
            Layout.Box(_L.history_popup, { size = "90%" }),
            Layout.Box(prompt_popup, { size = "10%" }),
        }, { dir = "col" })
    )

    _L.layout:mount()
    _L.history_winid = _L.history_popup.winid
    _L.refresh_display()
    if type == "prompt" then
        if _L.parent_visual_selection ~= nil then
            local lines_altered = Utils.stream_to_buffer(_L.history_bufnr, "\n# Context")
            _L.history_lines_to_clear.first = lines_altered.first
            lines_altered = Utils.stream_to_buffer(_L.history_bufnr, _L.parent_visual_selection)
            _L.history_lines_to_clear.last = lines_altered.last
        elseif "your" == "mom" then
            Utils.stream_to_buffer(_L.history_bufnr, Utils.get_lines_until_cursor(_L.parent_window, _L.parent_bufnr))
        end
    end
    -- unmount component when cursor leaves buffer BufWinLeav BufHidden
    _L.history_popup:on(event.BufHidden, function()
        _L.clear_buffer(_L.history_bufnr, false)
    end)

    -- PROMPT COMMANDS
    prompt_popup:map("n", "<esc>", function(bufnr)
        _L.close()
    end, { noremap = true })

    prompt_popup:map("n", "<C-s>", function(bufnr)
        _L.vim.api.nvim_set_current_win(_L.history_popup.winid)
    end, { noremap = true })
    prompt_popup:map("i", "<C-s>", function(bufnr)
        vim.api.nvim_set_current_win(_L.history_popup.winid)
    end, { noremap = true })

    prompt_popup:map("n", "<C-x>", function(bufnr)
        -- 1. prompt LLM
        --      1. either use chat history + up to cursor
        --      2. either have selected text from orginal buffer
        --          a. if this, create new chat? i.e. clear old buffer
        --      3. either have selected text from buffer in chat history
        -- 2. clear popup buffer
        -- 3. append stream to buffer of chat
        -- 4. if <C-y> - paste latest stream to original buffer
        _L.forward(_L.history_bufnr, prompt_popup.bufnr)
        -- vim.api.nvim_set_current_win(_L.history_popup.winid)
        -- layout:unmount()
    end, { noremap = true })
    prompt_popup:map("v", "<C-x>", function(bufnr)
        _L.forward(_L.history_bufnr, prompt_popup.bufnr)
        -- vim.api.nvim_set_current_win(_L.history_popup.winid)
        -- layout:unmount()
    end, { noremap = true })
    prompt_popup:map("i", "<C-x>", function(bufnr)
        _L.forward(_L.history_bufnr, prompt_popup.bufnr)
        -- vim.api.nvim_set_current_win(_L.history_popup.winid)
        -- layout:unmount()
    end, { noremap = true })

    prompt_popup:map("n", "<C-y>", function(bufnr)
        _L.layout:unmount()
    end, { noremap = true })

    prompt_popup:map("n", "<C-n>", function(bufnr)
        _L.open_history_buffer(IO.new_chat_filename())
    end, { noremap = true })

    -- HISTORY COMMANDS
    -- chat:map("n", "<esc>", function(bufnr)
    --     layout:unmount()
    -- end, { noremap = true })
    _L.history_popup:map("n", "<C-s>", function(bufnr)
        vim.api.nvim_set_current_win(prompt_popup.winid)
    end, { noremap = true })
    _L.history_popup:map("i", "<C-s>", function(bufnr)
        vim.api.nvim_set_current_win(prompt_popup.winid)
    end, { noremap = true })

    _L.history_popup:map("v", "<C-y>", function(bufnr)
        _L.layout:unmount()
    end, { noremap = true })
end

return _G
