package services

import "installer/internal/config"

func RunDoctor(cfg config.InstallConfig) error {
	if err := EnsureLoginShell(cfg, false); err != nil {
		return err
	}
	if err := EnsureI3lockPam(cfg, false); err != nil {
		return err
	}
	if err := EnsurePowerPolkitRule(cfg, false); err != nil {
		return err
	}
	if err := EnsurePowermanagerSudoersAndGroup(cfg, false); err != nil {
		return err
	}
	return EnsureDisplayManager(cfg, false)
}