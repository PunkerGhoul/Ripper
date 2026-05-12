package config

type InstallConfig struct {
	Username      string
	HomeDirectory string
	HostName      string
	System        string
	Distro        string
	GPUWrapper    string
	StateVersion  string
	ConfigPath    string
	Existing      bool
}