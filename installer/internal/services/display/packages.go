package display

import (
	"fmt"

	"ripper/installer/internal/system"
)

// EnsureDisplayManagerPackages instala y asegura paquetes requeridos según distro.
// Siempre asegura que polkit esté instalado y habilitado.
func EnsureDisplayManagerPackages(distro string, apply bool) (string, error) {
	switch distro {
	case "debian":
		return ensureDisplayManagerPackagesDebian(apply)
	case "arch":
		return ensureDisplayManagerPackagesArch(apply)
	default:
		return "", fmt.Errorf(
			"unsupported distro %q; install sddm and xorg-server manually",
			distro,
		)
	}
}

func ensureDisplayManagerPackagesDebian(apply bool) (string, error) {
	sudoPath, err := system.ResolveCommand("sudo", "/usr/bin/sudo", "/bin/sudo")
	if err != nil {
		return "", err
	}

	aptPath, err := system.ResolveCommand("apt", "/usr/bin/apt", "/bin/apt")
	if err != nil {
		return "", err
	}

	systemctlPath, err := system.ResolveCommand("systemctl", "/usr/bin/systemctl", "/bin/systemctl")
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
		"polkit",
		"xorg",
		"dbus-x11",
	); err != nil {
		return "", err
	}

	if err := startPolkitService(sudoPath, systemctlPath); err != nil {
		return "", err
	}

	return "configured_debian", nil
}

func ensureDisplayManagerPackagesArch(apply bool) (string, error) {
	sudoPath, err := system.ResolveCommand("sudo", "/usr/bin/sudo", "/bin/sudo")
	if err != nil {
		return "", err
	}

	pacmanPath, err := system.ResolveCommand("pacman", "/usr/bin/pacman", "/bin/pacman")
	if err != nil {
		return "", err
	}

	systemctlPath, err := system.ResolveCommand("systemctl", "/usr/bin/systemctl", "/bin/systemctl")
	if err != nil {
		return "", err
	}

	if !apply {
		return "would_install_arch", nil
	}

	if err := system.RunInteractive(sudoPath, pacmanPath, "-Syu", "--needed", "--noconfirm",
		"sddm",
		"polkit",
		"xorg-server",
		"xorg-xauth",
		"dbus",
	); err != nil {
		return "", err
	}

	if err := startPolkitService(sudoPath, systemctlPath); err != nil {
		return "", err
	}

	return "configured_arch", nil
}

func startPolkitService(sudoPath, systemctlPath string) error {
	if err := system.RunInteractive(sudoPath, systemctlPath, "start", "polkit"); err != nil {
		return fmt.Errorf("start polkit.service failed: %w", err)
	}

	return nil
}