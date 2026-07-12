-- =========================================================================
-- Hyprland animations and bezier curves (Lua module)
-- =========================================================================

hl.config({ animations = { enabled = true } })

-- CSS ease: cubic-bezier(0.25, 0.1, 0.25, 1.0)
hl.curve("ease", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1.0 } } })

-- Todas as animacoes: rapidas (speed=20 ~150ms), mesma curva ease
-- Estilos variam por folha: fade onde suportado, none/minimal para as demais
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 20, bezier = "ease" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 20, bezier = "ease" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 20, bezier = "ease" })
hl.animation({ leaf = "border",           enabled = true, speed = 20, bezier = "ease" })
hl.animation({ leaf = "fade",             enabled = true, speed = 20, bezier = "ease" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 20, bezier = "ease", style = "fade" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 20, bezier = "ease", style = "fade" })
hl.animation({ leaf = "layersIn",         enabled = true, speed = 20, bezier = "ease", style = "fade" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 20, bezier = "ease", style = "fade" })
