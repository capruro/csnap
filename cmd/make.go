/*
Copyright © 2024 Capruro me@capruro.com
*/
package cmd

import (
	"fmt"
	"os"
	"os/user"
	"runtime"

	"github.com/spf13/cobra"
)

// makeCmd represents the make command
var makeCmd = &cobra.Command{
	Use:   "make",
	Short: "Make a new snapshot",
	Long:  `The "make" option create a new snapshot`,
	Run:   makeRun,
}

func collectOSDetails() {
	os := runtime.GOOS
	arch := runtime.GOARCH

	fmt.Printf("Operating System: %s\n", os)
	fmt.Printf("Architecture: %s\n", arch)

	switch os {
	case "windows":
		// Additional Windows-specific details
		// You can use `os.Getenv("OS")` to get specific version information or use other relevant functions.
		fmt.Println("Windows it's not supported yet!")
	case "linux":
		// Additional Linux-specific details
		// You can use specific Linux commands or system calls to gather more information.
		fmt.Println("Linux-specific details...")

	case "darwin":
		// Additional macOS-specific details
		// You can use specific macOS commands or system calls to gather more information.
		fmt.Println("macOS-specific details...")
	default:
		fmt.Println("Unknown operating system")
	}
}

func checkAndCreateDir(name, path string) {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		fmt.Printf("[INFO] %s directory not found\n", name)
		fmt.Printf("[INFO] Creating %s directory\n", name)

		err := os.MkdirAll(path, 0755)
		if err != nil {
			fmt.Printf("[ERROR] Failure to create the %s directory\n", name)
			os.Exit(1)
		}

		err = os.Chmod(path, 0755)
		if err != nil {
			fmt.Printf("[ERROR] Failure to change permissions for %s\n", path)
			os.Exit(1)
		}
	}
}

func checkRoot() error {
	currentUser, err := user.Current()
	if err != nil {
		return err
	}

	if currentUser.Username != "root" {
		return fmt.Errorf("error: This command must be run as root")
	}

	return nil
}

func makeRun(cmd *cobra.Command, args []string) {
	if err := checkRoot(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	collectOSDetails()
}

func init() {
	rootCmd.AddCommand(makeCmd)
}
