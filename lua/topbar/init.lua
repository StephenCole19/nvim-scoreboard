local M = {}
local sports = require("topbar.sports")

local config = {
  visible = true,
  show_sports = true,
  teams = { "Packers", "Maple Leafs" },
  refresh_interval = 60,
  height = 4,
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

local function create_block(data)
  if not data then
    return { "╭── Error ──╮", "│  No Data  │", "│           │", "╰───────────╯" }
  end

  local line1_text = ""
  local line2_text = ""

  if data.error then
    line1_text = "Error"
    line2_text = "N/A"
  elseif data.status == "No game scheduled" then
    line1_text = string.format("%s: %s", data.league or "???", data.abbrev or "???")
    line2_text = "No game"
  elseif data.status == "live" then
    line1_text = string.format("🔴 %s %d-%d %s", data.away_team or "???", data.away_score or 0, data.home_score or 0, data.home_team or "???")
    line2_text = data.time or "LIVE"
  elseif data.status == "upcoming" then
    line1_text = string.format("%s: %s vs %s", data.league or "???", data.away_team or "???", data.home_team or "???")
    line2_text = data.time or "TBD"
  else -- Final
    line1_text = string.format("FINAL: %s vs %s", data.away_team or "???", data.home_team or "???")
    line2_text = string.format("%d - %d", data.away_score or 0, data.home_score or 0)
  end

  local width = math.max(vim.fn.strdisplaywidth(line1_text), vim.fn.strdisplaywidth(line2_text)) + 2
  local top_border = "╭" .. string.rep("─", width) .. "╮"
  local bottom_border = "╰" .. string.rep("─", width) .. "╯"
  
  local l1_padding = width - vim.fn.strdisplaywidth(line1_text)
  local l1_left = math.floor(l1_padding / 2)
  local l1_right = l1_padding - l1_left
  local line1 = "│" .. string.rep(" ", l1_left) .. line1_text .. string.rep(" ", l1_right) .. "│"

  local l2_padding = width - vim.fn.strdisplaywidth(line2_text)
  local l2_left = math.floor(l2_padding / 2)
  local l2_right = l2_padding - l2_left
  local line2 = "│" .. string.rep(" ", l2_left) .. line2_text .. string.rep(" ", l2_right) .. "│"

  return { top_border, line1, line2, bottom_border }
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
    local content_lines = { "", "", "", "" }
    local has_content = false
    
    if config.show_sports and #config.teams > 0 then
      for i, _ in ipairs(config.teams) do
        if cached_sports_data[i] then
          local block_lines = create_block(cached_sports_data[i])
          if block_lines then
            has_content = true
            for j = 1, 4 do
              content_lines[j] = content_lines[j] .. (content_lines[j] ~= "" and "  " or "") .. block_lines[j]
            end
          end
        end
      end
    else
      local text = config.text or ""
      content_lines[2] = text
      has_content = (text ~= "")
    end
    
    local final_lines = {}
    if has_content then
       local content_width = 0
       if config.show_sports then
         content_width = vim.fn.strdisplaywidth(content_lines[1])
       else
         content_width = vim.fn.strdisplaywidth(content_lines[2])
       end

       local padding = math.floor((width - content_width) / 2)
       local left_pad = string.rep(" ", math.max(0, padding))

       for j = 1, 4 do
         table.insert(final_lines, left_pad .. content_lines[j])
       end
    else
       final_lines = { "", "", "", "" }
    end

    vim.api.nvim_buf_set_option(topbar_buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(topbar_buf, 0, -1, false, final_lines)
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

