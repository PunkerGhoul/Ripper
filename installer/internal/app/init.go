package app

import "ripper/installer/internal/config"

func runInit() error {
	_, err := config.EnsureInstallConfig()
	return err
}