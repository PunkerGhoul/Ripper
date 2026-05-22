package powermanager

import (
	"fmt"
	"strings"

	"ripper/installer/internal/config"
	"ripper/installer/internal/system"
)

func Ensure(cfg config.InstallConfig, apply bool) error {
	group := "powermanager"
	path := "/etc/sudoers.d/90-user-powermanager"

	commands := []string{
		"/usr/bin/poweroff",
		"/usr/bin/reboot",
		"/usr/bin/systemctl poweroff",
		"/usr/bin/systemctl reboot",
		"/usr/bin/systemctl suspend",
		"/usr/bin/systemctl hibernate",
		"/usr/bin/systemctl hybrid-sleep",
	}

	line := fmt.Sprintf("%%%s ALL=(root) NOPASSWD: %s\n",
		group,
		strings.Join(commands, ", "),
	)

	// --- grupo ---
	exists, err := system.GroupExists(group)
	if err != nil {
		return err
	}

	if !exists {
		if !apply {
			fmt.Printf("Group %s would be created\n", group)
		} else {
			fmt.Printf("Creating group %s\n", group)
			if err := system.CreateGroup(group); err != nil {
				return err
			}
		}
	} else {
		fmt.Printf("Group %s already exists\n", group)
	}

	// --- usuario en grupo ---
	inGroup, err := system.UserInGroup(cfg.Username, group)
	if err != nil {
		return err
	}

	if !inGroup {
		if !apply {
			fmt.Printf("User %s would be added to %s\n", cfg.Username, group)
		} else {
			fmt.Printf("Adding user %s to %s\n", cfg.Username, group)
			if err := system.AddUserToGroup(cfg.Username, group); err != nil {
				return err
			}
		}
	} else {
		fmt.Printf("User %s already in %s\n", cfg.Username, group)
	}

	// --- sudoers ---
	if system.FileHasContent(path, line) {
		fmt.Printf("Sudoers already configured: %s\n", path)
		return nil
	}

	if !apply {
		fmt.Printf("Sudoers would be written: %s\n", path)
		return nil
	}

	return system.WriteRootFile(path, line, "0440")
}