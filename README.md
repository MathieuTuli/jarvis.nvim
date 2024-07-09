# jarvis.nvim

I've decided to stop trying to find cool names for things and just copy Tony. Jarvis cause you know right away what it might be. Jarvis cause the term LLMs might not last the test of time.

A neovim plugin for *agent*-assisted programming. Currently supports models based on [dingllm](https://github.com/yacineMTB/dingllm.nvim), see [usage](#usage) for an example.

Based on [melbaldove/jarvis.nvim](https://github.com/melbaldove/llm.nvim) and [yacine](https://github.com/yacineMTB/dingllm.nvim).

The main features/differences:
- The ui. 
    - This uses [nui](https://github.com/MunifTanjim/nui.nvim)
    - This lets you open a floating window, type prompts, and neatly separate user prompts and responses. It's just streamlining the process.
- Chat vs. prompting
    - Separates workflows, allowing for a normal turn-style chat interaction or a one-off, file-bound prompting session.

### TODO
1. Default support for models?
    - Local
    - Anthropic
    - Groq
1. Add configurable options
    - Window sizing
    - Whether to jump into the history window or stay in the prompt window
    - Session persistence (currently bound to neovim process, should file path bind it?)
    - key-commands
1. Job cancel
1. Make history window read-only during response stream
1. Fuzzy find previous interactions easily and open/swap between them quickly
    - fuzzy find by content
    - fuzzy find by filename
1. Improve prompt history formatting (format the context/prompt/response shit based on models? xml? json? md?)
1. Cache cleanup
1. Look at the [link](https://github.com/MunifTanjim/nui.nvim/wiki/nui.layout) for how to unmount and clean everything
1. ~~copy/paste/confirm response~~

### Installation

For `packer.nvim` (I'm sure you can figure it out if you use `lazy`)
```lua
use({'MathieuTuli/jarvis.nvim',
    requires = { 'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim' },
})

```

### Usage

**`setup()`**

You can call `requires("jarvis").setup()` to accept the default API handler. Below is a copy of the default handler.

Somewhere else in your `init.lua` or in my case I have it in `~/.config/nvim/after/plugin/jarvis.lua` (basically somewhere that will run when you run nvim)
```lua
local model_name = "gpt-4o"
local url = "https://api.openai.com/v1/chat/completions"
local api_key_name = "OPENAI_API_KEY"
local system_prompt = "You are my helpful assistant coder. Try to be as non-verbose as possible and stick to the important things. Avoid describing your code unnecessarily, I only want you to output code mainly and limit describing it."

local function openai_data_handler(data_stream)
    if data_stream:match '"delta":' then
        local json = vim.json.decode(data_stream)
        if json.choices and json.choices[1] and json.choices[1].delta then
            return json.choices[1].delta.content
        end
    end
end

local function make_openai_curl_args(history, prompt)
    local api_key = os.getenv(api_key_name)
    local data = {
        messages = { { role = 'system', content = system_prompt }, { role = 'user', content = history .. prompt } },
        model = model_name,
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

require("jarvis").setup({
    cache_limit=1000,
    data_handler=openai_data_handler,
    make_curl_args=make_openai_curl_args,
})
```
Checkout [yacine](https://github.com/yacineMTB/dingllm.nvim) if you want examples for other models.

**`keymaps`**
There are two main interactions:
- `chat` : open a turn-based styled chat like regular ChatGPT
- `prompt` : open a one-off prompt window to ask a specific question
    - each time you open neovim, a timestamp is recorded, so the prompt history will persist for your entire session until the neovim process is killed
    - each buffer (i.e. file) will be bound to its own specific prompt history. you can thus navigate to new files and open prompts for each, and return to those buffers later to continue if you like (as long as it's in the same neovim process)
    - this window will also copy your visual selection from the current file, otherwise there won't be any copied context
```lua
-- there are two types of interactions: chat and prompting
vim.keymap.set({ 'n', 'v' }, '<leader>lc', function() require("jarvis").interact("chat") end, { desc = 'chat with jarvis' })
vim.keymap.set({ 'n', 'v' }, '<leader>la', function() require("jarvis").interact("prompt") end, { desc = 'prompt jarvis' })
```

### Credits

- [yacine](https://twitter.com/i/broadcasts/1kvJpvRPjNaKE)/[yacine](https://github.com/yacineMTB/llm.nvim) and [melbadove](https://github.com/melbaldove/llm.nvim)
