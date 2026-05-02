package app

import (
	"installer/internal/config"
	"installer/internal/services"
	"installer/internal/services/homemanager"
	"installer/internal/ui"
)

func runSwitch() error {
	cfg, err := config.EnsureInstallConfig()
	if err != nil {
		return err
	}
	ui.PrintDoctor(cfg)
	if err := services.EnsureLoginShell(cfg, true); err != nil {
		return err
	}
	if err := services.EnsureI3lockPam(cfg, true); err != nil {
		return err
	}
	if _, err := services.EnsurePowerPolkitRule(cfg, true); err != nil {
		return err
	}
	if err := services.EnsurePowermanagerSudoersAndGroup(cfg, true); err != nil {
		return err
	}
	if _, err := homemanager.Run(cfg, true); err != nil {
		return err
	}
	if _, err := services.EnsureDisplayManager(cfg, true); err != nil {
		return err
	}
	return nil
}