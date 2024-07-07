local _G = {}
local Job = require("plenary.job")
local Utils = require("jarvis.utils")

local function get_api_key(name)
  return os.getenv(name)
end

function _G.make_openai_spec_curl_args(prompt, history)
  local url = "https://api.openai.com/v1/chat/completions"
  -- local api_key = opts.api_key_name and get_api_key(opts.api_key_name)
  local api_key = os.getenv("APIKEY")
  local data = {
    messages = { { role = 'system', content = history }, { role = 'user', content = prompt } },
    model = "gpt-4o",
    temperature = 0.7,
    stream = true,
  }
  local args = { '-N', '-X', 'POST', '-H', 'Content-Type: application/json', '-d', vim.json.encode(data) }
  if api_key then
    table.insert(args, '-H')
    table.insert(args, 'Authorization: Bearer ' .. api_key)
  end
  table.insert(args, url)
  return args
end

function _G.handle_openai_spec_data(winid, data_stream)
    if data_stream:match '"delta":' then
        local json = vim.json.decode(data_stream)
        if json.choices and json.choices[1] and json.choices[1].delta then
            local content = json.choices[1].delta.content
            if content then
                vim.schedule(function()
                    Utils.stream_to_buffer_at_cursor(winid, content)
                end)
            end
        end
    end
end

local active_job = nil
function _G.get_response_and_stream_to_buffer(history_winid, history_bufnr, prompt_winid, prompt_bufnr)
    local history_lines = vim.api.nvim_buf_get_lines(history_bufnr, 0, -1, false)
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_bufnr, 0, -1, false)
    Utils.stream_to_buffer(history_bufnr, "\n# Prompt")
    Utils.stream_to_buffer(history_bufnr, prompt_lines)
    Utils.stream_to_buffer(history_bufnr, "\n# Response\n")
    Utils.clear_buffer(prompt_bufnr)
    vim.api.nvim_set_current_win(history_winid)
    Utils.move_cursor_to_bottom(history_winid, history_bufnr)

    -- local args = _G.make_openai_spec_curl_args(table.concat(prompt_lines, "\n"),
    --                                            table.concat(history_lines, "\n"))
    local args = _G.make_openai_spec_curl_args(table.concat(prompt_lines, "\n"), table.concat(history_lines, "\n"))

    local function parse_and_call(line)
        print(line)
        local event = line:match '^event: (.+)$'
        if event then
            return
        end
        local data_match = line:match '^data: (.+)$'
        if data_match then
            _G.handle_openai_spec_data(history_winid, data_match)
        end
    end

    if active_job then
        active_job:shutdown()
        active_job = nil
    end

    active_job = Job:new {
        command = 'curl',
        args = args,
        on_stdout = function(_, out)
            parse_and_call(out)
        end,
        on_stderr = function(_, _) end,
        on_exit = function()
            vim.schedule(function()
                Utils.move_cursor_to_bottom(history_winid, history_bufnr)
                Utils.save_buffer(history_bufnr)
                vim.api.nvim_set_current_win(prompt_winid)
            end)
            active_job = nil
        end,
    }

    active_job:start()

    -- vim.api.nvim_create_autocmd('User', {
        --     group = group,
        --     pattern = 'DING_LLM_Escape',
        --     callback = function()
            --         if active_job then
            --             active_job:shutdown()
            --             print 'LLM streaming cancelled'
            --             active_job = nil
            --         end
            --     end,
            -- })
            -- vim.api.nvim_set_keymap('n', '<Esc>', ':doautocmd User DING_LLM_Escape<CR>', { noremap = true, silent = true })
        end

        return _G
