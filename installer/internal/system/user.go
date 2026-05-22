package system

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func CurrentLoginShell(username string) (string, error) {
	if getent, err := exec.LookPath("getent"); err == nil {
		output, err := exec.Command(getent, "passwd", username).Output()
		if err == nil {
			parts := strings.Split(strings.TrimSpace(string(output)), ":")
			if len(parts) == 7 && parts[6] != "" {
				return parts[6], nil
			}
		}
	}

	data, err := os.ReadFile("/etc/passwd")
	if err != nil {
		return "", fmt.Errorf("read /etc/passwd: %w", err)
	}

	for _, line := range strings.Split(string(data), "\n") {
		parts := strings.Split(line, ":")
		if len(parts) == 7 && parts[0] == username {
			return parts[6], nil
		}
	}

	return "", fmt.Errorf("could not determine login shell for %s", username)
}