package main

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"runtime"
	"strings"
)

type installConfig struct {
	Username      string
	HomeDirectory string
	System        string
	Distro        string
	GPUWrapper    string
	StateVersion  string
	ConfigPath    string
	Existing      bool
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	command := "switch"
	if len(args) > 0 {
		command = args[0]
	}

	switch command {
	case "init":
		_, err := ensureInstallConfig()
		return err
	case "doctor":
		cfg, err := ensureInstallConfig()
		if err != nil {
			return err
		}
		printDoctor(cfg)
		if err := ensureLoginShell(cfg, false); err != nil {
			return err
		}
		if err := ensureI3lockPam(cfg, false); err != nil {
			return err
		}
		return ensureDisplayManager(cfg, false)
	case "switch", "apply":
		cfg, err := ensureInstallConfig()
		if err != nil {
			return err
		}
		printDoctor(cfg)
		if err := ensureLoginShell(cfg, true); err != nil {
			return err
		}
		if err := ensureI3lockPam(cfg, true); err != nil {
			return err
		}
		if err := runHomeManager(); err != nil {
			return err
		}
		if err := ensureDisplayManager(cfg, true); err != nil {
			return err
		}
		return nil
	default:
		return fmt.Errorf("unknown command %q; expected init, doctor, or switch", command)
	}
}

func ensureInstallConfig() (installConfig, error) {
	repoRoot, err := repoRoot()
	if err != nil {
		return installConfig{}, err
	}
	cfg, err := detectConfig()
	if err != nil {
		return installConfig{}, err
	}
	path := filepath.Join(repoRoot, "local", "install.nix")
	if _, err := os.Stat(path); err == nil {
		cfg.ConfigPath = path
		cfg.Existing = true
		return cfg, nil
	} else if !errors.Is(err, os.ErrNotExist) {
		return installConfig{}, err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return installConfig{}, err
	}
	if err := os.WriteFile(path, []byte(renderInstallConfig(cfg)), 0o644); err != nil {
		return installConfig{}, err
	}
	cfg.ConfigPath = path
	fmt.Println("Created", path)
	return cfg, nil
}

