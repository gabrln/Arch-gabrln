-- =========================================================================
-- Atalhos e Teclas de Atalho do Hyprland (Módulo Lua)
-- =========================================================================

local mod = "SUPER"

-- Função auxiliar para alternar scratchpad, abrindo se não estiver rodando
local function toggle_scratchpad(name, cmd)
    local windows = hl.get_windows({ class = name })
    if #windows == 0 then
        hl.exec_cmd(cmd)
        hl.exec_cmd("sleep 0.3")
        hl.exec_cmd("hyprctl dispatch togglespecialworkspace " .. name)
    else
        hl.exec_cmd("hyprctl dispatch togglespecialworkspace " .. name)
    end
end

-- Aplicações principais e ferramentas
hl.bind(mod .. " + T",      hl.dsp.exec_cmd("kitty")) -- Terminal padrão
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty")) -- Atalho fallback para terminal
hl.bind(mod .. " + B",      hl.dsp.exec_cmd("firefox"))
hl.bind(mod .. " + E",      hl.dsp.exec_cmd("kitty -e yazi"))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("nautilus"))
hl.bind(mod .. " + SHIFT + D", hl.dsp.exec_cmd("/home/gabrln/.config/hypr/scripts/WindowInfo.lua"))

-- Fechar janelas e gerenciamento de sessão
hl.bind(mod .. " + Q",         hl.dsp.window.close())
hl.bind("ALT + F4",            hl.dsp.exec_cmd("/home/gabrln/.config/hypr/scripts/AltF4.lua"))
hl.bind("CTRL + ALT + Delete", hl.dsp.exit())
hl.bind("CTRL + ALT + L",      hl.dsp.exec_cmd("noctalia msg session lock"))

-- Controles de interface do Noctalia
hl.bind(mod .. " + D",         hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))
hl.bind(mod .. " + V",         hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard"))
hl.bind(mod .. " + P",         hl.dsp.exec_cmd("noctalia msg panel-toggle control-center"))
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("noctalia msg panel-toggle session"))
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("noctalia msg panel-toggle control-center notifications"))
hl.bind(mod .. " + I",         hl.dsp.exec_cmd("noctalia msg settings-toggle"))
hl.bind(mod .. " + N",         hl.dsp.exec_cmd("noctalia msg nightlight-toggle"))
hl.bind(mod .. " + Y",         hl.dsp.exec_cmd("noctalia msg caffeine-toggle"))
hl.bind(mod .. " + W",         hl.dsp.exec_cmd("noctalia msg wallpaper-random"))
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("noctalia msg theme-mode-toggle")) -- Alternar tema Claro/Escuro (migrado do SHIFT+T)

-- Navegação de foco (Teclas Vim - H/L lateral, K/J para workspaces)
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + K", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + J", hl.dsp.focus({ workspace = "e+1" }))

-- Mover janelas (Teclas Vim - H/L lateral, K/J para workspaces)
hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + K", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ workspace = "e+1" }))

