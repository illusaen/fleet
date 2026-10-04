local ui = require("noctalia.ui")
local sysmon = require("noctalia.sysmon")
local theme = noctalia.getConfig("theme")

-- State persistence for animations/re-renders
local state = {
    show_extended = false
}

-- Format bytes into a readable string
local function format_gb(bytes)
    return string.format("%.1f GB", bytes / (1024^3))
end

function update()
    -- Request fast ticks for the second-hand clock
    desktopWidget.setWantsSecondTicks(true)

    -- Fetch latest system statistics
    local cpu_usage = sysmon.getCpuUsage()
    local ram = sysmon.getMemoryInfo() -- Returns { total, used, free }
    
    -- Build the layout tree
    desktopWidget.render(ui.column({ 
        gap = 16, 
        align = "stretch",
        padding = 20,
        backgroundColor = theme.colors.surface,
        borderRadius = 12
    }, {
        -- Section 1: Clock & Date
        ui.column({ align = "center", gap = 4 }, {
            ui.label({ 
                text = os.date("%H:%M:%S"), 
                fontSize = 36, 
                fontWeight = "bold", 
                color = theme.colors.text 
            }),
            ui.label({ 
                text = os.date("%A, %B %d"), 
                fontSize = 14, 
                color = theme.colors.textMuted 
            }),
        }),

        -- Divider
        ui.divider({ color = theme.colors.border }),

        -- Section 2: System Stats
        ui.column({ gap = 12 }, {
            -- CPU Stat
            ui.column({ gap = 4 }, {
                ui.row({ justify = "space-between" }, {
                    ui.label({ text = "CPU Usage", fontSize = 13, fontWeight = "medium" }),
                    ui.label({ text = string.format("%d%%", cpu_usage * 100), fontSize = 13 }),
                }),
                ui.progressBar({ value = cpu_usage, color = theme.colors.accent })
            }),

            -- RAM Stat
            ui.column({ gap = 4 }, {
                ui.row({ justify = "space-between" }, {
                    ui.label({ text = "Memory", fontSize = 13, fontWeight = "medium" }),
                    ui.label({ text = format_gb(ram.used) .. " / " .. format_gb(ram.total), fontSize = 12, color = theme.colors.textMuted }),
                }),
                ui.progressBar({ value = ram.used / ram.total, color = theme.colors.success or theme.colors.accent })
            }),
        }),

        -- Conditional Extended Metrics
        state.show_extended and ui.column({ gap = 4 }, {
            ui.row({ justify = "space-between" }, {
                ui.label({ text = "Free Memory:", fontSize = 12, color = theme.colors.textMuted }),
                ui.label({ text = format_gb(ram.free), fontSize = 12 }),
            })
        }) or nil,

        -- Divider
        ui.divider({ color = theme.colors.border }),

        -- Section 3: Custom Action Buttons
        ui.row({ gap = 8, justify = "space-between" }, {
            ui.button({ 
                text = state.show_extended and "Less" or "More", 
                variant = "secondary", 
                onClick = "toggle_details",
                flex = 1
            }),
            ui.button({ 
                text = "DP", 
                variant = "danger", 
                onClick = "switch_dp",
                flex = 1
            }),
            ui.button({ 
                text = "HD", 
                variant = "danger", 
                onClick = "switch_hd",
                flex = 1
            }),
        })
    }))
end

-- Callback Actions
function toggle_details()
    state.show_extended = not state.show_extended
    update() -- Force an immediate visual refresh
end

function switch_hd()
    noctalia.exec("switcher hdmi1") 
end

function switch_hd()
    noctalia.exec("switcher dp") 
end
