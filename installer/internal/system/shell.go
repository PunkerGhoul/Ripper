package system

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func EnsureShellListed(shellPath string) error {
	data, err := os.ReadFile("/etc/shells")
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("read /etc/shells: %w", err)
	}

	for _, line := range strings.Split(string(data), "\n") {
		if strings.TrimSpace(line) == shellPath {
			return nil
		}
	}

	return appendShell(shellPath)
}

func appendShell(shellPath string) error {
	sudoPath, err := ResolveCommand("sudo", "/usr/bin/sudo", "/bin/sudo")
	if err != nil {
		return err
	}

	shPath, err := ResolveCommand("sh", "/bin/sh", "/usr/bin/sh")
	if err != nil {
		return err
	}

	cmd := exec.Command(
		sudoPath,
		shPath,
		"-c",
		"printf '%s\n' \"$1\" >> /etc/shells",
		"sh",
		shellPath,
	)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("append /etc/shells failed: %w", err)
	}

	return nil
}

func ChangeLoginShell(username, shellPath string) error {
	sudoPath, err := ResolveCommand("sudo", "/usr/bin/sudo", "/bin/sudo")
	if err != nil {
		return err
	}

	chshPath, err := ResolveCommand("chsh", "/usr/bin/chsh", "/bin/chsh")
	if err != nil {
		return err
	}

	cmd := exec.Command(sudoPath, chshPath, "-s", shellPath, username)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("chsh failed: %w", err)
	}

	return nil
}