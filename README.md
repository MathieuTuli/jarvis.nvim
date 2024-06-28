# jarvis.nvim

A neovim plugin for no agent-assisted programming. Currently supports the following models:
- LLMS: [local, OpenAI, Anthropic]

Based on [melbaldove/jarvis.nvim](https://github.com/melbaldove/llm.nvim)


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

### Credits

- Obviously [yacine](https://twitter.com/i/broadcasts/1kvJpvRPjNaKE)/[yacine](https://github.com/yacineMTB/llm.nvim) and [melbadove](https://github.com/melbaldove/llm.nvim)
