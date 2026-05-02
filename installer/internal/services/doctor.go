package services

import "ripper/installer/internal/config"

func RunDoctor(cfg config.InstallConfig) error {
	if err := EnsureLoginShell(cfg, false); err != nil {
		return err
	}
	if err := EnsureI3lockPam(cfg, false); err != nil {
		return err
	}
	if _, err := EnsurePowerPolkitRule(cfg, false); err != nil {
		return err
	}
	if err := EnsurePowermanagerSudoersAndGroup(cfg, false); err != nil {
		return err
	}
	if _, err := EnsureDisplayManager(cfg, false); err != nil {
		return err
	}
	return nil
}