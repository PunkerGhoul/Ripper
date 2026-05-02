package display

import (
	"fmt"

	"installer/internal/system"
)

// EnsureDisplayManagerPackages instala paquetes requeridos según distro.
// Devuelve estado semántico.
func EnsureDisplayManagerPackages(distro string, apply bool) (string, error) {
	sudoPath, err := system.ResolveCommand("sudo", "/usr/bin/sudo", "/bin/sudo")
	if err != nil {
		return "", err
	}

	switch distro {
	case "debian":
		aptPath, err := system.ResolveCommand("apt", "/usr/bin/apt", "/bin/apt")
		if err != nil {
			return "", err
		}

		if !apply {
			return "would_install_debian", nil
		}

		if err := system.RunInteractive(sudoPath, aptPath, "update", "-y"); err != nil {
			return "", fmt.Errorf("apt update failed: %w", err)
		}

		if err := system.RunInteractive(sudoPath, aptPath, "install", "-y",
			"sddm",
			"xorg",
			"dbus-x11",
		); err != nil {
			return "", err
		}

		return "installed_debian", nil

	case "arch":
		pacmanPath, err := system.ResolveCommand("pacman", "/usr/bin/pacman", "/bin/pacman")
		if err != nil {
			return "", err
		}

		if !apply {
			return "would_install_arch", nil
		}

		if err := system.RunInteractive(sudoPath, pacmanPath, "-Syu", "--needed", "--noconfirm",
			"sddm",
			"xorg-server",
			"xorg-xauth",
			"dbus",
		); err != nil {
			return "", err
		}

		return "installed_arch", nil

	default:
		return "", fmt.Errorf(
			"unsupported distro %q; install sddm and xorg-server manually",
			distro,
		)
	}
}