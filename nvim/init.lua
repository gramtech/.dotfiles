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
              lookahead = true, -- optional: jump forward to textobject
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
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
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
