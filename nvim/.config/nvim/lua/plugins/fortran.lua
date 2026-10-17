return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        fortls = {
          -- Managed with `uv tool`, not Mason
          mason = false,
          cmd = {
            vim.fn.expand("~/.local/bin/fortls"),
          },
        },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, "fortran") then
        table.insert(opts.ensure_installed, "fortran")
      end
    end,
  },
  -- gfortran diagnostics, with flags from .vscode/settings.json (fortran.linter.*)
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        fortran = { "gfortran" },
      },
      linters = {
        gfortran = function()
          local file = vim.api.nvim_buf_get_name(0)
          return {
            cmd = "gfortran",
            args = require("fortran.project").lint_args(file),
            stdin = false,
            append_fname = true,
            stream = "stderr",
            ignore_exitcode = true,
            parser = function(output, bufnr)
              local diagnostics = {}
              local name = vim.fs.basename(vim.api.nvim_buf_get_name(bufnr))
              local severities = {
                Error = vim.diagnostic.severity.ERROR,
                ["Fatal Error"] = vim.diagnostic.severity.ERROR,
                Warning = vim.diagnostic.severity.WARN,
              }
              for line in vim.gsplit(output, "\n", { trimempty = true }) do
                local path, lnum, col, kind, msg = line:match("^(.-):(%d+):(%d+): (%a[%a ]-): (.*)$")
                if path and vim.fs.basename(path) == name and severities[kind] then
                  table.insert(diagnostics, {
                    lnum = tonumber(lnum) - 1,
                    col = tonumber(col) - 1,
                    severity = severities[kind],
                    message = (msg:gsub(" at %(1%)", "")),
                    source = "gfortran",
                  })
                end
              end
              return diagnostics
            end,
          }
        end,
      },
    },
  },
  -- fprettify, with flags from .vscode/settings.json (fortran.formatting.fprettifyArgs)
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        fortran = { "fprettify" },
      },
      formatters = {
        fprettify = {
          prepend_args = function(_, ctx)
            return require("fortran.project").fprettify_args(ctx.filename)
          end,
        },
      },
    },
  },
  -- Highlight project procedures/types at call sites (see lua/fortran/semantic.lua)
  {
    name = "fortran-semantic",
    dir = vim.fn.stdpath("config") .. "/lua/fortran",
    ft = "fortran",
    config = function()
      require("fortran.semantic").setup()
      -- Format with <leader>cf on demand; formatting on save would touch unrelated lines
      local function no_autoformat(buf)
        vim.b[buf].autoformat = false
      end
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("fortran_no_autoformat", { clear = true }),
        pattern = "fortran",
        callback = function(ev)
          no_autoformat(ev.buf)
        end,
      })
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].filetype == "fortran" then
          no_autoformat(buf)
        end
      end
    end,
  },
}
