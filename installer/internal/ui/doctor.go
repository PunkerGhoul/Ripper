package ui

import (
	"fmt"

	"ripper/installer/internal/config"
)

func PrintDoctor(cfg config.InstallConfig) {
	if cfg.Existing {
		fmt.Printf("Ripper profile: using existing declaration %s\n", cfg.ConfigPath)
		fmt.Println("Power actions: installer will manage polkit and power rules during switch")
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
	fmt.Println("Power actions: installer will manage polkit and power rules during switch")
}