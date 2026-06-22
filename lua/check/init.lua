local M = {}

local API = "https://triage.golproductions.com/preflight"
local VERSION = "1.0.0"

M.config = {
  client_id = vim.env.GOL_CLIENT_ID or "",
  enabled = true,
  timeout = 5000,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

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
      vim.notify("Check: Client ID set. Add GOL_CLIENT_ID=" .. id .. " to your shell profile to persist.", vim.log.levels.INFO)
    end
  end, { desc = "Set GOL Check Client ID" })
end

function M.validate(command)
  if not M.config.enabled then
    vim.notify("Check: Disabled", vim.log.levels.WARN)
    return
  end

  if M.config.client_id == "" then
    vim.notify("Check: No Client ID. Run :CheckSetup or set GOL_CLIENT_ID env var.\nGet one at golproductions.com/check.html", vim.log.levels.ERROR)
    return
  end

  local body = vim.json.encode({
    command = command,
    platform = "neovim",
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
  else
    vim.notify("Check: ✗ Blocked — " .. (data.reason or short), vim.log.levels.WARN)
  end
end

return M
