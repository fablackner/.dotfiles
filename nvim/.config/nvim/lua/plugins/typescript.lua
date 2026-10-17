-- TypeScript 7 serves its language server from `tsc --lsp` (there is no tsserver.js
-- any more). Prefer the project's own compiler so diagnostics match `tsc`; fall back
-- to the Mason-installed tsgo for projects on older TypeScript.
local function tsgo_executable(root)
  local bin = vim.fs.joinpath(root, "node_modules/.bin")
  if vim.fn.executable(bin .. "/tsgo") == 1 then
    return bin .. "/tsgo"
  end
  local ok, pkg = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(root .. "/node_modules/typescript/package.json"), "\n"))
  end)
  local major = ok and type(pkg) == "table" and tonumber(tostring(pkg.version):match("^(%d+)%.")) or 0
  if major >= 7 and vim.fn.executable(bin .. "/tsc") == 1 then
    return bin .. "/tsc"
  end
  return "tsgo"
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        tsgo = {
          cmd = function(dispatchers, config)
            local root = (config or {}).root_dir
            local exe = root and tsgo_executable(root) or "tsgo"
            return vim.lsp.rpc.start({ exe, "--lsp", "--stdio" }, dispatchers)
          end,
          on_init = function(client)
            -- Where Biome is configured it owns formatting; don't format twice on save.
            local root = client.root_dir
            local biome = root and vim.fs.find({ "biome.json", "biome.jsonc" }, { path = root, upward = true })
            if biome and #biome > 0 then
              client.server_capabilities.documentFormattingProvider = false
              client.server_capabilities.documentRangeFormattingProvider = false
            end
          end,
        },
        -- Only starts in projects with a biome.json; uses node_modules/.bin/biome when present.
        biome = {},
      },
    },
  },
}
