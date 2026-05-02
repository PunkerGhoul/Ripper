package ui

import (
	"fmt"

	"installer/internal/config"
)

func PrintDoctor(cfg config.InstallConfig) {
	if cfg.Existing {
		fmt.Printf("Ripper profile: using existing declaration %s\n", cfg.ConfigPath)
		return
	}

	fmt.Printf(
		"Ripper profile: user=%s home=%s system=%s distro=%s gpu=%s\n",
		cfg.Username,
		cfg.HomeDirectory,
		cfg.System,
		cfg.Distro,
		cfg.GPUWrapper,
	)
}