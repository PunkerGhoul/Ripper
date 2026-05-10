package display

import (
	"fmt"
	"strings"

	"ripper/installer/internal/config"
	"ripper/installer/internal/system"
)

// EnsureDisplayManager orquesta la configuración completa de SDDM
func EnsureDisplayManager(cfg config.InstallConfig, apply bool) (map[string]string, error) {
	result := map[string]string{}

	// --- detección ---
	missing := system.MissingPaths("/usr/bin/sddm")
	needsInstall := len(missing) > 0

	if cfg.Distro == "debian" {
		ok, _ := system.IsDebianPackageInstalled("sddm")
		if !ok {
			missing = append(missing, "package:sddm")
			needsInstall = true
		}
	}

	// --- paquetes (siempre ejecutar para asegurar polkit) ---
	state, err := EnsureDisplayManagerPackages(cfg.Distro, apply)
	if err != nil {
		return nil, err
	}
	if needsInstall {
		result["packages"] = state + ":" + strings.Join(missing, ",")
	} else {
		result["packages"] = state + ":polkit_ensured"
	}

	// --- hardening rootless Xorg ---
	rootlessState, err := EnsureXorgRootlessConfig(apply)
	if err != nil {
		return nil, fmt.Errorf("ensure rootless xorg: %w", err)
	}
	result["xorg_rootless"] = rootlessState

	// --- sesión ---
	sessionState, err := EnsureRipperSession(apply)
	if err != nil {
		return nil, err
	}
	result["session"] = sessionState

	// --- config ---
	configState, err := EnsureSddmConfig(cfg, apply)
	if err != nil {
		return nil, err
	}
	result["config"] = configState

	// --- enable ---
	enableState, err := EnsureSddmEnabled(apply)
	if err != nil {
		return nil, err
	}
	result["enabled"] = enableState

	return result, nil
}

// EnsureRipperSession asegura que exista la sesión y el script de arranque
func EnsureRipperSession(apply bool) (string, error) {
		const scriptPath = "/usr/local/bin/ripper-session"
		const desktopPath = "/usr/share/xsessions/ripper.desktop"
		script := `#!/bin/sh
# Managed by Ripper.
for profile in \
	"$HOME/.nix-profile" \
	"$HOME/.local/state/nix/profiles/profile" \
	"/etc/profiles/per-user/$USER"; do
	if [ -r "$profile/etc/profile.d/hm-session-vars.sh" ]; then
		. "$profile/etc/profile.d/hm-session-vars.sh"
	fi
	if [ -d "$profile/bin" ]; then
		PATH="$profile/bin:$PATH"
	fi
	if [ -d "$profile/share" ]; then
		XDG_DATA_DIRS="$profile/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
	fi
done

export PATH
export XDG_DATA_DIRS

export XDG_CURRENT_DESKTOP=i3
export XDG_SESSION_DESKTOP=ripper
export DESKTOP_SESSION=ripper

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
	dbus-update-activation-environment --systemd DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP DESKTOP_SESSION
fi

if [ ! -x "$HOME/.local/bin/ripper-session-start" ]; then
	echo "Ripper session: missing Home Manager launcher: $HOME/.local/bin/ripper-session-start" >&2
	exit 127
fi

exec "$HOME/.local/bin/ripper-session-start"
`
		desktop := `[Desktop Entry]
Name=Ripper
Comment=Ripper i3 session
Exec=/usr/local/bin/ripper-session
TryExec=/usr/local/bin/ripper-session
Type=Application
DesktopNames=i3;Ripper
`

		if system.FileHasContent(scriptPath, script) && system.FileHasContent(desktopPath, desktop) {
				return "already_configured", nil
		}
		if !apply {
				return "would_write", nil
		}
		if err := system.WriteRootFile(scriptPath, script, "0755"); err != nil {
				return "", err
		}
		if err := system.WriteRootFile(desktopPath, desktop, "0644"); err != nil {
				return "", err
		}
		return "written", nil
}