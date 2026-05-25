package display

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"ripper/installer/internal/config"
	"ripper/installer/internal/system"
)

const (
	abstractThemeName     = "Abstract"
	abstractThemeDest     = "/usr/share/sddm/themes/Abstract"
	abstractThemeVideoRel = "local/sddm/Abstract.mp4"
)

func EnsureAbstractTheme(apply bool) (string, error) {
	repoRoot, err := config.RepoRoot()
	if err != nil {
		return "", err
	}

	themeSource := filepath.Join(repoRoot, "nix", "modules", "sddm", "assets", abstractThemeName)
	videoSource := filepath.Join(repoRoot, filepath.FromSlash(abstractThemeVideoRel))

	if _, err := os.Stat(themeSource); err != nil {
		return "", fmt.Errorf("missing local SDDM theme source %s: %w", themeSource, err)
	}
	if _, err := os.Stat(videoSource); err != nil {
		return "", fmt.Errorf("missing %s; copy your mp4 there before running `nix run .#switch`", abstractThemeVideoRel)
	}

	files, err := collectThemeFiles(themeSource)
	if err != nil {
		return "", err
	}

	if themeInstalled(files, themeSource) && videoInstalled(videoSource) {
		return "already_configured", nil
	}
	if !apply {
		return "would_install", nil
	}

	for _, rel := range files {
		sourcePath := filepath.Join(themeSource, filepath.FromSlash(rel))
		destPath := filepath.Join(abstractThemeDest, filepath.FromSlash(rel))

		content, err := os.ReadFile(sourcePath)
		if err != nil {
			return "", fmt.Errorf("read %s: %w", sourcePath, err)
		}
		if err := system.WriteRootFile(destPath, string(content), "0644"); err != nil {
			return "", err
		}
	}

	if err := installThemeVideo(videoSource); err != nil {
		return "", err
	}

	return "installed", nil
}

func collectThemeFiles(root string) ([]string, error) {
	files := []string{}

	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if entry.IsDir() {
			return nil
		}

		rel, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		rel = filepath.ToSlash(rel)
		if strings.HasPrefix(rel, "Backgrounds/") {
			return nil
		}

		files = append(files, rel)
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("walk %s: %w", root, err)
	}

	return files, nil
}

func themeInstalled(files []string, sourceRoot string) bool {
	for _, rel := range files {
		sourcePath := filepath.Join(sourceRoot, filepath.FromSlash(rel))
		destPath := filepath.Join(abstractThemeDest, filepath.FromSlash(rel))

		content, err := os.ReadFile(sourcePath)
		if err != nil {
			return false
		}
		if !system.FileHasContent(destPath, string(content)) {
			return false
		}
	}

	return true
}

func videoInstalled(sourcePath string) bool {
	source, err := os.Stat(sourcePath)
	if err != nil {
		return false
	}

	dest, err := os.Stat(filepath.Join(abstractThemeDest, "Backgrounds", "Abstract.mp4"))
	if err != nil {
		return false
	}

	return source.Size() == dest.Size()
}

func installThemeVideo(sourcePath string) error {
	sudoPath, err := system.ResolveCommand("sudo", "/usr/bin/sudo", "/bin/sudo")
	if err != nil {
		return err
	}

	installPath, err := system.ResolveCommand("install", "/usr/bin/install", "/bin/install")
	if err != nil {
		return err
	}

	destPath := filepath.Join(abstractThemeDest, "Backgrounds", "Abstract.mp4")
	if err := system.RunInteractive(sudoPath, installPath, "-Dm644", sourcePath, destPath); err != nil {
		return fmt.Errorf("install %s: %w", destPath, err)
	}

	return nil
}
