package homemanager

import (
	"errors"
	"fmt"
	"os"

	"ripper/installer/internal/config"
	"ripper/installer/internal/system"
)

// Run aplica el switch de Home Manager
func Run(cfg config.InstallConfig, apply bool) (string, error) {
	repoRoot, err := config.RepoRoot()
	if err != nil {
		return "", err
	}

	homeManager := os.Getenv("RIPPER_HOME_MANAGER_BIN")

	if homeManager == "" {
		path, err := system.ResolveCommand("home-manager")
		if err != nil {
			return "", errors.New("missing home-manager; run through `nix run .`")
		}
		homeManager = path
	}

	args := []string{
		"switch",
		"--flake", "path:" + repoRoot + "#ripper",
		"-b", "backup",
	}

	if !apply {
		return "would_run", nil
	}

	if err := system.RunInteractive(homeManager, args...); err != nil {
		return "", fmt.Errorf("home-manager switch failed: %w", err)
	}

	return "applied", nil
}