package app

import (
	"installer/internal/config"
	"installer/internal/services"
	"installer/internal/ui"
)

func runDoctor() error {
	cfg, err := config.EnsureInstallConfig()
	if err != nil {
		return err
	}

	ui.PrintDoctor(cfg)

	return services.RunDoctor(cfg)
}