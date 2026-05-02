package system

import (
	"errors"
	"fmt"
	"os"
	"strings"
)

type FileState int

const (
	FileMissing FileState = iota
	FileMatch
	FileDifferent
	FileUnmanaged
)

func CheckFileState(path string, expected string) (FileState, error) {
	current, err := os.ReadFile(path)

	if err == nil {
		currentStr := strings.TrimSpace(string(current))
		expectedStr := strings.TrimSpace(expected)

		if currentStr == expectedStr {
			return FileMatch, nil
		}

		if len(current) > 0 && !strings.Contains(currentStr, "Managed by Ripper") {
			return FileUnmanaged, nil
		}

		return FileDifferent, nil
	}

	if errors.Is(err, os.ErrNotExist) {
		return FileMissing, nil
	}

	return FileMissing, fmt.Errorf("read %s: %w", path, err)
}