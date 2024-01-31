/*
Copyright © 2024 Capruro me@capruro.com
*/
package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"os/user"

	"github.com/spf13/cobra"
)

// makeCmd represents the make command
var makeCmd = &cobra.Command{
	Use:   "make",
	Short: "Make a new snapshot",
	Long:  `The "make" option create a new snapshot`,
	Run:   makeRun,
}

func makeRun(cmd *cobra.Command, args []string) {
	if err := checkRoot(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	fmt.Println("make called")
	// Add your make logic here
	loadConfig()
	testDirs()

	// Append the content of /etc/hosts to the log file
	appendHostsContent()
}

// Config represents the configuration structure.
type Config struct {
	SnapshotsDir string `json:"snapshotsDir"`
	FmtFile      string `json:"fmtFile"`
}

var config Config

func loadConfig() {
	file, err := os.Open("config.json")
	if err != nil {
		fmt.Println("[ERROR] Failed to open config file:", err)
		os.Exit(1)
	}
	defer file.Close()

	decoder := json.NewDecoder(file)
	err = decoder.Decode(&config)
	if err != nil {
		fmt.Println("[ERROR] Failed to decode config file:", err)
		os.Exit(1)
	}
}

func testDirs() {
	checkAndCreateDir("snapshots", config.SnapshotsDir)
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

func init() {
	rootCmd.AddCommand(makeCmd)
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

func appendHostsContent() {
	logFilePath := fmt.Sprintf("%s/%s", config.SnapshotsDir, config.FmtFile)
	cmd := exec.Command("cat", "/etc/hosts")
	out, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Printf("[ERROR] Failed to execute 'cat /etc/hosts': %v\n", err)
		os.Exit(1)
	}

	f, err := os.OpenFile(logFilePath, os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0644)
	if err != nil {
		fmt.Printf("[ERROR] Failed to open log file: %v\n", err)
		os.Exit(1)
	}
	defer f.Close()

	if _, err := f.Write(out); err != nil {
		fmt.Printf("[ERROR] Failed to write to log file: %v\n", err)
		os.Exit(1)
	}
}
