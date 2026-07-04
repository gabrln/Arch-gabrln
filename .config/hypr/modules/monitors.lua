-- =========================================================================
-- Monitores e Workspaces do Hyprland (Módulo Lua)
-- =========================================================================

-- Tela principal do notebook
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})
-- Monitor externo genérico / hotplug
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- Workspaces fixas (1 a 10)
for i = 1, 10 do
    hl.workspace_rule({
        workspace  = tostring(i),
        persistent = true,
    })
end
