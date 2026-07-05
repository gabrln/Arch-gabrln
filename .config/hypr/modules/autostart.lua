-- =========================================================================
-- Inicialização Automática e Serviços (Módulo Lua)
-- =========================================================================

hl.on("hyprland.start", function()
	-- Prioridade máxima: iniciar o desktop shell (wallpaper, painel e notificações) imediatamente
	hl.exec_cmd("noctalia")

	-- Gerenciamento de plugins: verificação de estado e compilação condicional
	local handle = io.popen("hyprpm list 2>/dev/null")
	local plugins = handle:read("*a")
	handle:close()

	if not string.find(plugins, "scrolloverview") then
		hl.exec_cmd(
			"hyprpm update && hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git && hyprpm enable scrolloverview && hyprpm reload"
		)
	else
		hl.exec_cmd("hyprpm reload")
	end

	-- Serviços de chaves (chaveiro GNOME) - Polkit é gerido nativamente pelo Noctalia
	hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")

	-- Utilitários do sistema e clipboard
	hl.exec_cmd("wl-clip-persist --clipboard regular --reconnect-tries 0")
	hl.exec_cmd("wl-paste --watch cliphist store")
	hl.exec_cmd("flatpak run com.github.wwmm.easyeffects --gapplication-service")
end)
