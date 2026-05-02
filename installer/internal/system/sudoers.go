package system

import (
	"fmt"
	"os/exec"
	"strings"
)

// WriteSudoers escribe un archivo sudoers con permisos correctos (0440)
// y opcionalmente valida con visudo antes de aplicarlo.
func WriteSudoers(path, content string) error {
	// Validación previa con visudo (si existe)
	visudoPath, err := ResolveCommand("visudo", "/usr/sbin/visudo", "/usr/bin/visudo")
	if err == nil {
		cmd := exec.Command(visudoPath, "-cf", "-")
		cmd.Stdin = strings.NewReader(content)

		if err := cmd.Run(); err != nil {
			return fmt.Errorf("invalid sudoers content: %w", err)
		}
	}

	// Escritura real (usa tu primitiva existente)
	return WriteRootFile(path, content, "0440")
}