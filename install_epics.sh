#!/bin/bash

# EPICS Base Installation Script
# Supports: x86_64, x86, arm, aarch64 architectures
# Environment: /etc/profile.d/epics.sh

set -e # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

# Configuration
EPICS_BASE_VERSION="${1:-7.0.9}"
EPICS_DIR="/opt/epics"
DOWNLOAD_URL="https://epics-controls.org/download/base/base-${EPICS_BASE_VERSION}.tar.gz"
ACTUAL_DIR="${EPICS_DIR}/base-${EPICS_BASE_VERSION}"
SYMLINK_DIR="${EPICS_DIR}/base"
CURRENT_USER=$(whoami)
CURRENT_GROUP=$(id -gn $CURRENT_USER)

# Detect and set EPICS host architecture
detect_architecture() {
  local arch=$(uname -m)
  local kernel=$(uname -s)

  case "${arch}" in
  "x86_64")
    EPICS_HOST_ARCH="linux-x86_64"
    ;;
  "i386" | "i486" | "i586" | "i686")
    EPICS_HOST_ARCH="linux-x86"
    ;;
  "armv7l" | "armv6l")
    EPICS_HOST_ARCH="linux-arm"
    ;;
  "aarch64")
    EPICS_HOST_ARCH="linux-aarch64"
    ;;
  *)
    log_warning "Unsupported architecture: ${arch}, attempting linux-x86_64"
    EPICS_HOST_ARCH="linux-x86_64"
    ;;
  esac

  log_info "Detected architecture: ${arch} -> EPICS_HOST_ARCH: ${EPICS_HOST_ARCH}"
}

# Check if running as root for system-wide installation
check_privileges() {
  if [[ $EUID -eq 0 ]]; then
    log_info "Running with root privileges - will install system-wide"
  else
    log_warning "Running without root privileges - may require sudo for system operations"
  fi
}

# Detect operating system and install dependencies
install_dependencies() {
  log_info "Installing EPICS build dependencies..."

  if [[ -f /etc/redhat-release ]]; then
    log_info "Detected CentOS/RHEL system"
    sudo yum update -y
    sudo yum install -y gcc gcc-c++ make tar gzip wget \
      readline-devel kernel-devel libX11-devel libXext-devel perl
  elif [[ -f /etc/debian_version ]]; then
    log_info "Detected Debian/Ubuntu system"
    sudo apt-get update
    sudo apt-get install -y gcc g++ make tar gzip wget \
      libreadline-dev build-essential libx11-dev libxext-dev perl
  else
    log_warning "Unknown OS - attempting to install basic build tools"
    # Try generic package managers
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y build-essential libreadline-dev tar wget
    elif command -v yum >/dev/null 2>&1; then
      sudo yum update -y
      sudo yum install -y gcc gcc-c++ make readline-devel
    else
      log_warning "Please manually install: gcc, g++, make, libreadline-dev, wget, tar"
    fi
  fi
}

# Create EPICS directory with proper ownership
setup_epics_directory() {
  log_info "Setting up EPICS directory structure"

  # Create /epics directory if it doesn't exist
  if [[ ! -d "${EPICS_DIR}" ]]; then
    sudo mkdir -p "${EPICS_DIR}"
    log_info "Created ${EPICS_DIR} directory"
  fi

  # Change ownership to current user
  sudo chown -R ${CURRENT_USER}:${CURRENT_GROUP} "${EPICS_DIR}"
  log_info "Set ownership of ${EPICS_DIR} to ${CURRENT_USER}:${CURRENT_GROUP}"

  # Ensure proper permissions
  chmod 755 "${EPICS_DIR}"
}

