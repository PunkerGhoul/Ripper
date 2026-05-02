package display

import (
	"strings"

	"ripper/installer/internal/config"
	"ripper/installer/internal/system"
)

// EnsureDisplayManager orquesta todo el setup de SDDM
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

	// --- paquetes ---
	if needsInstall {
		state, err := EnsureDisplayManagerPackages(cfg.Distro, apply)
		if err != nil {
			return nil, err
		}
		result["packages"] = state + ":" + strings.Join(missing, ",")
	} else {
		result["packages"] = "already_installed"
	}

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