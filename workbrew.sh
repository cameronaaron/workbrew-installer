#!/bin/bash

set -euo pipefail

# Function to print an error message and exit the script.
abort() {
  printf "🚨 %s\n" "$*" >&2
  exit 1
}

# Function to print an informational message.
ohai() {
  printf "🍻 \033[1;34m==>\033[1;39m %s\033[0m\n" "$1"
}

# Function to print a warning message.
warn() {
  printf "⚠️ \033[1;31mWarning:\033[0m %s\n" "$1" >&2
}

# Function to display usage information.
usage() {
  cat <<EOS
💡 Workbrew Installer for macOS
Usage: ./workbrew.sh --api-key YOUR_API_KEY
    --api-key YOUR_API_KEY    🔑 Provide your unique Workbrew API key.
    -h, --help                🆘 Display this message.
EOS
  exit "${1:-0}"
}

# Function to parse arguments.
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --api-key)
        if [[ -n "${2:-}" ]]; then
          API_KEY="$2"
          shift 2
        else
          abort "Error: --api-key requires a value 🚨."
        fi
        ;;
      -h|--help)
        usage 0
        ;;
      *)
        abort "Unknown option: $1 🚨."
        ;;
    esac
  done

  if [[ -z "${API_KEY:-}" ]]; then
    usage 1
  fi
}

# Function to check if the OS is macOS.
check_os() {
  OS=$(uname)
  if [[ "$OS" != "Darwin" ]]; then
    abort "Workbrew is only supported on macOS 🖥️. Please use a macOS device to run this installer."
  fi
}

# Function to check and install Xcode Command Line Tools.
check_xcode_clt() {
  ohai "Checking for Xcode Command Line Tools... 🔍"
  if ! xcode-select -p &>/dev/null; then
    echo "🛠️ Xcode Command Line Tools not found. Installing..."
    touch "/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    CLT_PACKAGE=$(softwareupdate -l | grep -B 1 "Command Line Tools" | awk -F"*" '/^ *\*/ {print $2}' | sed 's/^ *Label: //' | sort -V | tail -n1)
    if [[ -z "$CLT_PACKAGE" ]]; then
      abort "No Command Line Tools package found for installation 🚫."
    fi
    sudo softwareupdate -i "$CLT_PACKAGE" --verbose || abort "Failed to install Xcode Command Line Tools 🚫."
    rm -f "/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  fi
  ohai "✅ Xcode Command Line Tools are installed!"
}

# Function to install Workbrew.
install_workbrew() {
  ohai "Starting Workbrew installation... 🚀"

  # Create necessary directories and apply permissions
  sudo mkdir -pv "/opt/workbrew/home/Library/Application Support/com.workbrew.workbrew-agent"
  sudo chmod 700 "/opt/workbrew/home/Library/Application Support/com.workbrew.workbrew-agent"

  # Save the API key securely
  echo "$API_KEY" | sudo tee "/opt/workbrew/home/Library/Application Support/com.workbrew.workbrew-agent/api_key" >/dev/null

  # Use the download URL directly
  PACKAGE_URL="https://console.workbrew.com/downloads/macos"

  echo "⬇️  Downloading the Workbrew agent package..."

  # Create temporary directory for download
  INSTALL_DIR=$(mktemp -d)
  pushd "$INSTALL_DIR" >/dev/null

  # Download the package, following redirects, saving with original filename
  curl -L -O -J "$PACKAGE_URL" || abort "Failed to download Workbrew agent package ❌."

  # Determine the downloaded package name
  PACKAGE_NAME=$(ls Workbrew-*.pkg | head -n 1)

  # If PACKAGE_NAME is empty, fall back to default
  if [[ -z "$PACKAGE_NAME" ]]; then
    PACKAGE_NAME="Workbrew.pkg"
    mv "$(ls *.pkg | head -n1)" "$PACKAGE_NAME"
  fi

  # Verify that the downloaded file exists
  if [[ ! -f "$PACKAGE_NAME" ]]; then
    abort "Downloaded Workbrew package not found ❌."
  fi

  # Optional: Verify the integrity of the package (requires pkgutil)
  if ! pkgutil --check-signature "$PACKAGE_NAME" &>/dev/null; then
    abort "Downloaded package is invalid or corrupted ❌."
  fi

  echo "📦 Installing the Workbrew agent package..."

  # Install the package
  sudo installer -pkg "$PACKAGE_NAME" -target / || abort "Installation of Workbrew package failed 🚫."

  # Clean up
  popd >/dev/null
  rm -rf "$INSTALL_DIR"

  ohai "✅ Workbrew installation is complete! 🎉"
}

# Monitor the Workbrew agent logs for any errors during setup
monitor_logs() {
  LOG_FILE="/opt/workbrew/var/log/workbrew-agent.log"
  echo "👀 Monitoring Workbrew logs for any issues..."

  # Ensure the log file exists before tailing
  if [[ ! -f "$LOG_FILE" ]]; then
    warn "Log file $LOG_FILE does not exist yet. Waiting for it to be created..."
    until [[ -f "$LOG_FILE" ]]; do
      sleep 1
    done
  fi

  tail -Fn0 "$LOG_FILE" | while read -r line; do
    if [[ "$line" == *"ERROR"* ]]; then
      echo "⚠️  Uh-oh! Error detected in Workbrew logs: $line"
      echo "💡 Need help? Check out https://workbrew.com for support."
    fi
  done &
}

# Ensure cleanup on exit
trap 'rm -f "/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"' EXIT

# Main script execution
parse_args "$@"
check_os
ohai "Welcome to Workbrew! 🍻 Setting up your device for optimal performance."
check_xcode_clt
install_workbrew
monitor_logs

ohai "🎉 Workbrew setup is complete on macOS! Log monitoring is active."
echo "For more information, visit: https://workbrew.com 🍻"
