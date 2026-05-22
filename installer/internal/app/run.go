package app

import (
	"fmt"
)

func run(args []string) error {
	command := "switch"
	if len(args) > 0 {
		command = args[0]
	}
	switch command {
		case "init":
			return runInit()
		case "doctor":
			return runDoctor()
		case "switch", "apply":
			return runSwitch()
		default:
			return fmt.Errorf("unknown command %q; expected init, doctor, or switch", command)
	}
}

// Run is the exported entrypoint for the CLI.
func Run(args []string) error {
	return run(args)
}