# Download and extract EPICS Base
download_epics() {
  log_info "Downloading EPICS Base ${EPICS_BASE_VERSION}"

  cd "${EPICS_DIR}"

  # Remove existing installation if it exists
  if [[ -d "${ACTUAL_DIR}" ]]; then
    log_warning "Directory ${ACTUAL_DIR} already exists"
    read -p "Overwrite? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -rf "${ACTUAL_DIR}"
    else
      log_info "Installation cancelled"
      exit 0
    fi
  fi

  # Download the package
  log_info "Downloading from ${DOWNLOAD_URL}"
  if wget -O "base-${EPICS_BASE_VERSION}.tar.gz" "${DOWNLOAD_URL}"; then
    log_info "Download completed successfully"
  else
    log_error "Failed to download EPICS Base from ${DOWNLOAD_URL}"
    log_info "Attempting alternative download source..."
    # Try alternative source
    if wget -O "base-${EPICS_BASE_VERSION}.tar.gz" "https://epics.anl.gov/download/base/base-${EPICS_BASE_VERSION}.tar.gz"; then
      log_info "Download from alternative source successful"
    else
      log_error "All download attempts failed"
      exit 1
    fi
  fi

  # Extract the package
  log_info "Extracting EPICS Base"
  tar -xzf "base-${EPICS_BASE_VERSION}.tar.gz"

  # Handle different directory naming conventions
  if [[ ! -d "base-${EPICS_BASE_VERSION}" ]]; then
    extracted_dir=$(tar -tzf "base-${EPICS_BASE_VERSION}.tar.gz" | head -1 | cut -f1 -d"/")
    if [[ -n "$extracted_dir" && -d "$extracted_dir" ]]; then
      mv "$extracted_dir" "base-${EPICS_BASE_VERSION}"
      log_info "Renamed $extracted_dir to base-${EPICS_BASE_VERSION}"
    else
      log_error "Could not find extracted EPICS Base directory"
      exit 1
    fi
  fi

  # Clean up download file
  rm -f "base-${EPICS_BASE_VERSION}.tar.gz"

  # Ensure correct ownership
  chown -R ${CURRENT_USER}:${CURRENT_GROUP} "${ACTUAL_DIR}"
  log_info "EPICS Base extracted to ${ACTUAL_DIR}"
}

# Create symbolic link
create_symlink() {
  log_info "Creating symbolic link"

  # Remove existing symlink if it exists
  if [[ -L "${SYMLINK_DIR}" ]]; then
    log_info "Removing existing symbolic link"
    rm -f "${SYMLINK_DIR}"
  fi

  # Create new symbolic link
  ln -sf "${ACTUAL_DIR}" "${SYMLINK_DIR}"
  log_info "Created symbolic link: ${SYMLINK_DIR} -> ${ACTUAL_DIR}"
}

# Build EPICS Base
build_epics() {
  log_info "Building EPICS Base ${EPICS_BASE_VERSION}"

  cd "${ACTUAL_DIR}"

  # Final architecture detection using EPICS tool
  if [[ -f startup/EpicsHostArch ]]; then
    local detected_arch=$(startup/EpicsHostArch)
    if [[ "$detected_arch" != "$EPICS_HOST_ARCH" ]]; then
      log_info "EPICS detected architecture: ${detected_arch} (overriding our detection)"
      EPICS_HOST_ARCH="$detected_arch"
    fi
  fi

  log_info "Building for architecture: ${EPICS_HOST_ARCH}"

  # Build EPICS
  log_info "Starting build process with $(nproc) cores..."
  make -j$(nproc)

  if [[ $? -eq 0 ]]; then
    log_info "Build completed successfully"
    make clean
  else
    log_error "Build failed"
    exit 1
  fi
}

# Setup environment variables in /etc/profile.d/
setup_environment() {
  log_info "Setting up environment variables in /etc/profile.d/"

  # Create system-wide environment setup
  local env_file="/etc/profile.d/epics.sh"

  # Create the file with sudo
  sudo tee "$env_file" >/dev/null <<EOF
#!/bin/bash
# EPICS Environment Configuration
# Generated by EPICS installation script
# Installation date: $(date)
# Version: ${EPICS_BASE_VERSION}

export EPICS_BASE="${SYMLINK_DIR}"
export EPICS_HOST_ARCH=\$(${SYMLINK_DIR}/startup/EpicsHostArch)
export PATH=\${EPICS_BASE}/bin/\${EPICS_HOST_ARCH}:\$PATH

# Channel Access configuration
export EPICS_CA_ADDR_LIST="127.255.255.255"
export EPICS_CA_AUTO_ADDR_LIST="NO"
export EPICS_CA_MAX_ARRAY_BYTES="10000000"
EOF

  # Set proper permissions
  sudo chmod 644 "$env_file"

  # Also create user-specific environment file
  local user_env_file="${HOME}/.epicsrc"
  cat >"$user_env_file" <<EOF
# User-specific EPICS environment
source /etc/profile.d/epics.sh
EOF
  chmod 600 "$user_env_file"

  # Add to bashrc if not already present
  if ! grep -q "epicsrc" "${HOME}/.bashrc"; then
    echo "[[ -f \"${HOME}/.epicsrc\" ]] && source \"${HOME}/.epicsrc\"" >>"${HOME}/.bashrc"
  fi

  # Source the environment for current session
  source "$env_file"
  log_info "Environment configured in ${env_file}"
}

