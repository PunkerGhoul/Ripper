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
		return nil
	case "switch", "apply":
		cfg, err := ensureInstallConfig()
		if err != nil {
			return err
		}
		printDoctor(cfg)
		return runHomeManager()
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
