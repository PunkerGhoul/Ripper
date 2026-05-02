package config

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
)

func RepoRoot() (string, error) {
	repoRoot := os.Getenv("RIPPER_REPO_ROOT")
	if repoRoot == "" {
		return "", errors.New("missing RIPPER_REPO_ROOT; run through `nix run .`")
	}

	abs, err := filepath.Abs(repoRoot)
	if err != nil {
		return "", err
	}

	if _, err := os.Stat(filepath.Join(abs, "flake.nix")); err != nil {
		return "", fmt.Errorf("missing flake.nix in %s", abs)
	}

	return abs, nil
}