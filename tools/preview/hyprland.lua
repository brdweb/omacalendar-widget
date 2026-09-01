hl.monitor({ output = "", mode = "800x800@60", position = "0x0", scale = 1 })

hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
    border_size = 0,
  },
  decoration = {
    rounding = 0,
    shadow = {
      enabled = false,
    },
    blur = {
      enabled = false,
    },
  },
  animations = {
    enabled = false,
  },
  cursor = {
    invisible = true,
  },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    disable_watchdog_warning = true,
    force_default_wallpaper = 0,
  },
  debug = {
    suppress_errors = true,
  },
})
