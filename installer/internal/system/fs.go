package system

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func FileHasContent(path string, expected string) bool {
	current, err := os.ReadFile(path)
	if err != nil {
		return false
	}

	return strings.TrimSpace(string(current)) ==
		strings.TrimSpace(expected)
}

func MissingPaths(paths ...string) []string {
	return missingHostPaths(paths...)
}

func missingHostPaths(paths ...string) []string {
	missing := []string{}
	for _, path := range paths {
		if _, err := os.Stat(path); err != nil {
			missing = append(missing, path)
		}
	}
	return missing
}

func WriteRootFile(path string, content string, mode string) error {
	sudoPath, err := systemCommand("sudo", "/usr/bin/sudo", "/bin/sudo")
	if err != nil {
		return err
	}

	shPath, err := systemCommand("sh", "/bin/sh", "/usr/bin/sh")
	if err != nil {
		return err
	}

	cmd := exec.Command(
		sudoPath,
		shPath,
		"-c",
		"umask 022 && mkdir -p \"$1\" && cat > \"$2\" && chmod \"$3\" \"$2\"",
		"sh",
		filepath.Dir(path),
		path,
		mode,
	)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = strings.NewReader(content)

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("write %s failed: %w", path, err)
	}

	return nil
}