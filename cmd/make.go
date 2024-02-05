/*
Copyright © 2024 Capruro me@capruro.com
*/
package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"runtime"
	"strings"

	"github.com/spf13/cobra"
)

// HOSTInfo struct represents operating system information
type HOSTInfo struct {
	Name        string
	Version     string
	ModelCPU    string
	NRCPUCore   string
	NRNIC       string
	NRFC        string
	Vendor      string
	Type        string
	LPAR        string
	VM          string
	Control     string
	MemTotal    string
	MemFree     string
	SwapTotal   string
	SwapFree    string
	MemActive   string
	MemInactive string
	RunLevel    string
	Date        string
	DateUTC     string
	Uptime      string
	Kernel      string
	Serial      string
}

var hostInfo *HOSTInfo

var makeCmd = &cobra.Command{
	Use:   "make",
	Short: "Make a new snapshot",
	Long:  `The "make" option creates a new snapshot`,
	Run:   makeRun,
}

func collectOSDetails() (*HOSTInfo, error) {
	if hostInfo != nil {
		return hostInfo, nil
	}

	hostInfo = &HOSTInfo{
		Name:    runtime.GOOS,
		Version: runtime.GOARCH,
	}

	fmt.Printf("Operating System: %s\n", hostInfo.Name)
	fmt.Printf("Architecture: %s\n", hostInfo.Version)

	// Check for /proc/sysinfo
	if _, err := os.Stat("/proc/sysinfo"); err == nil {
		hostInfo.Name = "MAINFRAME"
		hostInfo.ModelCPU = executeCommand("cat", "/proc/cpuinfo | grep ^vendor_id | head -n1 | awk '{print $NF}'")
		hostInfo.NRCPUCore = executeCommand("cat", "/proc/cpuinfo | grep ^# | head -n1 | awk '{print $NF}'")
		hostInfo.NRNIC = executeCommand("ls -l /sys/devices/qeth | grep ^d | wc -l")
		hostInfo.NRFC = "0"
		hostInfo.Vendor = "IBM"
		hostInfo.Type = executeCommand("cat", "/proc/sysinfo | grep ^Type: | awk '{print $NF}'")
		hostInfo.LPAR = executeCommand("cat", "/proc/sysinfo | grep ^LPAR\\ Name: | awk '{print $NF}'")
		hostInfo.VM = executeCommand("cat", "/proc/sysinfo | grep ^VM00\\ Name: | awk '{print $NF}'")
		hostInfo.Control = executeCommand("cat", "/proc/sysinfo | grep Control | awk '{print substr($0, index($0,$4)) }' | awk '{print $1,$2}'")
	} else {
		hostInfo.ModelCPU = executeCommand("cat", "/proc/cpuinfo | grep -m 1 \"model name\" | cut -d\":\" -f 2 | sed 's/^[ \t]*//;s/[ \t]*$//' | tr -s ' ' ' '")
		hostInfo.NRCPUCore = executeCommand("cat", "/proc/cpuinfo | grep processor | wc -l")
		hostInfo.NRNIC = executeCommand("lspci | grep \"Ethernet\" | wc -l 2> /dev/null")
		hostInfo.NRFC = executeCommand("lspci | grep \"Fibre\" | wc -l 2> /dev/null")

		// Check for dmidecode
		if _, err := exec.LookPath("dmidecode"); err == nil {
			hostInfo.Vendor = executeCommand("dmidecode | grep \"System Information\" -A1 | tail -n1 | cut -d: -f2 | sed 's/^[ \t]*//;s/[ \t]*$//'")
			hostInfo.Vendor = strings.TrimSpace(hostInfo.Vendor)
			if hostInfo.Vendor == "" {
				hostInfo.Vendor = "N/A"
			}

			hostInfo.Type = executeCommand("dmidecode | grep \"System Information\" -A2 | tail -n1 | cut -d: -f2 | sed 's/^[ \t]*//;s/[ \t]*$//'")
			hostInfo.Type = strings.TrimSpace(hostInfo.Type)
			if hostInfo.Type == "" {
				hostInfo.Type = "N/A"
			}

			hostInfo.Serial = executeCommand("dmidecode | grep \"System Information\" -A4 | tail -n1 | cut -d: -f2 | sed 's/^[ \t]*//;s/[ \t]*$//'")
			hostInfo.Serial = strings.TrimSpace(hostInfo.Serial)
			if hostInfo.Serial == "" {
				hostInfo.Serial = "N/A"
			}
		} else {
			hostInfo.Vendor = "N/A"
			hostInfo.Type = "N/A"
			hostInfo.Serial = "N/A"
		}
	}

	hostInfo.MemTotal = executeCommand("cat", "/proc/meminfo | grep MemTotal | cut -d\":\" -f 2 | awk '{print $1,$2}'")
	hostInfo.MemFree = executeCommand("cat", "/proc/meminfo | grep MemFree | cut -d\":\" -f 2 | awk '{print $1,$2}'")
	hostInfo.SwapTotal = executeCommand("cat", "/proc/meminfo | grep SwapTotal | cut -d\":\" -f 2 | awk '{print $1,$2}'")
	hostInfo.SwapFree = executeCommand("cat", "/proc/meminfo | grep SwapFree | cut -d\":\" -f 2 | awk '{print $1,$2}'")
	hostInfo.MemActive = executeCommand("cat", "/proc/meminfo | grep Active | cut -d\":\" -f 2 | head -n1 | awk '{print $1,$2}'")
	hostInfo.MemInactive = executeCommand("cat", "/proc/meminfo | grep Inactive | cut -d\":\" -f 2 | head -n1 | awk '{print $1,$2}'")
	hostInfo.RunLevel = executeCommand("runlevel | awk '{print $NF}'")
	hostInfo.Date = executeCommand("date")
	hostInfo.DateUTC = executeCommand("date -u")
	hostInfo.Uptime = executeCommand("uptime | cut -d, -f1 | tr -s ' ' ' ' | sed 's/^[ \t]*//;s/[ \t]*$//'")
	hostInfo.Kernel = executeCommand("uname -r")

	return hostInfo, nil
}

