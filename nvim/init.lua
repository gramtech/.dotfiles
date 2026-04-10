--------------------------------------------------
-- Leader keys
--------------------------------------------------
vim.g.mapleader = " "
vim.g.maplocalleader = " "

--------------------------------------------------
-- Basic options
--------------------------------------------------
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 500
vim.opt.clipboard = "unnamedplus"
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true
vim.opt.mouse = "a"

vim.keymap.set("n", "<leader>w", "<cmd>w<cr>",  { desc = "Save" })
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>",  { desc = "Quit" })
vim.keymap.set("n", "<leader>Q", "<cmd>qa<cr>", { desc = "Quit all" })

--------------------------------------------------
-- AI startup default — written to ~/.zshrc.local by install.sh.
-- "copilot"  → Copilot auto-triggers, codecompanion defaults to Copilot adapter.
-- unset/other → Ollama is the default. Toggle at runtime with <leader>am.
--------------------------------------------------
local copilot_default = os.getenv("NVIM_AI_DEFAULT") == "copilot"
local ai_mode = copilot_default and "work" or "home"

--------------------------------------------------
-- Bootstrap lazy.nvim
--------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Servers to install/enable — built once, shared by mason-lspconfig and lspconfig
local function lsp_servers()
  local s = { "lua_ls" }
  if vim.fn.executable("npm")       == 1 then
    table.insert(s, "bashls")
    table.insert(s, "yamlls")
    table.insert(s, "jsonls")
  end
  if vim.fn.executable("terraform") == 1 then table.insert(s, "terraformls") end
  if vim.fn.executable("docker")    == 1 then table.insert(s, "dockerls")    end
  return s
end

--------------------------------------------------
-- Plugins
--------------------------------------------------
require("lazy").setup({

  { "nvim-lua/plenary.nvim" },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep,  { desc = "Live grep" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers,    { desc = "Buffers" })
    end,
  },

  -- tmux <-> nvim navigation
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
  },

  {
    "lewis6991/gitsigns.nvim",
    opts = {},
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
    },
    config = function()
      local wk = require("which-key")
      wk.add({
        { "<leader>f", group = "format/find" },
        { "<leader>a", group = "ai" },
      })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
    config = function()
      local ok, configs = pcall(require, "nvim-treesitter.configs")
      if ok then
        configs.setup({
          highlight = { enable = true },
          textobjects = {
            select = {
              enable = true,
              lookahead = true,
              keymaps = {
                ["af"] = "@function.outer",
                ["if"] = "@function.inner",
                ["ac"] = "@class.outer",
                ["ic"] = "@class.inner",
              },
            },
          },
        })
      end
    end,
  },

  --------------------------------------------------
  -- AI: Copilot — native ghost text (VS Code style)
  -- Activate at work with :Copilot auth
  --------------------------------------------------
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = function()
      return {
        suggestion = {
          enabled = true,
          auto_trigger = copilot_default, -- on at work, off at home
          keymap = {
            accept      = false,  -- handled by smart Tab below
            accept_word = "<M-w>",
            accept_line = "<M-l>",
            next        = "<M-]>",
            prev        = "<M-[>",
            dismiss     = "<C-]>",
          },
        },
        panel = { enabled = false },
      }
    end,
  },

  --------------------------------------------------
  -- AI: Ollama ghost text (FIM model)
  -- Requires: ollama serve + a FIM model pulled
  -- e.g. ollama pull qwen2.5-coder:7b
  --------------------------------------------------
  {
    "huggingface/llm.nvim",
    opts = {
      backend = "ollama",
      url     = "http://localhost:11434",
      model   = "qwen2.5-coder:7b", -- swap for whichever FIM model you have pulled
      enable_suggestions_on_startup = false, -- toggle with <leader>ag
    },
  },

  --------------------------------------------------
  -- AI: Claude sidebar via Claude Code CLI
  -- No API key needed — uses existing `claude` login
  --------------------------------------------------
  {
    "coder/claudecode.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
    keys = {
      { "<leader>at", "<cmd>ClaudeCodeToggle<cr>", desc = "Toggle Claude sidebar" },
      { "<leader>as", "<cmd>ClaudeCode<cr>",        desc = "Claude Code" },
    },
  },

  --------------------------------------------------
  -- AI: Chat + inline assist (Copilot at work, Ollama at home)
  --------------------------------------------------
  {
    "olimorris/codecompanion.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("codecompanion").setup({
        adapters = {
          copilot = function()
            return require("codecompanion.adapters").extend("copilot", {})
          end,
          ollama = function()
            return require("codecompanion.adapters").extend("ollama", {
              schema = { model = { default = "llama3.2" } },
            })
          end,
          -- Uncomment + set OPENAI_API_KEY to enable ChatGPT/Codex via API:
          -- openai = function()
          --   return require("codecompanion.adapters").extend("openai", {
          --     schema = { model = { default = "gpt-4o" } },
          --   })
          -- end,
        },
        strategies = {
          chat   = { adapter = copilot_default and "copilot" or "ollama" },
          inline = { adapter = copilot_default and "copilot" or "ollama" },
        },
      })
    end,
    keys = {
      { "<leader>ac", "<cmd>CodeCompanionChat<cr>",    mode = { "n", "v" }, desc = "AI chat" },
      { "<leader>aa", "<cmd>CodeCompanionActions<cr>",  mode = { "n", "v" }, desc = "AI actions" },
      { "<leader>ai", "<cmd>CodeCompanion<cr>",         mode = { "n", "v" }, desc = "AI inline" },
    },
  },

  --------------------------------------------------
  -- Mason
  --------------------------------------------------
  {
    "williamboman/mason.nvim",
    opts = {},
  },

  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = function()
      return { ensure_installed = lsp_servers() }
    end,
  },

  --------------------------------------------------
  -- Completion
  --------------------------------------------------
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "L3MON4D3/LuaSnip" },

  --------------------------------------------------
  -- Formatting
  --------------------------------------------------
  { "stevearc/conform.nvim" },

  --------------------------------------------------
  -- LSP (Neovim 0.11+)
  --------------------------------------------------
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/nvim-cmp",
      "hrsh7th/cmp-nvim-lsp",
      "L3MON4D3/LuaSnip",
      "stevearc/conform.nvim",
    },
    config = function()

      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local function on_attach(_, bufnr)
        local map = function(mode, lhs, rhs)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr })
        end
        map("n", "gd", vim.lsp.buf.definition)
        map("n", "gr", vim.lsp.buf.references)
        map("n", "K", vim.lsp.buf.hover)
        map("n", "<leader>rn", vim.lsp.buf.rename)
        map("n", "<leader>ca", vim.lsp.buf.code_action)
      end

      for _, server in ipairs(lsp_servers()) do
        vim.lsp.config(server, {
          capabilities = capabilities,
          on_attach = on_attach,
        })
        vim.lsp.enable(server)
      end

      --------------------------------------------------
      -- nvim-cmp
      --------------------------------------------------
      local cmp = require("cmp")
      cmp.setup({
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<CR>"]    = cmp.mapping.confirm({ select = true }),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
          -- <Tab> is handled below (smart Tab)
        }),
        sources = {
          { name = "nvim_lsp" },
        },
      })

      --------------------------------------------------
      -- Conform
      --------------------------------------------------
      require("conform").setup({
        formatters_by_ft = {
          lua = { "stylua" },
          sh = { "shfmt" },
          terraform = { "terraform_fmt" },
          json = { "jq" },
        },
      })

      vim.keymap.set({ "n", "v" }, "<leader>f", function()
        require("conform").format({ lsp_fallback = true, timeout_ms = 2000 })
      end, { desc = "Format" })

    end,
  },

})

