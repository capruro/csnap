
# CSNAP (Configuration Snapshot) for Linux (RHEL/SUSE)

CSNAP (Configuration Snapshot) is designed to capture various configuration details of a Linux system, specifically tailored for Red Hat (RHEL) and SUSE distributions.

It gathers over 40 configuration files that can prove valuable for pre and post-system reboots. Additionally, having a snapshot of these files is advantageous, especially if you are unfamiliar with the system you are working on.

### Configuration captured
- Hardware summary
- Active/inactive services
- Hosts information
- DNS configuration
- Device information
- Module information
- Network interfaces
- Kernel parameters
- Filesystem table
- ... (and more)

## Usage
### Creating a Snapshot
Run the script as a superuser (root) to capture the system configuration.
To create a configuration snapshot, execute the following command:

```
sudo csnap make
```
This will generate detailed logs in the specified directories.

### Comparing Snapshots
To compare two snapshots, use the comparecsnap function in the script. Follow the on-screen instructions to select the snapshots you want to compare.

```
csnap compare
```
