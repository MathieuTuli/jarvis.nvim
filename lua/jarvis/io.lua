local _G = {}

-- PLUGIN SETUP
_G.root = vim.fn.stdpath('data') .. "/jarvis/"
if vim.fn.isdirectory(_G.root) == 0 then
    vim.fn.mkdir(_G.root, "p")
end
_G.config_path = _G.root .. "config.lua"

function _G.read_config()
    local config = {}
    local file = io.open(_G.config_path, "r")
    if file then
        local content = file:read("*a")
        config = loadstring(content)()
        file:close()
    end
    return config
end

function _G.write_config(config)
    local file = io.open(_G.config_path, "w")
    if file then
        file:write("return " .. vim.inspect(config))
        file:close()
    end
end

function _G.get_stored_chat_filename()
    local config = read_config()
    return config.last_chat_filename
end

function _G.update_stored_chat_filename(new_filename)
    local config = read_config()
    config.last_chat_filename = new_filename
    write_config(config)
end

function _G.file_exists(path)
    return vim.fn.filereadable(path) == 1
end

function _G.create_new_chat()
    local date_time = os.date("%Y-%m-%d_%H-%M-%S")
    local filename = date_time .. ".md"

    --  vim.fn.expand("~/.local/share/nvim/jarvis/chats/")
    local dir = _G.root .. "/chats/"
    if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
    end
    local full_path = dir .. filename
    if vim.fn.filereadable(full_path) == 0 then
        local file = io.open(full_path, "w")
        if file then
            file:close()
        end
    end
    vim.cmd("badd " .. full_path)
    return filename
end

function _G.get_prompt_history(session_timestamp, bufnr)
    assert(session_timestamp ~= nil)
    local dir = string.format("%s/prompts/%s/", _G.root, session_timestamp)
    if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
    end
    local full_path = dir .. bufnr .. ".md"
    if vim.fn.filereadable(full_path) == 0 then
        local file = io.open(full_path, "w")
        if file then
            file:close()
        end
    end
    vim.cmd("badd " .. full_path)
    return full_path
end

return _G
