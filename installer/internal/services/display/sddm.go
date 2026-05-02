package display

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"ripper/installer/internal/config"
	"ripper/installer/internal/system"
	"ripper/installer/internal/util"
)

const sddmConfigPath = "/etc/sddm.conf.d/99-ripper.conf"

// EnsureSddmConfig asegura el archivo de configuración
func EnsureSddmConfig(cfg config.InstallConfig, apply bool) (string, error) {
	config := renderSddmConfig(cfg.Username)

	current, err := os.ReadFile(sddmConfigPath)
	if err == nil {
		if strings.TrimSpace(string(current)) == strings.TrimSpace(config) {
			return "already_configured", nil
		}
	}

	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return "", fmt.Errorf("read %s: %w", sddmConfigPath, err)
	}

	if !apply {
		return "would_write", nil
	}

	if err := system.WriteRootFile(sddmConfigPath, config, "0644"); err != nil {
		return "", err
	}

	return "written", nil
}

// EnsureSddmEnabled asegura que el servicio esté habilitado
func EnsureSddmEnabled(apply bool) (string, error) {
	systemctlPath, err := system.ResolveCommand("systemctl", "/usr/bin/systemctl", "/bin/systemctl")
	if err != nil {
		return "", err
	}

	// ya está habilitado
	if err := execCommand(systemctlPath, "is-enabled", "--quiet", "sddm.service"); err == nil {
		return "already_enabled", nil
	}

	if !apply {
		return "would_enable", nil
	}

	sudoPath, err := system.ResolveCommand("sudo", "/usr/bin/sudo", "/bin/sudo")
	if err != nil {
		return "", err
	}

	if err := system.RunInteractive(sudoPath, systemctlPath, "enable", "--force", "sddm.service"); err != nil {
		return "", fmt.Errorf("enable sddm.service failed: %w", err)
	}

	if err := system.RunInteractive(sudoPath, systemctlPath, "set-default", "graphical.target"); err != nil {
		return "", fmt.Errorf("set graphical.target failed: %w", err)
	}

	return "enabled", nil
}

// --- helpers privados ---

func renderSddmConfig(loginUser string) string {
	return fmt.Sprintf(`[General]
DisplayServer=x11

[Autologin]
Relogin=false
Session=
User=

[Users]
MinimumUid=1000
MaximumUid=29999
HideShells=/usr/sbin/nologin,/usr/bin/nologin,/sbin/nologin,/bin/false
HideUsers=%s
RememberLastUser=false
RememberLastSession=false
`, strings.Join(sddmHiddenUsers(loginUser), ","))
}

func sddmHiddenUsers(loginUser string) []string {
	hidden := []string{"root", "nobody"}

	data, err := os.ReadFile("/etc/passwd")
	if err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			fields := strings.Split(line, ":")
			if len(fields) < 3 {
				continue
			}

			name := fields[0]
			if name == "" || name == loginUser {
				continue
			}

			if strings.HasPrefix(name, "nixbld") {
				hidden = append(hidden, name)
			}
		}
	}

	return util.UniqueStrings(hidden)
}

// pequeño wrapper para mantener consistencia
func execCommand(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	return cmd.Run()
}