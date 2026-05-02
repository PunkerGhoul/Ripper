package config

import (
	"fmt"
	"runtime"
)

func nixSystem() (string, error) {
	if runtime.GOOS != "linux" {
		return "", fmt.Errorf("unsupported OS %s", runtime.GOOS)
	}
	switch runtime.GOARCH {
	case "amd64":
		return "x86_64-linux", nil
	case "arm64":
		return "aarch64-linux", nil
	default:
		return "", fmt.Errorf("unsupported architecture %s", runtime.GOARCH)
	}
}