# Verify installation
verify_installation() {
  log_info "Verifying installation..."

  # Check directory ownership
  local dir_owner=$(stat -c "%U:%G" "${EPICS_DIR}")
  if [[ "$dir_owner" == "${CURRENT_USER}:${CURRENT_GROUP}" ]]; then
    log_info "✓ Directory ownership correct: ${dir_owner}"
  else
    log_error "✗ Directory ownership incorrect: ${dir_owner}"
  fi

  # Check symbolic link
  if [[ -L "${SYMLINK_DIR}" && "$(readlink -f ${SYMLINK_DIR})" == "$(readlink -f ${ACTUAL_DIR})" ]]; then
    log_info "✓ Symbolic link correctly points to ${ACTUAL_DIR}"
  else
    log_error "✗ Symbolic link verification failed"
  fi

  # Check if architecture detection works
  local detected_arch=$(${SYMLINK_DIR}/startup/EpicsHostArch)
  if [[ -n "$detected_arch" ]]; then
    log_info "✓ EPICS architecture detection: ${detected_arch}"
    EPICS_HOST_ARCH="$detected_arch"
  else
    log_error "✗ EPICS architecture detection failed"
  fi

  # Check essential binaries
  local bin_dir="${SYMLINK_DIR}/bin/${EPICS_HOST_ARCH}"
  local essential_bins=("softIoc" "caget" "caput")

  for bin in "${essential_bins[@]}"; do
    if [[ -f "${bin_dir}/${bin}" ]]; then
      log_info "✓ Found ${bin}"
    else
      log_warning "⚠ Missing ${bin} in ${bin_dir}"
    fi
  done

  # Test basic functionality
  if command -v softIoc >/dev/null 2>&1; then
    log_info "✓ softIoc command is available in PATH"

    # Quick functionality test
    log_info "Testing basic EPICS functionality..."
    timeout 5s softIoc --help >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
      log_info "✓ EPICS basic functionality test passed"
    else
      log_warning "⚠ EPICS basic functionality test had issues"
    fi
  else
    log_error "softIoc command not found in PATH"
  fi
}

# Display installation summary
show_summary() {
  log_info "=== EPICS Base Installation Complete ==="
  echo "Version: ${EPICS_BASE_VERSION}"
  echo "Installation directory: ${ACTUAL_DIR}"
  echo "Symbolic link: ${SYMLINK_DIR}"
  echo "Architecture: ${EPICS_HOST_ARCH}"
  echo "Owner: ${CURRENT_USER}:${CURRENT_GROUP}"
  echo "Environment: /etc/profile.d/epics.sh"
  echo ""
  echo "Next steps:"
  echo "1. Log out and log back in to reload environment variables"
  echo "2. Or run: source /etc/profile.d/epics.sh"
  echo "3. Test with: softIoc --help"
  echo "4. Test with: caget --version"
  echo ""
}

# Main installation function
main() {
  clear
  log_info "Starting EPICS Base Installation"
  echo "Version: ${EPICS_BASE_VERSION}"
  echo "Target: ${SYMLINK_DIR} -> ${ACTUAL_DIR}"
  echo "Owner: ${CURRENT_USER}:${CURRENT_GROUP}"
  echo ""

  # Check privileges
  check_privileges

  # Installation confirmation
  read -p "Continue with installation? (y/n): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Installation cancelled"
    exit 0
  fi

  # Execute installation steps
  detect_architecture
  install_dependencies
  setup_epics_directory
  download_epics
  create_symlink
  build_epics
  setup_epics_directory
  setup_environment
  verify_installation
  show_summary

  log_info "Installation completed successfully!"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
