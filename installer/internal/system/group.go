package system

import (
	"fmt"
	"os/exec"
	"strings"
)

// GroupExists verifica si un grupo existe en el sistema
func GroupExists(name string) (bool, error) {
	getentPath, err := ResolveCommand("getent", "/usr/bin/getent", "/bin/getent")
	if err != nil {
		return false, err
	}

	out, err := exec.Command(getentPath, "group", name).Output()
	if err != nil {
		// getent devuelve error si no existe
		return false, nil
	}

	return strings.Contains(string(out), name), nil
}

// CreateGroup crea un grupo en el sistema
func CreateGroup(name string) error {
	sudoPath, err := ResolveCommand("sudo", "/usr/bin/sudo", "/bin/sudo")
	if err != nil {
		return err
	}

	groupaddPath, err := ResolveCommand("groupadd", "/usr/sbin/groupadd", "/usr/bin/groupadd")
	if err != nil {
		return err
	}

	if err := RunInteractive(sudoPath, groupaddPath, name); err != nil {
		return fmt.Errorf("create group %s: %w", name, err)
	}

	return nil
}

// AddUserToGroup añade un usuario a un grupo
func AddUserToGroup(user, group string) error {
	sudoPath, err := ResolveCommand("sudo", "/usr/bin/sudo", "/bin/sudo")
	if err != nil {
		return err
	}

	usermodPath, err := ResolveCommand("usermod", "/usr/sbin/usermod", "/usr/bin/usermod")
	if err != nil {
		return err
	}

	if err := RunInteractive(sudoPath, usermodPath, "-aG", group, user); err != nil {
		return fmt.Errorf("add user %s to group %s: %w", user, group, err)
	}

	return nil
}

// UserInGroup verifica si un usuario pertenece a un grupo
func UserInGroup(user, group string) (bool, error) {
	idPath, err := ResolveCommand("id", "/usr/bin/id", "/bin/id")
	if err != nil {
		return false, err
	}

	out, err := exec.Command(idPath, "-nG", user).Output()
	if err != nil {
		return false, err
	}

	groups := strings.Fields(string(out))
	for _, g := range groups {
		if g == group {
			return true, nil
		}
	}

	return false, nil
}