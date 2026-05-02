package config

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
)

func EnsureInstallConfig() (InstallConfig, error) {
	repoRoot, err := RepoRoot()
	if err != nil {
		return InstallConfig{}, err
	}

	cfg, err := DetectConfig()
	if err != nil {
		return InstallConfig{}, err
	}

	path := filepath.Join(repoRoot, "local", "install.nix")

	if _, err := os.Stat(path); err == nil {
		cfg.ConfigPath = path
		cfg.Existing = true
		return cfg, nil
	} else if !errors.Is(err, os.ErrNotExist) {
		return InstallConfig{}, err
	}

	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return InstallConfig{}, err
	}

	content := RenderInstallConfig(cfg)
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		return InstallConfig{}, err
	}

	cfg.ConfigPath = path
	cfg.Existing = false

	fmt.Println("Created", path)

	return cfg, nil
}