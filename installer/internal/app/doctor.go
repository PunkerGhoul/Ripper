package app

import (
	"ripper/installer/internal/config"
	"ripper/installer/internal/services"
	"ripper/installer/internal/ui"
)

func runDoctor() error {
	cfg, err := config.EnsureInstallConfig()
	if err != nil {
		return err
	}

	ui.PrintDoctor(cfg)

	return services.RunDoctor(cfg)
}