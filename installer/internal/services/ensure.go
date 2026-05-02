package services

import (
	"installer/internal/config"
	"installer/internal/services/display"
	"installer/internal/services/powermanager"
)

func EnsureDisplayManager(cfg config.InstallConfig, apply bool) (map[string]string, error) {
	return display.EnsureDisplayManager(cfg, apply)
}

func EnsurePowermanagerSudoersAndGroup(cfg config.InstallConfig, apply bool) error {
	return powermanager.Ensure(cfg, apply)
}