-- Redimensionamento, apresentação e grupos de janelas
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen())
hl.bind(mod .. " + M",         hl.dsp.layout("colresize toend")) -- Maximizar largura da coluna
hl.bind(mod .. " + C",         hl.dsp.window.center())
hl.bind(mod .. " + Space",     hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + ALT + Space", hl.dsp.window.pin({ action = "toggle" })) -- Fixar janela flutuante em todas workspaces
hl.bind(mod .. " + R",         hl.dsp.layout("colresize +conf")) -- Redimensionar coluna (próxima largura predefinida)
hl.bind(mod .. " + SHIFT + R", hl.dsp.layout("colresize -conf")) -- Redimensionar coluna (largura predefinida anterior)
hl.bind(mod .. " + G",           hl.dsp.exec_cmd("hyprctl dispatch togglegroup")) -- Criar/remover grupo (modo abas)
hl.bind(mod .. " + ALT + H",     hl.dsp.exec_cmd("hyprctl dispatch changegroupactive b")) -- Aba anterior no grupo
hl.bind(mod .. " + ALT + L",     hl.dsp.exec_cmd("hyprctl dispatch changegroupactive f")) -- Próxima aba no grupo

-- Redimensionar janela por pixels (Ctrl + Alt + Setas)
hl.bind("CTRL + ALT + Left",  hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
hl.bind("CTRL + ALT + Right", hl.dsp.window.resize({ x = 100,  y = 0, relative = true }))
hl.bind("CTRL + ALT + Up",    hl.dsp.window.resize({ x = 0,  y = -100, relative = true }))
hl.bind("CTRL + ALT + Down",  hl.dsp.window.resize({ x = 0,  y = 100, relative = true }))

-- Operações de colunas no layout scrolling
hl.bind(mod .. " + period",         hl.dsp.layout("+col"))
hl.bind(mod .. " + comma",          hl.dsp.layout("-col"))
hl.bind(mod .. " + SHIFT + period", hl.dsp.layout("swapnext"))
hl.bind(mod .. " + SHIFT + comma",  hl.dsp.layout("swapprev"))

-- Alternar workspaces e mover janelas (1 a 10)
for i = 1, 9 do
    hl.bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + 0",         hl.dsp.focus({ workspace = 10 }))
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Alternar workspaces via Tab/Scroll e ativar scrolloverview
local function toggle_overview()
    if hl.plugin and hl.plugin.scrolloverview then
        hl.plugin.scrolloverview.overview("toggle")
    else
        hl.exec_raw("toggleoverview", "")
    end
end

-- hl.bind(mod .. " + Tab", toggle_overview) -- Desativado: apenas ALT + Tab para overview
hl.bind(mod .. " + SHIFT + Tab",       hl.dsp.focus({ workspace = "e-1" }))
hl.bind("ALT + Tab",                   toggle_overview)
hl.bind(mod .. " + mouse_down",        hl.dsp.focus({ workspace = "e-1" }), { mouse = true })
hl.bind(mod .. " + mouse_up",          hl.dsp.focus({ workspace = "e+1" }), { mouse = true })
hl.bind(mod .. " + SHIFT + mouse_down", hl.dsp.window.move({ workspace = "e-1" }), { mouse = true })
hl.bind(mod .. " + SHIFT + mouse_up",   hl.dsp.window.move({ workspace = "e+1" }), { mouse = true })

-- Submap opcional para navegação avançada no scrolloverview
if hl.define_submap then
    hl.define_submap("scrolloverview", function()
        hl.bind("left",   function() if hl.plugin and hl.plugin.scrolloverview then hl.plugin.scrolloverview.navigate("left") end end)
        hl.bind("right",  function() if hl.plugin and hl.plugin.scrolloverview then hl.plugin.scrolloverview.navigate("right") end end)
        hl.bind("up",     function() if hl.plugin and hl.plugin.scrolloverview then hl.plugin.scrolloverview.navigate("up") end end)
        hl.bind("down",   function() if hl.plugin and hl.plugin.scrolloverview then hl.plugin.scrolloverview.navigate("down") end end)
        hl.bind("h",      function() if hl.plugin and hl.plugin.scrolloverview then hl.plugin.scrolloverview.navigate("left") end end)
        hl.bind("l",      function() if hl.plugin and hl.plugin.scrolloverview then hl.plugin.scrolloverview.navigate("right") end end)
        hl.bind("k",      function() if hl.plugin and hl.plugin.scrolloverview then hl.plugin.scrolloverview.navigate("up") end end)
        hl.bind("j",      function() if hl.plugin and hl.plugin.scrolloverview then hl.plugin.scrolloverview.navigate("down") end end)

        -- Fechar overview ao acionar novamente apenas com ALT + Tab
        hl.bind("ALT + Tab", toggle_overview)
        hl.bind("return", function() if hl.plugin and hl.plugin.scrolloverview then hl.plugin.scrolloverview.overview("select") end end)
        hl.bind("escape", function() if hl.plugin and hl.plugin.scrolloverview then hl.plugin.scrolloverview.overview("off") end end)

        -- Navegação lateral com scroll de mouse sem SUPER quando overview está ativo
        hl.bind("mouse_down", function() if hl.plugin and hl.plugin.scrolloverview then hl.plugin.scrolloverview.navigate("right") end end, { mouse = true })
        hl.bind("mouse_up",   function() if hl.plugin and hl.plugin.scrolloverview then hl.plugin.scrolloverview.navigate("left") end end, { mouse = true })

        hl.bind("mouse:272", function()
            if hl.plugin and hl.plugin.scrolloverview then
                hl.plugin.scrolloverview.overview("select")
                hl.plugin.scrolloverview.window("select")
                hl.plugin.scrolloverview.overview("off")
            end
        end, { mouse = true })
        hl.bind("mouse:274", function() if hl.plugin and hl.plugin.scrolloverview then hl.plugin.scrolloverview.window("close") end end, { mouse = true })
    end)
end

-- Mover e redimensionar janelas pelo mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Scratchpads (Workspaces Especiais)
hl.bind(mod .. " + SHIFT + T",      function() toggle_scratchpad("kitty-drop", "kitty --class kitty-drop") end) -- Terminal suspenso/scratchpad
hl.bind(mod .. " + SHIFT + Return", function() toggle_scratchpad("kitty-drop", "kitty --class kitty-drop") end) -- Atalho fallback para terminal suspenso
hl.bind(mod .. " + F1",             function() toggle_scratchpad("btop-scratch", "kitty --class btop-scratch -e btop") end)
hl.bind(mod .. " + Slash",          function() toggle_scratchpad("keyhints-scratch", "kitty --class keyhints-scratch -e /home/gabrln/.config/hypr/scripts/KeyHints.lua") end)

-- Teclas multimídia, hardware e volume
hl.bind("XF86AudioRaiseVolume",    hl.dsp.exec_cmd("noctalia msg volume-up"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",    hl.dsp.exec_cmd("noctalia msg volume-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",           hl.dsp.exec_cmd("noctalia msg volume-mute"), { locked = true })
hl.bind("XF86AudioMicMute",        hl.dsp.exec_cmd("noctalia msg mic-mute"),    { locked = true })
hl.bind(mod .. " + SHIFT + M",     hl.dsp.exec_cmd("noctalia msg mic-mute"),    { locked = true })
hl.bind("XF86MonBrightnessUp",     hl.dsp.exec_cmd("noctalia msg brightness-up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",   hl.dsp.exec_cmd("noctalia msg brightness-down"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay",           hl.dsp.exec_cmd("noctalia msg media toggle"),    { locked = true })
hl.bind("XF86AudioPause",          hl.dsp.exec_cmd("noctalia msg media toggle"),    { locked = true })
hl.bind("XF86MediaPlayPause",      hl.dsp.exec_cmd("noctalia msg media toggle"),    { locked = true })
hl.bind("XF86AudioNext",           hl.dsp.exec_cmd("noctalia msg media next"),        { locked = true })
hl.bind("XF86AudioPrev",           hl.dsp.exec_cmd("noctalia msg media previous"),    { locked = true })
hl.bind("XF86AudioStop",           hl.dsp.exec_cmd("noctalia msg media stop"),        { locked = true })
hl.bind("CTRL + " .. mod .. " + Space", hl.dsp.exec_cmd("noctalia msg media toggle"), { locked = true })
hl.bind(mod .. " + ALT + N",       hl.dsp.exec_cmd("noctalia msg media next"),        { locked = true })
hl.bind(mod .. " + ALT + P",       hl.dsp.exec_cmd("noctalia msg media previous"),    { locked = true })

-- Capturas de tela (Screenshots)
hl.bind("Print",               hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen"))
hl.bind(mod .. " + Print",       hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen"))
hl.bind(mod .. " + SHIFT + Print", hl.dsp.exec_cmd("noctalia msg screenshot-region"))
hl.bind("ALT + Print",         hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen pick"))