func executeCommand(command string, args ...string) string {
	// Get the current environment
	env := os.Environ()

	// Append the desired PATH to the environment
	env = append(env, "PATH=/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin") // Add any necessary paths

	// Set the modified environment for the command
	cmd := exec.Command(command, args...)
	cmd.Env = env

	// Run the command and capture its output
	output, err := cmd.Output()
	if err != nil {
		fmt.Printf("Error executing command %s: %s\n", command, err)
		return ""
	}

	return strings.TrimSpace(string(output))
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

func collectNetworkDetails() {
	hostInfo, err := collectOSDetails()
	if err != nil {
		fmt.Println(err)
		return
	}

	fmt.Printf("\nNetwork Configuration Details for %s:\n", hostInfo.Name)

	switch hostInfo.Name {
	case "windows":
		collectWindowsNetworkDetails()
	case "linux":
		collectLinuxNetworkDetails()
	case "darwin":
		collectMacNetworkDetails()
	default:
		fmt.Println("Network configuration details not supported for this operating system.")
	}
}

func collectWindowsNetworkDetails() {
	fmt.Println("Windows-specific network details...")

	// Use specific Windows commands or system calls to gather network information.
	cmd := exec.Command("ipconfig", "/all")
	output, err := cmd.Output()
	if err != nil {
		fmt.Println("Error collecting network details on Windows:", err)
		return
	}

	fmt.Println(string(output))
}

func collectLinuxNetworkDetails() {
	fmt.Println("Linux-specific network details...")

	// Use specific Linux commands or system calls to gather network information.
	cmd := exec.Command("/usr/bin/ip", "a")
	output, err := cmd.Output()
	if err != nil {
		fmt.Println("Error collecting network details on Linux:", err)
		return
	}

	fmt.Println(string(output))
}

func collectMacNetworkDetails() {
	fmt.Println("macOS-specific network details...")

	// Use specific macOS commands or system calls to gather network information.
	cmd := exec.Command("ifconfig")
	output, err := cmd.Output()
	if err != nil {
		fmt.Println("Error collecting network details on macOS:", err)
		return
	}

	fmt.Println(string(output))
}

func makeRun(cmd *cobra.Command, args []string) {
	if err := checkRoot(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	// Call the function to collect OS details
	_, err := collectOSDetails()
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	// Call the function to collect network details
	hostInfo, err := collectOSDetails()
	if err != nil {
		fmt.Println(err)
		return
	}

	// Print the collected host information
	fmt.Printf("Model CPU: %s\n", hostInfo.ModelCPU)
	fmt.Printf("Number of CPU Cores: %s\n", hostInfo.NRCPUCore)
	fmt.Printf("Number of NICs: %s\n", hostInfo.NRNIC)
	fmt.Printf("Number of FC: %s\n", hostInfo.NRFC)
	fmt.Printf("Vendor: %s\n", hostInfo.Vendor)
	fmt.Printf("Type: %s\n", hostInfo.Type)
	fmt.Printf("LPAR: %s\n", hostInfo.LPAR)
	fmt.Printf("VM: %s\n", hostInfo.VM)
	fmt.Printf("Control: %s\n", hostInfo.Control)
	fmt.Printf("Memory Total: %s\n", hostInfo.MemTotal)
	fmt.Printf("Memory Free: %s\n", hostInfo.MemFree)
	fmt.Printf("Swap Total: %s\n", hostInfo.SwapTotal)
	fmt.Printf("Swap Free: %s\n", hostInfo.SwapFree)
	fmt.Printf("Memory Active: %s\n", hostInfo.MemActive)
	fmt.Printf("Memory Inactive: %s\n", hostInfo.MemInactive)
	fmt.Printf("Run Level: %s\n", hostInfo.RunLevel)
	fmt.Printf("Date: %s\n", hostInfo.Date)
	fmt.Printf("Date UTC: %s\n", hostInfo.DateUTC)
	fmt.Printf("Uptime: %s\n", hostInfo.Uptime)
	fmt.Printf("Kernel Version: %s\n", hostInfo.Kernel)
	collectNetworkDetails()
}

func init() {
	rootCmd.AddCommand(makeCmd)
}
