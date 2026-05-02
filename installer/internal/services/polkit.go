package services

import (
	"errors"
	"fmt"
	"os"
	"strings"

	"installer/internal/config"
	"installer/internal/system"
)

const polkitRulePath = "/etc/polkit-1/rules.d/49-ripper-power.rules"

// EnsurePowerPolkitRule asegura que la regla de polkit exista y esté en el estado esperado.
// No imprime nada. Devuelve estado semántico para que la capa app decida.
func EnsurePowerPolkitRule(cfg config.InstallConfig, apply bool) (string, error) {
	expected := renderPowerPolkitRule(cfg.Username)

	current, err := os.ReadFile(polkitRulePath)
	if err == nil {
		currentStr := strings.TrimSpace(string(current))
		expectedStr := strings.TrimSpace(expected)

		// Ya está exactamente como queremos
		if currentStr == expectedStr {
			return "already_configured", nil
		}

		// Existe pero no es nuestro → no tocar
		if len(current) > 0 && !strings.Contains(currentStr, "Managed by Ripper") {
			return "skipped_foreign_file", nil
		}
	}

	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return "", fmt.Errorf("read %s: %w", polkitRulePath, err)
	}

	// Modo dry-run
	if !apply {
		return "would_write", nil
	}

	// Aplicar cambio
	if err := system.WriteRootFile(polkitRulePath, expected, "0644"); err != nil {
		return "", err
	}

	return "written", nil
}

// renderPowerPolkitRule genera el contenido de la regla.
// Función pura.
func renderPowerPolkitRule(username string) string {
	return fmt.Sprintf(`// Managed by Ripper.
polkit.addRule(function(action, subject) {
  var actions = [
    "org.freedesktop.login1.power-off",
    "org.freedesktop.login1.power-off-multiple-sessions",
    "org.freedesktop.login1.power-off-ignore-inhibit",
    "org.freedesktop.login1.reboot",
    "org.freedesktop.login1.reboot-multiple-sessions",
    "org.freedesktop.login1.reboot-ignore-inhibit",
    "org.freedesktop.login1.suspend",
    "org.freedesktop.login1.suspend-multiple-sessions",
    "org.freedesktop.login1.suspend-ignore-inhibit",
    "org.freedesktop.login1.hibernate",
    "org.freedesktop.login1.hibernate-multiple-sessions",
    "org.freedesktop.login1.hibernate-ignore-inhibit",
    "org.freedesktop.login1.hybrid-sleep",
    "org.freedesktop.login1.hybrid-sleep-multiple-sessions",
    "org.freedesktop.login1.hybrid-sleep-ignore-inhibit",
    "org.freedesktop.login1.suspend-then-hibernate",
    "org.freedesktop.login1.suspend-then-hibernate-multiple-sessions",
    "org.freedesktop.login1.suspend-then-hibernate-ignore-inhibit"
  ];

  if (subject.user == %q && actions.indexOf(action.id) >= 0) {
    return polkit.Result.YES;
  }
});
`, username)
}