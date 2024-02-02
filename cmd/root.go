/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"os"

	"github.com/spf13/cobra"
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "csnap",
	Short: "Configuration Snapshot",
	Long: `CSNAP (Configuration Snapshot)
is designed to capture various configuration details of a Linux system,
specifically tailored for Red Hat (RHEL) and SUSE distributions.

It gathers over 40 configuration files that can prove valuable for pre and post-system reboots.
Additionally, having a snapshot of these files is advantageous, especially if you are unfamiliar with the system you are working on.

Configuration captured
Hardware summary
Active/inactive services
Hosts information
DNS configuration
Device information
Module information
Network interfaces
Kernel parameters
Filesystem table
... (and more)`,
	// Uncomment the following line if your bare application
	// has an action associated with it:
	// Run: func(cmd *cobra.Command, args []string) { },
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

func init() {
	// Here you will define your flags and configuration settings.
	// Cobra supports persistent flags, which, if defined here,
	// will be global for your application.

	// rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.csnap.yaml)")

	// Cobra also supports local flags, which will only run
	// when this action is called directly.
	rootCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}
