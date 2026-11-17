-- macish · tema Segnale — per Hyprland 0.55+ con configurazione Lua.
-- L'installer aggiunge  require("macish")  in fondo a ~/.config/hypr/hyprland.lua

hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 10,
    border_size = 1,
    ["col.active_border"] = "rgba(ffffff99)",   
    ["col.inactive_border"] = "rgba(80808033)",
  },
  decoration = {
    rounding = 12,
    rounding_power = 3,
    shadow = { enabled = true, range = 28, render_power = 3, offset = "0 8", color = "rgba(00000055)" },
    blur = { enabled = false },   -- Segnale: superfici piene, niente vetro
  },
})

hl.on("hyprland.start", function()
  hl.exec_cmd("qs -c macish")
end)

local qs = "qs -c macish ipc call "

-- Launcher, pannello rapido, tema scuro/chiaro
hl.unbind("SUPER + Space")
hl.bind("SUPER + Space", hl.dsp.exec_cmd(qs .. "launcher toggle"))
hl.bind("SUPER + CTRL + C", hl.dsp.exec_cmd(qs .. "cc toggle"))
hl.bind("SUPER + CTRL + A", hl.dsp.exec_cmd(qs .. "agenti toggle"))
hl.bind("SUPER + CTRL + M", hl.dsp.exec_cmd(qs .. "notifiche toggle"))
hl.bind("SUPER + CTRL + N", hl.dsp.exec_cmd([[sh -c 'case "$(gsettings get org.gnome.desktop.interface color-scheme)" in *dark*) s=prefer-light;; *) s=prefer-dark;; esac; gsettings set org.gnome.desktop.interface color-scheme $s']]))

-- Tasti multimediali: l'OSD di Segnale
for _, k in ipairs({ "XF86AudioRaiseVolume", "XF86AudioLowerVolume", "XF86AudioMute",
                     "XF86AudioMicMute", "XF86MonBrightnessUp", "XF86MonBrightnessDown" }) do
  hl.unbind(k)
end
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true, locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("sh -c 'brightnessctl -q set 5%+ && " .. qs .. "osd brightness'"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("sh -c 'brightnessctl -q set 5%- && " .. qs .. "osd brightness'"), { repeating = true, locked = true })
