package app

import "installer/internal/config"

func runInit() error {
	_, err := config.EnsureInstallConfig()
	return err
}