package system

import "os/exec"

// IsDebianPackageInstalled verifica si un paquete está instalado usando dpkg
func IsDebianPackageInstalled(name string) (bool, error) {
	dpkgPath, err := ResolveCommand("dpkg", "/usr/bin/dpkg", "/bin/dpkg")
	if err != nil {
		return false, err
	}

	cmd := exec.Command(dpkgPath, "-s", name)
	err = cmd.Run()

	if err == nil {
		return true, nil
	}

	// dpkg -s devuelve error si no está instalado
	return false, nil
}