func detectConfig() (installConfig, error) {
	current, err := user.Current()
	if err != nil {
		return installConfig{}, fmt.Errorf("detect current user: %w", err)
	}
	username := current.Username
	if idx := strings.LastIndex(username, `\`); idx >= 0 {
		username = username[idx+1:]
	}
	if username == "" || username == "root" {
		return installConfig{}, fmt.Errorf("refusing to generate a Home Manager profile for %q", username)
	}
	system, err := nixSystem()
	if err != nil {
		return installConfig{}, err
	}
	return installConfig{
		Username:      username,
		HomeDirectory: current.HomeDir,
		System:        system,
		Distro:        detectDistro(),
		GPUWrapper:    "mesa",
		StateVersion:  "25.05",
	}, nil
}

func nixSystem() (string, error) {
	if runtime.GOOS != "linux" {
		return "", fmt.Errorf("unsupported OS %s; Ripper apply targets Linux VMs", runtime.GOOS)
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

func renderInstallConfig(cfg installConfig) string {
	return fmt.Sprintf(`{
  username = %q;
  homeDirectory = %q;
  system = %q;
  distro = %q;
  stateVersion = %q;

  gpu = {
    # Pure Mesa path for VMware SVGA, Intel, AMD, and Nouveau guests.
    # For Nvidia passthrough, set wrapper = "nvidia" and add:
    # nvidia = { version = "..."; sha256 = "sha256-..."; };
    wrapper = %q;
  };
}
`, cfg.Username, cfg.HomeDirectory, cfg.System, cfg.Distro, cfg.StateVersion, cfg.GPUWrapper)
}

func runHomeManager() error {
	repoRoot, err := repoRoot()
	if err != nil {
		return err
	}
	homeManager := os.Getenv("RIPPER_HOME_MANAGER_BIN")
	if homeManager == "" {
		homeManager, err = exec.LookPath("home-manager")
		if err != nil {
			return errors.New("missing home-manager; run through `nix run .`")
		}
	}
	cmd := exec.Command(homeManager, "switch", "--flake", "path:"+repoRoot+"#ripper", "-b", "backup")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	cmd.Env = os.Environ()
	return cmd.Run()
}

func ensureLoginShell(cfg installConfig, apply bool) error {
	zshPath, err := exec.LookPath("zsh")
	if err != nil {
		return errors.New("missing zsh in installer runtime")
	}
	currentShell, err := currentLoginShell(cfg.Username)
	if err != nil {
		return err
	}
	if currentShell == zshPath {
		fmt.Println("Login shell already set to", zshPath)
		return nil
	}
	if !apply {
		fmt.Printf("Login shell would be changed from %s to %s\n", currentShell, zshPath)
		return nil
	}
	if err := ensureShellListed(zshPath); err != nil {
		return err
	}
	sudoPath, err := systemCommand("sudo", "/usr/bin/sudo", "/bin/sudo")
	if err != nil {
		return err
	}
	chshPath, err := systemCommand("chsh", "/usr/bin/chsh", "/bin/chsh")
	if err != nil {
		return err
	}
	fmt.Println("Changing login shell to", zshPath)
	cmd := exec.Command(sudoPath, chshPath, "-s", zshPath, cfg.Username)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("chsh failed: %w", err)
	}
	return nil
}

func ensureDisplayManager(cfg installConfig, apply bool) error {
	missing := missingHostPaths("/usr/bin/sddm")
	needsInstall := len(missing) > 0
	if cfg.Distro == "debian" && !debianPackageInstalled("sddm") {
		missing = append(missing, "package:sddm")
		needsInstall = true
	}

	if !needsInstall {
		fmt.Println("Host display manager already installed: /usr/bin/sddm")
	} else if !apply {
		fmt.Printf("Host SDDM packages would be installed; missing: %s\n", strings.Join(missing, ", "))
	} else if err := installDisplayManagerPackages(cfg.Distro); err != nil {
		return err
	}

	if err := ensureRipperSession(apply); err != nil {
		return err
	}
	if err := ensureSddmConfig(cfg, apply); err != nil {
		return err
	}
	return ensureSddmEnabled(apply)
}

func debianPackageInstalled(name string) bool {
	dpkgPath, err := systemCommand("dpkg", "/usr/bin/dpkg", "/bin/dpkg")
	if err != nil {
		return false
	}
	return exec.Command(dpkgPath, "-s", name).Run() == nil
}

func installDisplayManagerPackages(distro string) error {
	sudoPath, err := systemCommand("sudo", "/usr/bin/sudo", "/bin/sudo")
	if err != nil {
		return err
	}
	switch distro {
	case "debian":
		aptPath, err := systemCommand("apt", "/usr/bin/apt", "/bin/apt")
		if err != nil {
			return err
		}
		fmt.Println("Installing host SDDM packages for Debian/Ubuntu")
		if err := runInteractive(sudoPath, aptPath, "update", "-y"); err != nil {
			return fmt.Errorf("apt update failed: %w", err)
		}
		return runInteractive(sudoPath, aptPath, "install", "-y",
			"sddm",
			"xorg",
			"dbus-x11",
		)
	case "arch":
		pacmanPath, err := systemCommand("pacman", "/usr/bin/pacman", "/bin/pacman")
		if err != nil {
			return err
		}
		fmt.Println("Installing host SDDM packages for Arch")
		return runInteractive(sudoPath, pacmanPath, "-Syu", "--needed", "--noconfirm",
			"sddm",
			"xorg-server",
			"xorg-xauth",
			"dbus",
		)
	default:
		return fmt.Errorf("unsupported distro %q; install sddm and xorg-server with the host package manager", distro)
	}
}

func ensureRipperSession(apply bool) error {
	const scriptPath = "/usr/local/bin/ripper-session"
	const desktopPath = "/usr/share/xsessions/ripper.desktop"
	script := `#!/bin/sh
# Managed by Ripper.
for profile in \
  "$HOME/.nix-profile" \
  "$HOME/.local/state/nix/profiles/profile" \
  "/etc/profiles/per-user/$USER"; do
  if [ -r "$profile/etc/profile.d/hm-session-vars.sh" ]; then
    . "$profile/etc/profile.d/hm-session-vars.sh"
  fi
  if [ -d "$profile/bin" ]; then
    PATH="$profile/bin:$PATH"
  fi
  if [ -d "$profile/share" ]; then
    XDG_DATA_DIRS="$profile/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
  fi
done

export PATH
export XDG_DATA_DIRS

export XDG_CURRENT_DESKTOP=i3
export XDG_SESSION_DESKTOP=ripper
export DESKTOP_SESSION=ripper

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP DESKTOP_SESSION
fi

if [ ! -x "$HOME/.local/bin/ripper-session-start" ]; then
  echo "Ripper session: missing Home Manager launcher: $HOME/.local/bin/ripper-session-start" >&2
  exit 127
fi

exec "$HOME/.local/bin/ripper-session-start"
`
	desktop := `[Desktop Entry]
Name=Ripper
Comment=Ripper i3 session
Exec=/usr/local/bin/ripper-session
TryExec=/usr/local/bin/ripper-session
Type=Application
DesktopNames=i3;Ripper
`
	if fileHasContent(scriptPath, script) && fileHasContent(desktopPath, desktop) {
		fmt.Println("Ripper SDDM session already configured")
		return nil
	}
	if !apply {
		fmt.Println("Ripper SDDM session would be written")
		return nil
	}
	if err := writeRootFile(scriptPath, script, "0755"); err != nil {
		return err
	}
	return writeRootFile(desktopPath, desktop, "0644")
}

func ensureSddmConfig(cfg installConfig, apply bool) error {
	const configPath = "/etc/sddm.conf.d/99-ripper.conf"
	config := fmt.Sprintf(`[General]
DisplayServer=x11

[Autologin]
Relogin=false
Session=
User=

[Users]
MinimumUid=1000
MaximumUid=29999
HideShells=/usr/sbin/nologin,/usr/bin/nologin,/sbin/nologin,/bin/false
HideUsers=%s
RememberLastUser=false
RememberLastSession=false
`, strings.Join(sddmHiddenUsers(cfg.Username), ","))

	if fileHasContent(configPath, config) {
		fmt.Println("SDDM user filter already configured:", configPath)
		return nil
	}
	if !apply {
		fmt.Println("SDDM user filter would be written:", configPath)
		return nil
	}
	return writeRootFile(configPath, config, "0644")
}

func sddmHiddenUsers(loginUser string) []string {
	hidden := []string{"root", "nobody"}
	data, err := os.ReadFile("/etc/passwd")
	if err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			fields := strings.Split(line, ":")
			if len(fields) < 3 {
				continue
			}
			name := fields[0]
			if name == "" || name == loginUser {
				continue
			}
			if strings.HasPrefix(name, "nixbld") {
				hidden = append(hidden, name)
			}
		}
	}
	return uniqueStrings(hidden)
}

func ensureSddmEnabled(apply bool) error {
	systemctlPath, err := systemCommand("systemctl", "/usr/bin/systemctl", "/bin/systemctl")
	if err != nil {
		return err
	}
	if exec.Command(systemctlPath, "is-enabled", "--quiet", "sddm.service").Run() == nil {
		fmt.Println("SDDM service already enabled")
		return nil
	}
	if !apply {
		fmt.Println("SDDM service would be enabled")
		return nil
	}
	sudoPath, err := systemCommand("sudo", "/usr/bin/sudo", "/bin/sudo")
	if err != nil {
		return err
	}
	fmt.Println("Enabling SDDM service")
	if err := runInteractive(sudoPath, systemctlPath, "enable", "--force", "sddm.service"); err != nil {
		return fmt.Errorf("enable sddm.service failed: %w", err)
	}
	if err := runInteractive(sudoPath, systemctlPath, "set-default", "graphical.target"); err != nil {
		return fmt.Errorf("set graphical.target failed: %w", err)
	}
	return nil
}

func ensureI3lockPam(cfg installConfig, apply bool) error {
	const pamPath = "/etc/pam.d/i3lock"
	expected := pamConfig(cfg.Distro)
	current, err := os.ReadFile(pamPath)
	if err == nil && strings.TrimSpace(string(current)) == strings.TrimSpace(expected) {
		fmt.Println("PAM service already configured:", pamPath)
		return nil
	}
	if err == nil && len(current) > 0 && !strings.Contains(string(current), "Managed by Ripper") {
		fmt.Println("PAM service exists and is not managed by Ripper:", pamPath)
		return nil
	}
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("read %s: %w", pamPath, err)
	}
	if !apply {
		fmt.Println("PAM service would be written:", pamPath)
		return nil
	}
	sudoPath, err := systemCommand("sudo", "/usr/bin/sudo", "/bin/sudo")
	if err != nil {
		return err
	}
	shPath, err := systemCommand("sh", "/bin/sh", "/usr/bin/sh")
	if err != nil {
		return err
	}
	fmt.Println("Writing PAM service:", pamPath)
	cmd := exec.Command(sudoPath, shPath, "-c", "umask 022 && cat > /etc/pam.d/i3lock")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = strings.NewReader(expected)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("write %s failed: %w", pamPath, err)
	}
	return nil
}

func pamConfig(distro string) string {
	if distro == "arch" {
		return `# Managed by Ripper.
auth include system-auth
account include system-auth
password include system-auth
session include system-auth
`
	}
	return `# Managed by Ripper.
auth include common-auth
account include common-account
password include common-password
session include common-session
`
}

func currentLoginShell(username string) (string, error) {
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

func ensureShellListed(shellPath string) error {
	data, err := os.ReadFile("/etc/shells")
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("read /etc/shells: %w", err)
	}
	for _, line := range strings.Split(string(data), "\n") {
		if strings.TrimSpace(line) == shellPath {
			return nil
		}
	}
	fmt.Println("Adding", shellPath, "to /etc/shells")
	sudoPath, err := systemCommand("sudo", "/usr/bin/sudo", "/bin/sudo")
	if err != nil {
		return err
	}
	shPath, err := systemCommand("sh", "/bin/sh", "/usr/bin/sh")
	if err != nil {
		return err
	}
	cmd := exec.Command(sudoPath, shPath, "-c", "printf '%s\n' \"$1\" >> /etc/shells", "sh", shellPath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("append /etc/shells failed: %w", err)
	}
	return nil
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

func fileHasContent(path string, expected string) bool {
	current, err := os.ReadFile(path)
	return err == nil && strings.TrimSpace(string(current)) == strings.TrimSpace(expected)
}

func uniqueStrings(values []string) []string {
	seen := map[string]bool{}
	result := []string{}
	for _, value := range values {
		if value == "" || seen[value] {
			continue
		}
		seen[value] = true
		result = append(result, value)
	}
	return result
}

func writeRootFile(path string, content string, mode string) error {
	sudoPath, err := systemCommand("sudo", "/usr/bin/sudo", "/bin/sudo")
	if err != nil {
		return err
	}
	shPath, err := systemCommand("sh", "/bin/sh", "/usr/bin/sh")
	if err != nil {
		return err
	}
	fmt.Println("Writing", path)
	cmd := exec.Command(sudoPath, shPath, "-c", "umask 022 && mkdir -p \"$1\" && cat > \"$2\" && chmod \"$3\" \"$2\"", "sh", filepath.Dir(path), path, mode)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = strings.NewReader(content)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("write %s failed: %w", path, err)
	}
	return nil
}

func runInteractive(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

func systemCommand(name string, paths ...string) (string, error) {
	for _, path := range paths {
		if _, err := os.Stat(path); err == nil {
			return path, nil
		}
	}
	if path, err := exec.LookPath(name); err == nil && !strings.HasPrefix(path, "/nix/store/") {
		return path, nil
	}
	return "", fmt.Errorf("missing host %s; refusing to use a Nix-provided privileged command", name)
}

func repoRoot() (string, error) {
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

func printDoctor(cfg installConfig) {
	if cfg.Existing {
		fmt.Printf("Ripper profile: using existing declaration %s\n", cfg.ConfigPath)
		return
	}
	fmt.Printf("Ripper profile: user=%s home=%s system=%s distro=%s gpu=%s\n",
		cfg.Username,
		cfg.HomeDirectory,
		cfg.System,
		cfg.Distro,
		cfg.GPUWrapper,
	)
}
