local Path = require('plenary.path')

local Scandir = require('plenary.scandir')
local _G = {}

-- SETUP
_G.prune_after = 30
_G.cache_limit = 1000
_G.root = vim.fn.stdpath('data') .. "/jarvis/"
if vim.fn.isdirectory(_G.root) == 0 then
    vim.fn.mkdir(_G.root, "p")
end
_G.config_path = _G.root .. "config.lua"
-- DONE

function _G.read_config()
    local config = {}
    local file = io.open(_G.config_path, "r")
    if file then
        local content = file:read("*a")
        config = load(content)()
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
    if not _G.file_exists(_G.config_path) then
        return nil
    end
    local config = _G.read_config()
    return config.last_chat_filename
end

function _G.update_stored_chat_filename(new_filename)
    local config = _G.read_config()
    config.last_chat_filename = new_filename
    _G.write_config(config)
end

function _G.file_exists(path)
    return vim.fn.filereadable(path) == 1
end

function _G.new_chat_filename()
    local date_time = os.date("%Y-%m-%d_%H-%M-%S")
    local filename = date_time .. ".md"

    --  vim.fn.expand("~/.local/share/nvim/jarvis/chats/")
    local dir = _G.root .. "/chats/"
    _G.count_files_and_cleanup({ _G.root .. "/chats/", _G.root .. "/prompts/" })
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
    _G.update_stored_chat_filename(full_path)
    return filename
end

function _G.get_prompt_history_filename(session_timestamp, bufnr)
    assert(session_timestamp ~= nil)
    _G.count_files_and_cleanup({ _G.root .. "/chats/", _G.root .. "/prompts/" })
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
    -- vim.cmd("badd " .. full_path)
    return full_path
end

function _G.count_files_and_cleanup(directories)
    local function get_file_age(file)
        local mtime = file:_stat().mtime -- modified time
        return os.difftime(os.time(), mtime.sec) / (24 * 60 * 60)
    end

    local files = {}
    local function gather_files(dir)
        local entries = Scandir.scan_dir(dir, { hidden = false, add_dirs = true, depth = 1 })
        for _, entry in ipairs(entries) do
            entry = Path:new(entry)
            if entry:is_file() then
                table.insert(files, entry)
            elseif entry:is_dir() then
                gather_files(entry:absolute())
            end
        end
    end

    for _, dir in ipairs(directories) do
        gather_files(dir)
    end

    table.sort(files, function(a, b) return get_file_age(a) > get_file_age(b) end)

    for i = #files, 1, -1 do
        if get_file_age(files[i]) > _G.prune_after or #files > _G.cache_limit then
            files[i]:rm()
            table.remove(files, i)
        end
    end

    local function prune_empty_dirs(dir)
        local entries = Scandir.scan_dir(dir, { hidden = false, add_dirs = true, depth = 1 })
        for i = #entries, 1, -1 do
            local entry = Path:new(entries[i])
            if entry:is_dir() then
                prune_empty_dirs(entry:absolute())
                local ret = Scandir.scan_dir(entry:absolute(), { hidden = true, add_dirs = true })
                if #ret == 0 then
                    entry:rm( { recursive=true } )
                end
            end
        end
    end

    for _, dir in ipairs(directories) do
        prune_empty_dirs(dir)
    end
end

return _G
