local M = {}

local team_mappings = {
  ["green bay packers"] = { league = "nfl", espn_name = "Green Bay Packers", abbrev = "GB", team_id = "9" },
  ["packers"] = { league = "nfl", espn_name = "Green Bay Packers", abbrev = "GB", team_id = "9" },
  ["toronto maple leafs"] = { league = "nhl", espn_name = "Toronto Maple Leafs", abbrev = "TOR", team_id = "21" },
  ["maple leafs"] = { league = "nhl", espn_name = "Toronto Maple Leafs", abbrev = "TOR", team_id = "21" },
}

local function normalize_team_name(name)
  return string.lower(name)
end

function M.get_team_info(team_name)
  local normalized = normalize_team_name(team_name)
  return team_mappings[normalized]
end

local function find_next_game(events)
  if not events or #events == 0 then
    return nil, nil
  end
  
  for _, event in ipairs(events) do
    if event.competitions and #event.competitions > 0 then
      local comp = event.competitions[1]
      local status = event.status
      
      if status.type.state == "in" then
        return event, comp
      end
    end
  end
  
  for _, event in ipairs(events) do
    if event.competitions and #event.competitions > 0 then
      local comp = event.competitions[1]
      local status = event.status
      
      if status.type.state == "pre" then
        return event, comp
      end
    end
  end
  
  if #events > 0 and events[1].competitions and #events[1].competitions > 0 then
    return events[1], events[1].competitions[1]
  end
  
  return nil, nil
end

function M.fetch_team_data(team_name, callback)
  local safe_callback = function(data)
    pcall(callback, data)
  end
  
  local team_info = M.get_team_info(team_name)
  if not team_info then
    safe_callback({ 
      team = team_name,
      abbrev = "???",
      status = "No game scheduled",
      league = "???"
    })
    return
  end

  local league_id = team_info.league == "nfl" and "nfl" or "nhl"
  local sport = team_info.league == "nfl" and "football" or "hockey"
  local url = string.format("https://site.api.espn.com/apis/site/v2/sports/%s/%s/teams/%s",
    sport, league_id, team_info.team_id
  )

  local output = {}
  local default_result = { 
    team = team_info.espn_name,
    abbrev = team_info.abbrev,
    status = "No game scheduled",
    league = string.upper(team_info.league)
  }
  
  pcall(vim.fn.jobstart, { "curl", "-s", url }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      pcall(function()
        if data then
          output = data
        end
      end)
    end,
    on_exit = function()
      pcall(function()
        vim.schedule(function()
          pcall(function()
            local json_str = table.concat(output, "\n")
            
            if not json_str or json_str == "" then
              safe_callback(default_result)
              return
            end

            local ok, data = pcall(vim.fn.json_decode, json_str)
            if not ok or not data or not data.team or not data.team.nextEvent then
              safe_callback(default_result)
              return
            end

            local next_events = data.team.nextEvent
            if not next_events or #next_events == 0 then
              safe_callback(default_result)
              return
            end

            local next_event = next_events[1]
            if not next_event.competitions or #next_event.competitions == 0 then
              safe_callback(default_result)
              return
            end

            local comp = next_event.competitions[1]
            local status = comp.status
            local home_team, away_team
            
            for _, competitor in ipairs(comp.competitors) do
              if competitor.homeAway == "home" then
                home_team = competitor
              else
                away_team = competitor
              end
            end

            if not home_team or not away_team then
              safe_callback(default_result)
              return
            end

            local result_data = {
              team = team_info.espn_name,
              abbrev = team_info.abbrev,
              league = string.upper(team_info.league),
              home_team = home_team.team.abbreviation,
              away_team = away_team.team.abbreviation,
              home_score = tonumber(home_team.score) or 0,
              away_score = tonumber(away_team.score) or 0,
            }

            if status.type.state == "pre" then
              result_data.status = "upcoming"
              result_data.time = status.type.shortDetail or "Upcoming"
            elseif status.type.state == "in" then
              result_data.status = "live"
              result_data.time = status.type.shortDetail or "LIVE"
            else
              result_data.status = "final"
              result_data.time = "FINAL"
            end

            safe_callback(result_data)
          end)
        end)
      end)
    end,
  })
end

return M
