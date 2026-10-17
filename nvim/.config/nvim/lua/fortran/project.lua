-- Per-project Fortran settings, read from the Modern Fortran keys in
-- .vscode/settings.json so nvim lints and formats the same way VSCode does.
local M = {}

local cache = {} ---@type table<string, {mtime: integer, settings: table}>

---@param path string|integer file path or buffer
---@return string?
function M.root(path)
  return vim.fs.root(path, { ".fortls", ".fortls.json", "fpm.toml", ".git" })
end

---@param root string
---@return table
local function settings(root)
  local file = root .. "/.vscode/settings.json"
  local stat = vim.uv.fs_stat(file)
  if not stat then
    return {}
  end
  local cached = cache[root]
  if cached and cached.mtime == stat.mtime.sec then
    return cached.settings
  end
  local text = table.concat(vim.fn.readfile(file), "\n")
  -- VSCode allows full-line comments and trailing commas; strict JSON does not
  text = text:gsub("\n%s*//[^\n]*", "\n"):gsub(",(%s*[}%]])", "%1")
  local ok, decoded = pcall(vim.json.decode, text)
  local result = ok and type(decoded) == "table" and decoded or {}
  cache[root] = { mtime = stat.mtime.sec, settings = result }
  return result
end

---@param value string
---@param root string
local function expand(value, root)
  return (value:gsub("%${workspaceFolder}", root))
end

--- gfortran arguments for linting `file` (without the file itself)
---@param file string
---@return string[]
function M.lint_args(file)
  local root = M.root(file)
  local s = root and settings(root) or {}
  local args = { "-fsyntax-only", "-fdiagnostics-plain-output" }

  if file:match("%.F%w*$") then
    table.insert(args, "-cpp")
  end

  -- Keep warnings as warnings so the severity in the editor stays meaningful
  for _, arg in ipairs(s["fortran.linter.extraArgs"] or { "-Wall", "-Wextra" }) do
    if not arg:match("^%-Werror") then
      table.insert(args, arg)
    end
  end

  -- gfortran writes .mod files even with -fsyntax-only; keep them out of the source tree
  local mod_dir = s["fortran.linter.modOutput"] and expand(s["fortran.linter.modOutput"], root)
    or vim.fn.stdpath("cache") .. "/fortran-lint/" .. (root or "default"):gsub("[/\\:]", "%%")
  vim.fn.mkdir(mod_dir, "p")
  vim.list_extend(args, { "-J", mod_dir, "-I", mod_dir })

  for _, dir in ipairs(s["fortran.linter.includePaths"] or {}) do
    vim.list_extend(args, { "-I", expand(dir, root) })
  end
  vim.list_extend(args, { "-I", vim.fs.dirname(file) })
  return args
end

--- fprettify arguments, e.g. { "-i", "2", "-l", "600" }
---@param file string
---@return string[]
function M.fprettify_args(file)
  local root = M.root(file)
  local s = root and settings(root) or {}
  local args = {}
  for _, arg in ipairs(s["fortran.formatting.fprettifyArgs"] or {}) do
    vim.list_extend(args, vim.split(arg, "%s+", { trimempty = true }))
  end
  return args
end

return M
