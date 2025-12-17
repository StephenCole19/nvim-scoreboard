local M = {}
local sports = require("topbar.sports")

local config = {
  visible = true,
  show_sports = true,
  teams = { "Packers", "Maple Leafs" },
  refresh_interval = 60,
  height = 1,
  text = "",
}

local topbar_win = nil
local topbar_buf = nil
local timer = nil
local cached_sports_data = {}

local update_topbar_content

local function create_topbar()
  if topbar_buf and vim.api.nvim_buf_is_valid(topbar_buf) then
    return
  end

  topbar_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(topbar_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(topbar_buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(topbar_buf, "swapfile", false)
  vim.api.nvim_buf_set_option(topbar_buf, "modifiable", false)
end

local function format_team_box(data)
  local ok, result = pcall(function()
    if not data then
      return "[Error: No data]"
    end
    
    if data.error then
      return string.format("[%s: %s]", data.error, "N/A")
    end
    
    if data.status == "No game scheduled" then
      return string.format("[%s %s: No game]", data.league or "???", data.abbrev or "???")
    end
    
    if data.status == "live" then
      return string.format("[🔴 %s %d - %s %d | %s]",
        data.away_team or "???", data.away_score or 0,
        data.home_team or "???", data.home_score or 0,
        data.time or "LIVE"
      )
    elseif data.status == "upcoming" then
      return string.format("[%s: %s vs %s | %s]",
        data.league or "???",
        data.away_team or "???", data.home_team or "???",
        data.time or "TBD"
      )
    else
      return string.format("[FINAL: %s %d - %s %d]",
        data.away_team or "???", data.away_score or 0,
        data.home_team or "???", data.home_score or 0
      )
    end
  end)
  
  if ok then
    return result
  else
    return "[Error]"
  end
end

local function fetch_sports_data()
  pcall(function()
    if not config.show_sports or #config.teams == 0 then
      return
    end
    
    local completed = 0
    local total = #config.teams
    
    for i, team_name in ipairs(config.teams) do
      pcall(sports.fetch_team_data, team_name, function(data)
        pcall(function()
          cached_sports_data[i] = data
          completed = completed + 1
          if completed == total then
            pcall(update_topbar_content)
          end
        end)
      end)
    end
  end)
end

update_topbar_content = function()
  pcall(function()
    if not topbar_buf or not vim.api.nvim_buf_is_valid(topbar_buf) then
      return
    end

    local width = vim.o.columns
    local content = ""
    
    if config.show_sports and #config.teams > 0 then
      local boxes = {}
      for i, _ in ipairs(config.teams) do
        if cached_sports_data[i] then
          local box = format_team_box(cached_sports_data[i])
          if box then
            table.insert(boxes, box)
          end
        end
      end
      content = table.concat(boxes, " ")
    else
      content = config.text or ""
    end
    
    local padding = math.floor((width - #content) / 2)
    local padded_text = string.rep(" ", math.max(0, padding)) .. content

    vim.api.nvim_buf_set_option(topbar_buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(topbar_buf, 0, -1, false, { padded_text })
    vim.api.nvim_buf_set_option(topbar_buf, "modifiable", false)
  end)
end

local function start_refresh_timer()
  pcall(function()
    if not config.show_sports or #config.teams == 0 then
      return
    end
    
    if timer then
      pcall(timer.stop, timer)
      pcall(timer.close, timer)
    end
    
    pcall(fetch_sports_data)
    
    timer = vim.loop.new_timer()
    if timer then
      timer:start(config.refresh_interval * 1000, config.refresh_interval * 1000, function()
        vim.schedule(function()
          pcall(fetch_sports_data)
        end)
      end)
    end
  end)
end

local function stop_refresh_timer()
  pcall(function()
    if timer then
      pcall(timer.stop, timer)
      pcall(timer.close, timer)
      timer = nil
    end
  end)
end

local function show_topbar()
  if topbar_win and vim.api.nvim_win_is_valid(topbar_win) then
    return
  end

  create_topbar()
  update_topbar_content()

  local width = vim.o.columns

  topbar_win = vim.api.nvim_open_win(topbar_buf, false, {
    relative = "editor",
    row = 0,
    col = 0,
    width = width,
    height = config.height,
    style = "minimal",
    focusable = false,
    zindex = 100,
  })

  vim.api.nvim_win_set_option(topbar_win, "winhl", "Normal:TopbarNormal")

  vim.o.showtabline = 0

  config.visible = true
  
  if config.show_sports and #config.teams > 0 then
    start_refresh_timer()
  end
end

local function hide_topbar()
  if topbar_win and vim.api.nvim_win_is_valid(topbar_win) then
    vim.api.nvim_win_close(topbar_win, true)
    topbar_win = nil
  end
  stop_refresh_timer()
  config.visible = false
end

function M.toggle()
  pcall(function()
    if config.visible then
      hide_topbar()
    else
      show_topbar()
    end
  end)
end

function M.show()
  pcall(show_topbar)
end

function M.hide()
  pcall(hide_topbar)
end

function M.set_text(text)
  pcall(function()
    config.text = text
    update_topbar_content()
  end)
end

function M.refresh_sports()
  pcall(fetch_sports_data)
end

function M.enable_sports()
  pcall(function()
    config.show_sports = true
    cached_sports_data = {}
    if config.visible then
      stop_refresh_timer()
      start_refresh_timer()
    else
      pcall(fetch_sports_data)
    end
  end)
end

function M.disable_sports()
  pcall(function()
    config.show_sports = false
    stop_refresh_timer()
    update_topbar_content()
  end)
end

function M.setup(opts)
  opts = opts or {}
  config = vim.tbl_deep_extend("force", config, opts)

  vim.api.nvim_set_hl(0, "TopbarNormal", { bg = "#1e1e2e", fg = "#cdd6f4", bold = true })

  vim.api.nvim_create_user_command("ScoreT", function()
    M.toggle()
  end, {})

  vim.api.nvim_create_user_command("ScoreS", function()
    M.show()
  end, {})

  vim.api.nvim_create_user_command("ScoreH", function()
    M.hide()
  end, {})

  vim.api.nvim_create_user_command("ScoreRefresh", function()
    M.refresh_sports()
  end, {})

  vim.api.nvim_create_user_command("ScoreSportsEnable", function()
    M.enable_sports()
  end, {})

  vim.api.nvim_create_user_command("ScoreSportsDisable", function()
    M.disable_sports()
  end, {})

  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      pcall(function()
        if config.visible and topbar_win and vim.api.nvim_win_is_valid(topbar_win) then
          hide_topbar()
          show_topbar()
        end
      end)
    end,
  })

  if config.visible then
    vim.defer_fn(function()
      pcall(show_topbar)
    end, 100)
  end
end

return M

