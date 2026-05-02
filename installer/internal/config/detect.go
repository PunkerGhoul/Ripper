package config

import (
	"fmt"
	"os/user"
	"strings"
)

func normalizeUsername(username string) string {
	if idx := strings.LastIndex(username, `\`); idx >= 0 {
		return username[idx+1:]
	}
	return username
}

func detectDistro() string {
	data, err := os.ReadFile("/etc/os-release")
	if err != nil {
		return "unknown"
	}
	values := map[string]string{}
	for _, line := range strings.Split(string(data), "\n") {
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		values[key] = strings.Trim(value, `"`)
	}
	id := values["ID"]
	like := values["ID_LIKE"]
	switch {
	case id == "debian" || id == "ubuntu" || strings.Contains(like, "debian"):
		return "debian"
	case id == "arch" || strings.Contains(like, "arch"):
		return "arch"
	default:
		if id != "" {
			return id
		}
		return "unknown"
	}
}

func DetectConfig() (InstallConfig, error) {
	current, err := user.Current()
	if err != nil {
		return InstallConfig{}, fmt.Errorf("detect current user: %w", err)
	}

	username := normalizeUsername(current.Username)

	if username == "" || username == "root" {
		return InstallConfig{}, fmt.Errorf("refusing to generate a Home Manager profile for %q", username)
	}

	if current.HomeDir == "" {
		return InstallConfig{}, fmt.Errorf("could not determine home directory for %q", username)
	}

	system, err := nixSystem()
	if err != nil {
		return InstallConfig{}, err
	}

	return InstallConfig{
		Username:      username,
		HomeDirectory: current.HomeDir,
		System:        system,
		Distro:        detectDistro(),
		GPUWrapper:    "mesa",
		StateVersion:  "25.05",
	}, nil
}