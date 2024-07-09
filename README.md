# jarvis.nvim

I've decided to stop trying to find cool names for things and just copy Tony. Jarvis cause you know right away what it might be. Jarvis cause the term LLMs might not last the test of time.

A neovim plugin for no *agent*-assisted programming. Currently supports the following models:
- LLMS: OpenAI

Based on [melbaldove/jarvis.nvim](https://github.com/melbaldove/llm.nvim) and [yacine](https://github.com/yacineMTB/dingllm.nvim).

The main features/differences:
- the ui. 
    - this uses [nui](https://github.com/MunifTanjim/nui.nvim)
    - this lets you open a floating window, type prompts, and also neatly seperates user prompts and responses. it's just streamlining the process.
- Chat vs. prompting
    - Seperates workflows, allowing for a normal turn-style chat interaction or a one-off, file-bound prompting session.

### TODO
1. support for other models:
    - Local
    - Anthropic
    - Groq
1. add configurable options
    - model url
    - window sizing
    - whether to jump into history window or stay in prompt
    - cache size
    - session persistance (currently bound to neovim process, should it be bound by filepath?)
1. job cancel
1. make history window readonly during response stream
1. fuzzy find previous interactions easily and open/swap between them quickly
    - fuzzy find by content
    - fuzzy find by filename (it stores a registry of all previous .md files so you can open them across folders. you can clear this cache)
1. check on hacked solution to first line formatting problem
1. cache cleanup
1. format the context/prompt/response shit (based on models? xml? json? md?)
1. look at the [link](https://github.com/MunifTanjim/nui.nvim/wiki/nui.layout) for how to unmount and clean everything
1. ~~copy/paste/confirm response~~

### Installation

1. For `packer.nvim` (I'm sure you can figure it out if you use `lazy`)
```lua
use({'MathieuTuli/jarvis.nvim',
    requires = { 'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim' },
})

```

### Usage

**`setup()`**

Configure the plugin. This is required to define the LLM api.

Somewhere else in your `init.lua` or in my case I have it in `~/.config/nvim/after/plugin/jarvis.lua` (basically somewhere that will run when you run nvim)
```lua
local model_name = "gpt-4o"
local url = "https://api.openai.com/v1/chat/completions"
local api_key_name = "OPENAI_API_KEY"
local system_prompt = "You are my helpful assistant coder. Try to be as non-verbose as possible and stick to the important things. Avoid describing your own code unecessarily, I only want you to output code mainly and limit describing it."

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
### dev notes
ok flow will look something like this:
- <c-llm> will open the preview pane
- this will open the prompt at the bottom with the previously used session at the top (or wherever)
- you will then either do 4 things:
    1. type a prompt
    1. hit <c-c> or just <CR> enter the chat history and copy something
    1. hit <c-s> to open a search to find a previous filename/session
    1. hit <c-f> to open a search to find a previous session based on content
- The last 3 are self-explanatory.
- The first one, when you click <CR> on your prompt, it will auto-navigate you to the chat history window
    - each prompt will be seperated by blocks so you can navigate with `[` and `]` and copy
- The other option is that you don't store a chat history, and each session is spawned/deleted
    - in this case, opening the preview would create a buffer, and you could continue to prompt and even select code blocks to replace by v selecting and prompting again, and then you could copy the whole buffer and go back to your document
- similarly, maybe hitting like <ctrl-y> will copy and paste the buffer back into your previous cursor position or something, and if you were selecting something, it would replace it all
- to get out of the chat window, hit escape. the chat window is visual mode only, escape again will close the window

### Credits

- [yacine](https://twitter.com/i/broadcasts/1kvJpvRPjNaKE)/[yacine](https://github.com/yacineMTB/llm.nvim) and [melbadove](https://github.com/melbaldove/llm.nvim)
