-- Colors project-defined functions, type constructors and type-bound methods.
--
-- Tree-sitter cannot tell `foo(i)` (array access) from `foo(i)` (function call),
-- and fortls provides no semantic tokens. So the project is scanned for
-- procedure and type definitions, and matching call sites get highlighted.
local project = require("fortran.project")

local M = {}

local ns = vim.api.nvim_create_namespace("fortran_semantic")
local PRIORITY = 110 -- above tree-sitter (100), below LSP semantic tokens (125)

local NOT_NAMES = { operator = true, assignment = true, read = true, write = true, is = true }

---@class FortranSymbols
---@field funcs table<string, true>
---@field subs table<string, true>
---@field types table<string, true>
---@field methods table<string, true>

---@type table<string, FortranSymbols>
local projects = {}
local scanning = {} ---@type table<string, boolean>
local timers = {} ---@type table<integer, uv.uv_timer_t>

---@return FortranSymbols
local function empty()
  return { funcs = {}, subs = {}, types = {}, methods = {} }
end

---@param lines string[]
---@param syms FortranSymbols
local function parse_lines(lines, syms)
  for _, line in ipairs(lines) do
    local l = line:lower():gsub("!.*", "")
    if not l:match("^%s*end") then
      local name = l:match("function%s+([%a][%w_]*)")
      if name then
        syms.funcs[name] = true
      end
      name = l:match("subroutine%s+([%a][%w_]*)")
      if name then
        syms.subs[name] = true
      end
      -- Generic interfaces are called like the procedures they wrap
      name = l:match("^%s*interface%s+([%a][%w_]*)")
      if name and not NOT_NAMES[name] then
        syms.funcs[name] = true
      end
      name = l:match("^%s*type%s*,.-::%s*([%a][%w_]*)")
        or l:match("^%s*type%s*::%s*([%a][%w_]*)")
        or l:match("^%s*type%s+([%a][%w_]*)")
      if name and not NOT_NAMES[name] then
        syms.types[name] = true
      end
      if l:match("^%s*procedure") or l:match("^%s*generic") then
        local rest = l:match("::(.*)")
        for part in (rest or ""):gmatch("[^,]+") do
          local m = part:match("^%s*([%a][%w_]*)")
          if m and not NOT_NAMES[m] then
            syms.methods[m] = true
          end
        end
      end
    end
  end
end

local query ---@type vim.treesitter.Query?
local function get_query()
  query = query
    or vim.treesitter.query.parse(
      "fortran",
      [[
      (call_expression . (identifier) @call)
      (call_expression . (derived_type_member_expression (type_member) @method))
      (included_items (identifier) @import)
      (use_alias (local_name) @alias (identifier) @import)
      (variable_declaration
        declarator: [
          (identifier) @decl
          (sized_declarator . (identifier) @decl)
          (init_declarator left: [(identifier) @decl (sized_declarator . (identifier) @decl)])
          (pointer_init_declarator left: [(identifier) @decl (sized_declarator . (identifier) @decl)])
        ])
    ]]
    )
  return query
end

---@param buf integer
function M.highlight(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= "fortran" then
    return
  end
  local parser = vim.treesitter.get_parser(buf, "fortran", { error = false })
  if not parser then
    return
  end
  local tree = parser:parse()[1]
  local root = project.root(buf)
  local global = root and projects[root] or empty()

  -- The current buffer may contain unsaved definitions
  local syms = empty()
  parse_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false), syms)
  for kind, set in pairs(global) do
    setmetatable(syms[kind], { __index = set })
  end

  local q = get_query()
  local decls, captures = {}, {}
  for id, node in q:iter_captures(tree:root(), buf) do
    local cap = q.captures[id]
    local name = vim.treesitter.get_node_text(node, buf):lower()
    if cap == "decl" then
      decls[name] = true
    else
      table.insert(captures, { cap, name, node })
    end
  end

  -- `use m, only: local => original` makes `local` callable like `original`
  for i, c in ipairs(captures) do
    local nxt = captures[i + 1]
    if c[1] == "alias" and nxt and nxt[1] == "import" then
      for _, kind in ipairs({ "funcs", "types" }) do
        if syms[kind][nxt[2]] then
          syms[kind][c[2]] = true
        end
      end
    end
  end

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, c in ipairs(captures) do
    local cap, name, node = c[1], c[2], c[3]
    local hl
    if cap == "call" and not decls[name] then
      hl = syms.funcs[name] and "@function.call" or syms.types[name] and "@type" or nil
    elseif cap == "method" then
      hl = syms.methods[name] and "@function.method.call" or nil
    elseif cap == "import" or cap == "alias" then
      hl = (syms.funcs[name] or syms.subs[name]) and "@function" or syms.types[name] and "@type" or nil
    end
    if hl then
      local sr, sc, er, ec = node:range()
      vim.api.nvim_buf_set_extmark(buf, ns, sr, sc, { end_row = er, end_col = ec, hl_group = hl, priority = PRIORITY })
    end
  end
end

---@param buf integer
---@param ms? integer
function M.schedule(buf, ms)
  local timer = timers[buf]
  if not timer then
    timer = assert(vim.uv.new_timer())
    timers[buf] = timer
  end
  timer:start(ms or 150, 0, vim.schedule_wrap(function()
    M.highlight(buf)
  end))
end

---@param root string
local function refresh_root(root)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "fortran" and project.root(buf) == root then
      M.schedule(buf, 0)
    end
  end
end

---@param root string
function M.scan(root)
  if scanning[root] or vim.fn.executable("rg") == 0 then
    return
  end
  scanning[root] = true
  vim.system({
    "rg", "--ignore-case", "--no-filename", "--no-line-number", "--no-heading",
    "-e", [[\b(function|subroutine)\s+\w]],
    "-e", [[^\s*interface\s+\w]],
    "-e", [[^\s*type\b]],
    "-e", [[^\s*(procedure|generic)\b.*::]],
    "-g", "*.{f,F,for,FOR,f90,F90,f95,F95,f03,F03,f08,F08,fpp,FPP}",
    root,
  }, { text = true }, vim.schedule_wrap(function(out)
    scanning[root] = nil
    local syms = empty()
    parse_lines(vim.split(out.stdout or "", "\n", { trimempty = true }), syms)
    projects[root] = syms
    refresh_root(root)
  end))
end

function M.setup()
  local group = vim.api.nvim_create_augroup("fortran_semantic", { clear = true })

  local function attach(buf)
    local root = project.root(buf)
    if root and not projects[root] then
      M.scan(root)
    end
    M.schedule(buf, 0)
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "fortran",
    callback = function(ev)
      attach(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "BufEnter" }, {
    group = group,
    callback = function(ev)
      if vim.bo[ev.buf].filetype == "fortran" then
        M.schedule(ev.buf)
      end
    end,
  })
  -- New procedures in other files show up after saving
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(ev)
      local root = vim.bo[ev.buf].filetype == "fortran" and project.root(ev.buf)
      if root then
        M.scan(root)
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(ev)
      local timer = timers[ev.buf]
      if timer then
        timer:close()
        timers[ev.buf] = nil
      end
    end,
  })

  vim.api.nvim_create_user_command("FortranRescan", function()
    local root = project.root(0)
    if root then
      M.scan(root)
    end
  end, { desc = "Rescan the project for Fortran procedures and types" })

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "fortran" then
      attach(buf)
    end
  end
end

return M
