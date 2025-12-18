```lua
   -- Topbar plugin
  {
    "StephenCole19/nvim-scoreboard",
    config = function()
      require("topbar").setup({
        visible = true,
        show_sports = true,
        teams = {
          "Green Bay Packers",
          "Toronto Maple Leafs"
        },
        refresh_interval = 60,
      })
    end,
  }
```

<img width="1510" height="582" alt="Screenshot 2025-12-18 at 12 06 58 PM" src="https://github.com/user-attachments/assets/756480b5-caed-4afa-8e76-c2cd3f5eb8c5" />
