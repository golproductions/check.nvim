local M = {}

local API = "https://triage.golproductions.com/preflight"
local INSTANT = "https://triage.golproductions.com/instant-key"
local CHANNEL = "neovim"
local VERSION = "1.0.1"

M.config = {
  client_id = vim.env.GOL_CLIENT_ID or "",
  enabled = true,
  timeout = 5000,
}

-- One free GOL Client ID per machine, shared by every Check client
-- (npm hook, MCP, editors). All clients read and write this file.
local function key_file()
  return vim.fn.expand("~") .. "/.check/key"
end

local function legacy_key_file()
  return vim.fn.stdpath("data") .. "/gol-check-key"
end

function M._load_key()
  for _, path in ipairs({ key_file(), legacy_key_file() }) do
    local f = io.open(path, "r")
    if f then
      local id = vim.trim(f:read("*a") or "")
      f:close()
      if id ~= "" then return id end
    end
  end
  return ""
end

function M._save_key(id)
  vim.fn.mkdir(vim.fn.expand("~") .. "/.check", "p")
  local f = io.open(key_file(), "w")
  if f then
    f:write(id)
    f:close()
  end
end

-- One-way hash of coarse machine facts. No personal data. The recipe
-- (hostname|platform|arch|username, Node.js-style tokens) is shared by every
-- Check client so all tools on one machine resolve to the same free key.
local function device_fingerprint()
  local uname = vim.loop.os_uname() or {}
  local sys = (uname.sysname or ""):lower()
  local plat = "linux"
  if sys:find("windows") then plat = "win32"
  elseif sys:find("darwin") then plat = "darwin" end
  local mach = (uname.machine or ""):lower()
  local arch = (mach:find("arm64") or mach:find("aarch64")) and "arm64" or "x64"
  return vim.fn.sha256(table.concat({
    vim.fn.hostname() or "",
    plat,
    arch,
    os.getenv("USER") or os.getenv("USERNAME") or "",
  }, "|"))
end

-- Mint a free key with no signup. Persists and returns it, or nil on failure.
function M._mint_instant_key()
  local body = vim.json.encode({ fingerprint = device_fingerprint(), channel = CHANNEL })
  local handle = io.popen(string.format(
    'curl -s -X POST "%s" -H "Content-Type: application/json" -H "User-Agent: neovim/%s" --max-time 10 -d \'%s\'',
    INSTANT, VERSION, body:gsub("'", "'\\''")
  ))
  if not handle then return nil end
  local out = handle:read("*a")
  handle:close()
  local ok, data = pcall(vim.json.decode, out)
  if not ok or not data or not data.client_id then return nil end
  M.config.client_id = data.client_id
  M._save_key(data.client_id)
  return data.client_id
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Restore a previously minted key if no env var / option was provided.
  if M.config.client_id == "" then
    M.config.client_id = M._load_key()
  end

  vim.api.nvim_create_user_command("Check", function(args)
    local cmd = args.args
    if cmd == "" then
      cmd = vim.fn.input("Command to validate: ")
    end
    if cmd == "" then return end
    M.validate(cmd)
  end, { nargs = "?", desc = "Validate a command with GOL Check" })

  vim.api.nvim_create_user_command("CheckSelection", function()
    local lines = vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"), { type = vim.fn.visualmode() })
    local text = table.concat(lines, "\n")
    if text == "" then
      vim.notify("Check: No selection", vim.log.levels.WARN)
      return
    end
    M.validate(text)
  end, { range = true, desc = "Validate selected text with GOL Check" })

  vim.api.nvim_create_user_command("CheckSetup", function()
    local id = vim.fn.input("Enter your GOL Client ID: ")
    if id ~= "" then
      M.config.client_id = id
      M._save_key(id)
      vim.notify("Check: Client ID set and saved.", vim.log.levels.INFO)
    end
  end, { desc = "Set GOL Check Client ID" })
end

function M.validate(command)
  if not M.config.enabled then
    vim.notify("Check: Disabled", vim.log.levels.WARN)
    return
  end

  if M.config.client_id == "" then
    -- No key yet: mint one instantly. No email, no browser.
    vim.notify("Check: Activating...", vim.log.levels.INFO)
    if not M._mint_instant_key() then
      vim.notify("Check: could not activate. Check your connection and try again.", vim.log.levels.ERROR)
      return
    end
  end

  local body = vim.json.encode({
    command = command,
    platform = "neovim",
    channel = CHANNEL,
    v = VERSION,
  })

  vim.notify("Check: Validating...", vim.log.levels.INFO)

  if vim.fn.has("nvim-0.10") == 1 and vim.system then
    vim.system(
      { "curl", "-s", "-X", "POST", API,
        "-H", "Content-Type: application/json",
        "-H", "X-GOL-CLIENT-ID: " .. M.config.client_id,
        "-H", "User-Agent: neovim/" .. VERSION,
        "--max-time", tostring(M.config.timeout / 1000),
        "-d", body },
      {},
      vim.schedule_wrap(function(result)
        if result.code ~= 0 then
          vim.notify("Check: Network error", vim.log.levels.ERROR)
          return
        end
        M._handle_response(command, result.stdout)
      end)
    )
  else
    local handle = io.popen(string.format(
      'curl -s -X POST "%s" -H "Content-Type: application/json" -H "X-GOL-CLIENT-ID: %s" -H "User-Agent: neovim/%s" --max-time %d -d \'%s\'',
      API, M.config.client_id, VERSION, M.config.timeout / 1000, body:gsub("'", "'\\''")
    ))
    if not handle then
      vim.notify("Check: Failed to call API", vim.log.levels.ERROR)
      return
    end
    local response = handle:read("*a")
    handle:close()
    M._handle_response(command, response)
  end
end

function M._handle_response(command, response)
  local ok, data = pcall(vim.json.decode, response)
  if not ok or not data then
    vim.notify("Check: Invalid API response", vim.log.levels.ERROR)
    return
  end

  local short = command:sub(1, 80)
  if data.verdict == "runnable" then
    vim.notify("Check: ✓ Runnable — " .. short, vim.log.levels.INFO)
  elseif data.upgrade or data.error == "Daily free limit reached" then
    -- Free wall: out of daily free checks, balance empty.
    vim.notify("Check: You've used all 120 free checks today. Credits never expire. "
      .. (data.upgrade or "Top up at https://www.golproductions.com/console.html"), vim.log.levels.WARN)
  else
    vim.notify("Check: ✗ Blocked — " .. (data.reason or data.error or short), vim.log.levels.WARN)
  end
end

return M
