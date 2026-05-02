package system

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func SystemCommand(name string, paths ...string) (string, error) {
	for _, path := range paths {
		if _, err := os.Stat(path); err == nil {
			return path, nil
		}
	}
	if path, err := exec.LookPath(name); err == nil && !strings.HasPrefix(path, "/nix/store/") {
		return path, nil
	}
	return "", fmt.Errorf("missing host %s; refusing to use a Nix-provided privileged command", name)
}

func ResolveCommand(name string, paths ...string) (string, error) {
	return SystemCommand(name, paths...)
}

func RunInteractive(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

func LookPath(bin string) (string, error) {
	return exec.LookPath(bin)
}