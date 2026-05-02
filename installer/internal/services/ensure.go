package services

import (
	"ripper/installer/internal/config"
	"ripper/installer/internal/services/display"
	"ripper/installer/internal/services/powermanager"
)

func EnsureDisplayManager(cfg config.InstallConfig, apply bool) (map[string]string, error) {
	return display.EnsureDisplayManager(cfg, apply)
}

func EnsurePowermanagerSudoersAndGroup(cfg config.InstallConfig, apply bool) error {
	return powermanager.Ensure(cfg, apply)
}