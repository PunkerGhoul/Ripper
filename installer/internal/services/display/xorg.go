package display

import (
	"errors"
	"fmt"
	"os"
	"strings"

	"ripper/installer/internal/system"
)

const xwrapperConfigPath = "/etc/X11/Xwrapper.config"

func EnsureXorgRootlessConfig(apply bool) (string, error) {
	expected := strings.TrimSpace(`allowed_users=console
needs_root_rights=no
`) + "\n"

	current, err := os.ReadFile(xwrapperConfigPath)
	if err == nil {
		if strings.TrimSpace(string(current)) == strings.TrimSpace(expected) {
			return "already_configured", nil
		}
	}

	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return "", fmt.Errorf("read %s: %w", xwrapperConfigPath, err)
	}

	if !apply {
		return "would_write", nil
	}

	if err := system.WriteRootFile(xwrapperConfigPath, expected, "0644"); err != nil {
		return "", err
	}

	return "written", nil
}
