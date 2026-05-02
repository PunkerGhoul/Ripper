package services

import (
	"fmt"

	"installer/internal/config"
	"installer/internal/system"
)

func EnsureLoginShell(cfg config.InstallConfig, apply bool) error {
	zshPath, err := system.LookPath("zsh")
	if err != nil {
		return fmt.Errorf("missing zsh in installer runtime")
	}

	currentShell, err := system.CurrentLoginShell(cfg.Username)
	if err != nil {
		return err
	}

	if currentShell == zshPath {
		fmt.Println("Login shell already set to", zshPath)
		return nil
	}

	if !apply {
		fmt.Printf("Login shell would be changed from %s to %s\n", currentShell, zshPath)
		return nil
	}

	if err := system.EnsureShellListed(zshPath); err != nil {
		return err
	}

	fmt.Println("Changing login shell to", zshPath)

	return system.ChangeLoginShell(cfg.Username, zshPath)
}