/*
Copyright © 2024 Capruro me@capruro.com
*/
package cmd

import (
	"fmt"
	"log"
	"os"
	"runtime"
	"strings"

	"github.com/spf13/cobra"
)

var versionFile string // Add a variable to store the path to the version file

// versionCmd represents the version command
var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print version information",
	Long: `The "version" command prints detailed information about the build environment
	and the version of this software.`,
	Run: func(cmd *cobra.Command, args []string) {
		version, err := readVersionFromFile(versionFile)
		if err != nil {
			log.Fatal(err)
		}

		fmt.Printf("csnap %s compiled with %v on %v/%v\n",
			version, runtime.Version(), runtime.GOOS, runtime.GOARCH)
	},
}

func init() {
	rootCmd.AddCommand(versionCmd)

	versionCmd.Flags().StringVar(&versionFile, "version-file", "VERSION", "Path to the version file")

	// Other flag and configuration settings can be added here.
}

func readVersionFromFile(filePath string) (string, error) {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return "", err
	}

	version := strings.TrimSpace(string(content))
	return version, nil
}
