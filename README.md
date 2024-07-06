# jarvis.nvim

Jarvis cause the term LLMs might not last the test of time. i.e. it won't

A neovim plugin for no *agent*-assisted programming. Currently supports the following models:
- LLMS: [local, OpenAI, Anthropic]

Based on [melbaldove/jarvis.nvim](https://github.com/melbaldove/llm.nvim)

The main features/differences:
- the ui. 
    - this is an extension to [telescope](https://github.com/nvim-telescope/telescope.nvim)
    - this lets you open a floating window, type prompts, and also neatly seperates user prompts and responses. it's just streamlining the process.
    - *You can still use the file format if you'd like*.
- you can also fuzzy find previous sessions easily and open/swap between them quickly
    - fuzzy find by content
    - fuzzy find by filename (it stores a registry of all previous .md files so you can open them across folders. you can clear this cache)
- also there's support for local and api models

### Installation

`packer.nvim`
```lua
use({
    "MathieuTuli/jarvis.nvim",
    dependencies = { "nvim-neotest/nvim-nio" }
})
```

### Usage

**`setup()`**

Configure the plugin. This can be omitted to use the default configuration.

```lua
require('llm').setup({
    -- How long to wait for the request to start returning data.
    timeout_ms = 10000, -- if using a local model, this does nothing
    root = nil, -- set to a path to indicate where to store auto-created .md files
    -- by default = true : jarvis.nvim is like Telescope, it opens a windows to speak to it
    -- the window:
      -- always opens to the last conversation
      -- if there's a local .md file, it will open that
      -- you can start a new conversation with key commands (see below)
      -- every latest response is copied to clip if flag (below) is true
      -- otherwise, you can easily select the text you want copied
    windowed = true, 
    copy_to_clip = false,
    services = {
        -- Supported services configured by default
        -- openai = {
        --     url = "https://api.openai.com/v1/chat/completions",
        --     model = "gpt-4o",
        --     api_key_name = "OPENAI_API_KEY",
        -- },
        -- anthropic = {
        --     url = "https://api.anthropic.com/v1/messages",
        --     model = "claude-3-5-sonnet-20240620",
        --     api_key_name = "ANTHROPIC_API_KEY",
        -- },

        -- Extra OpenAI-compatible services to add (optional)
        -- other_provider = {
        --     url = "https://example.com/other-provider/v1/chat/completions",
        --     model = "llama3",
        --     api_key_name = "OTHER_PROVIDER_API_KEY",
        -- }
    }
})
```

**`prompt()`**

Triggers the LLM assistant.
- Optionally pass `replace` flag to replace the current selection with the LLM's response. The prompt is either the visually selected text or the file content up to the cursor if no selection is made.

**`create_llm_md()`**

Creates a new `llm.md` file in the `root` directory, where you can write questions or prompts for the LLM.
- Optionally takes a `path` or `name` to overwrite the default `root` path or set a filename.

**Example Bindings**
```lua
vim.keymap.set("n", "<leader>m", function() require("llm").create_llm_md() end)

-- keybinds for prompting with groq
vim.keymap.set("n", "<leader>,", function() require("llm").prompt({ replace = false, service = "groq" }) end)
vim.keymap.set("v", "<leader>,", function() require("llm").prompt({ replace = false, service = "groq" }) end)
vim.keymap.set("v", "<leader>.", function() require("llm").prompt({ replace = true, service = "groq" }) end)

-- keybinds for prompting with openai
vim.keymap.set("n", "<leader>g,", function() require("llm").prompt({ replace = false, service = "openai" }) end)
vim.keymap.set("v", "<leader>g,", function() require("llm").prompt({ replace = false, service = "openai" }) end)
vim.keymap.set("v", "<leader>g.", function() require("llm").prompt({ replace = true, service = "openai" }) end)

-- keybinds to support vim motions
vim.keymap.set("n", "g,", function() require("llm").prompt_operatorfunc({ replace = false, service = "groq" }) end)
vim.keymap.set("n", "g.", function() require("llm").prompt_operatorfunc({ replace = true, service = "groq" }) end)
```

### Roadmap
- your mom

### notes
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

- Obviously [yacine](https://twitter.com/i/broadcasts/1kvJpvRPjNaKE)/[yacine](https://github.com/yacineMTB/llm.nvim) and [melbadove](https://github.com/melbaldove/llm.nvim)
