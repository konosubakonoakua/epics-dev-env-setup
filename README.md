# EPICS Development Environment Setup

This repository contains scripts to automate the installation and configuration of the EPICS (Experimental Physics and Industrial Control System) base and synApps modules on Linux systems.

## Overview

The setup is divided into two main parts:
1. **EPICS Base**: The core of the EPICS control system.
2. **synApps**: A collection of EPICS support modules (asyn, autosave, etc.).

## Prerequisites

- A Linux system (Debian/Ubuntu recommended).
- Internet access for downloading source code and dependencies.
- Sudo privileges for installing system-wide dependencies and setting up environment variables.

## Installation

### 1. Install EPICS Base

The `install_epics.sh` script handles the download, compilation, and environment setup for EPICS Base.

```bash
# Create directory then give privileges
sudo mkdir -p /opt/epics
sudo chown -R $USER:$USER /opt/epics

# Make the script executable
chmod +x install_epics.sh

# Run the script (defaults to version 7.0.9)
./install_epics.sh
```

**Key features:**
- Automatically detects system architecture.
- Installs necessary build dependencies.
- Installs EPICS Base to `/opt/epics/base`.
- Configures environment variables in `/etc/profile.d/epics.sh`.

### 2. Install synApps

The `install_synapps.sh` script clones and configures various synApps modules. It requires EPICS Base to be installed first.

```bash
# Make the script executable
chmod +x install_synapps.sh

# Run the script
./install_synapps.sh
```

**Key features:**
- Clones modules from GitHub.
- Configures `RELEASE` files automatically.
- Installs to `/opt/epics/synApps`.
- Creates a symbolic link at `/opt/epics/synApps/support`.

## Environment Setup

After installation, you need to reload your shell environment:

```bash
source /etc/profile.d/epics.sh
```

The script also adds a source command to your `~/.bashrc` via `~/.epicsrc`.
If you use `PACSPY`, you will also need:
```bash
export PCAS=/opt/epics/synApps/support/pcas-v4-13-3/

```

## Verification

To verify the installation, you can use the following commands:

```bash
# Check EPICS Base tools
softIoc --help
caget --version

# Check environment variables
echo $EPICS_BASE
echo $EPICS_HOST_ARCH
```

## Directory Structure

Default installation path: `/opt/epics`

```
/opt/epics/
├── base -> base-7.0.9/
├── base-7.0.9/
└── synApps/
    ├── synApps-R6-3/
    └── support -> synApps-R6-3/support
```
