package services

import (
	"fmt"

	"installer/internal/config"
	"installer/internal/system"
)

func pamConfig(distro string) string {
	if distro == "arch" {
		return `# Managed by Ripper.
auth include system-auth
account include system-auth
password include system-auth
session include system-auth
`
	}
	return `# Managed by Ripper.
auth include common-auth
account include common-account
password include common-password
session include common-session
`
}

func EnsureI3lockPam(cfg config.InstallConfig, apply bool) error {
	const pamPath = "/etc/pam.d/i3lock"

	expected := pamConfig(cfg.Distro)

	status, err := system.CheckFileState(pamPath, expected)
	if err != nil {
		return err
	}

	switch status {
	case system.FileMatch:
		fmt.Println("PAM service already configured:", pamPath)
		return nil

	case system.FileUnmanaged:
		fmt.Println("PAM service exists and is not managed by Ripper:", pamPath)
		return nil

	case system.FileMissing, system.FileDifferent:
		if !apply {
			fmt.Println("PAM service would be written:", pamPath)
			return nil
		}

		fmt.Println("Writing PAM service:", pamPath)
		return system.WriteRootFile(pamPath, expected, "0644")
	}

	return nil
}