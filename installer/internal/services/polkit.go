package services

import (
	"errors"
	"fmt"
	"os"
	"strings"

	"ripper/installer/internal/config"
	"ripper/installer/internal/system"
)

const polkitRulePath = "/etc/polkit-1/rules.d/49-ripper-power.rules"

type polkitRuleState string

const (
	polkitRuleStateAlreadyConfigured polkitRuleState = "already_configured"
	polkitRuleStateSkippedForeign    polkitRuleState = "skipped_foreign_file"
	polkitRuleStateUnreadable        polkitRuleState = "unreadable"
	polkitRuleStateWouldWrite        polkitRuleState = "would_write"
	polkitRuleStateWouldWriteUnreadable polkitRuleState = "would_write_unreadable"
	polkitRuleStateWritten           polkitRuleState = "written"
)

// EnsurePowerPolkitRule asegura que la regla de polkit exista y esté en el estado esperado.
// No imprime nada. Devuelve estado semántico para que la capa app decida.
func EnsurePowerPolkitRule(cfg config.InstallConfig, apply bool) (string, error) {
	expected := renderPowerPolkitRule(cfg.Username)

	state, err := detectPolkitRuleState(expected)
	if err != nil {
		return "", err
	}

	switch state {
	case polkitRuleStateAlreadyConfigured:
		return string(state), nil
	case polkitRuleStateSkippedForeign:
		return string(state), nil
	case polkitRuleStateUnreadable:
		if !apply {
			return string(polkitRuleStateWouldWriteUnreadable), nil
		}
		return writePolkitRule(expected)
	default:
		if !apply {
			return string(polkitRuleStateWouldWrite), nil
		}
		return writePolkitRule(expected)
	}
}

func detectPolkitRuleState(expected string) (polkitRuleState, error) {
	current, err := os.ReadFile(polkitRulePath)
	if err != nil {
		if errors.Is(err, os.ErrPermission) {
			return polkitRuleStateUnreadable, nil
		}
		if errors.Is(err, os.ErrNotExist) {
			return "", nil
		}
		return "", fmt.Errorf("read %s: %w", polkitRulePath, err)
	}

	currentStr := strings.TrimSpace(string(current))
	expectedStr := strings.TrimSpace(expected)

	if currentStr == expectedStr {
		return polkitRuleStateAlreadyConfigured, nil
	}

	if len(current) > 0 && !strings.Contains(currentStr, "Managed by Ripper") {
		return polkitRuleStateSkippedForeign, nil
	}

	return "", nil
}

func writePolkitRule(expected string) (string, error) {
	if err := system.WriteRootFile(polkitRulePath, expected, "0644"); err != nil {
		return "", err
	}

	return string(polkitRuleStateWritten), nil
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