--------------------------------------------------
-- AI: Work / home mode toggle
-- Work:  Copilot ghost text on, Ollama off
-- Home:  Copilot ghost text off, Ollama available via <leader>ag
--------------------------------------------------
vim.keymap.set("n", "<leader>am", function()
  if ai_mode == "work" then
    require("copilot.suggestion").dismiss()
    vim.g.copilot_enabled = false
    ai_mode = "home"
    vim.notify("AI mode: Home (Claude + Ollama)", vim.log.levels.INFO)
  else
    if _llm_enabled then vim.cmd("LLMToggleAutoSuggest"); _llm_enabled = false end
    vim.g.copilot_enabled = true
    ai_mode = "work"
    vim.notify("AI mode: Work (Copilot)", vim.log.levels.INFO)
  end
end, { desc = "Toggle AI mode: Work / Home" })

-- Toggle Ollama ghost text (home mode)
local _llm_enabled = false
vim.keymap.set("n", "<leader>ag", function()
  vim.cmd("LLMToggleAutoSuggest")
  _llm_enabled = not _llm_enabled
  vim.notify("Ollama ghost text: " .. (_llm_enabled and "ON" or "OFF"), vim.log.levels.INFO)
end, { desc = "Toggle Ollama ghost text" })

--------------------------------------------------
-- Smart Tab
-- cmp open  → next completion item
-- ghost text visible → accept suggestion
-- otherwise → literal tab
--------------------------------------------------
vim.keymap.set("i", "<Tab>", function()
  local cmp = require("cmp")
  if cmp.visible() then
    cmp.select_next_item()
  elseif require("copilot.suggestion").is_visible() then
    require("copilot.suggestion").accept()
  else
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false
    )
  end
end, { desc = "Smart Tab" })
