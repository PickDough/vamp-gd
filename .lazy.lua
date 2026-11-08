-- Neovim setup for this Redot project. lazy.nvim loads this file when Neovim starts in the project root, so
-- everything here applies to this project only.
--
-- Redot has to be open on the project: it serves the GDScript language server (port 6005) and the debug adapter
-- (port 6006). Redot opens files here through server.pipe; see "Neovim" in CONTRIBUTING.md.

local root = vim.fs.root(vim.fn.getcwd(), "project.godot") or vim.fn.getcwd()

local function listen_for_redot()
  local pipe = root .. "/server.pipe"
  if vim.uv.fs_stat(pipe) then
    local ok, channel = pcall(vim.fn.sockconnect, "pipe", pipe)
    if ok and channel > 0 then
      vim.fn.chanclose(channel)
      return
    end
    os.remove(pipe)
  end
  pcall(vim.fn.serverstart, pipe)
end


listen_for_redot()

local godot_theme_captures = {
  ["@keyword.conditional"] = "@conditional",
  ["@keyword.repeat"] = "@repeat",
  ["@keyword.return"] = "@conditional",
  ["@keyword.exception"] = "@conditional",
  ["@function.method"] = "@function",
  ["@function.method.call"] = "@method.call",
  ["@type.definition"] = "@type",
  ["@string.special"] = "@attribute",
}

return {
  {
    "bentok/godot.nvim",
    commit = "799941ab9800293c18617acf7030b16f882ec32b",
    lazy = false,
    priority = 1000,
    init = function()
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "godot",
        callback = function()
          for capture, target in pairs(godot_theme_captures) do
            vim.api.nvim_set_hl(0, capture, { link = target })
          end
        end,
      })
    end,
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "godot" } },

  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          files = { exclude = { "*.uid" } },
          grep = { exclude = { "*.uid" } },
          explorer = { exclude = { "*.uid" } },
        },
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gdscript = { mason = false },
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "gdscript", "godot_resource", "gdshader" } },
  },

  {
    "mfussenegger/nvim-dap",
    keys = {
      { "<leader>dc", function() require("dap").continue() end, desc = "Run/Continue" },
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step Into" },
      { "<leader>do", function() require("dap").step_over() end, desc = "Step Over" },
      { "<leader>dO", function() require("dap").step_out() end, desc = "Step Out" },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "Terminate" },
    },
    config = function()
      local dap = require("dap")
      dap.adapters.godot = { type = "server", host = "127.0.0.1", port = 6006 }
      dap.configurations.gdscript = {
        { type = "godot", request = "launch", name = "Launch main scene", project = root },
      }
    end,
  },

  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = { gdscript = { "gdscript_formatter" } },
      formatters = {
        gdscript_formatter = {
          command = function()
            local on_path = vim.fn.exepath("gdscript-formatter")
            if on_path ~= "" then
              return on_path
            end
            for _, editor in ipairs({ "~/.cursor", "~/.vscode" }) do
              local pattern = editor .. "/extensions/dohe.godot-format-*/binaries/gdscript-formatter"
              local bundled = vim.fn.glob(pattern, false, true)
              if #bundled > 0 then
                return bundled[#bundled]
              end
            end
            return "gdscript-formatter"
          end,
          stdin = true,
        },
      },
    },
  },

  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.gdscript = { "vamp_rd_lint" }
      opts.linters = opts.linters or {}
      opts.linters.vamp_rd_lint = {
        cmd = "python3",
        args = { root .. "/tools/lint/lint.py", "--no-engine" },
        stdin = false,
        append_fname = true,
        ignore_exitcode = true,
        stream = "stdout",
        parser = require("lint.parser").from_pattern(
          "^[^:]+:(%d+):(%d+): ([%w%-]+): (.+)$",
          { "lnum", "col", "code", "message" },
          nil,
          { source = "lint.py", severity = vim.diagnostic.severity.WARN }
        ),
      }
    end,
  },
}
