#!/bin/bash

set -u

# Function to display a message and exit the script if necessary
abort() {
  printf "🚨 %s\n" "$@" >&2
  exit 1
}

# Functions to display user-friendly messages
ohai() {
  printf "🍻 \033[1;34m==>\033[1;39m %s\033[0m\n" "$1"
}

warn() {
  printf "⚠️ \033[1;31mWarning:\033[0m %s\n" "$1" >&2
}

# Usage guide if the script is incorrectly invoked
usage() {
  cat <<EOS
💡 Workbrew Installer for macOS
Usage: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/workbrew/install/HEAD/install.sh)" --api-key YOUR_API_KEY
    --api-key YOUR_API_KEY    🔑 Provide your unique Workbrew API key.
    -h, --help                🆘 Display this message.
EOS
  exit "${1:-0}"
}

# Verify that the user has provided an API key
if [[ "$#" -ne 2 ]] || [[ "$1" != "--api-key" ]]; then
  usage
fi

API_KEY="$2"
if [[ -z "$API_KEY" ]]; then
  abort "API key is required to proceed 🚧. Please provide your unique API key."
fi

# Verify that the script is being run on macOS
OS="$(uname)"
if [[ "$OS" != "Darwin" ]]; then
  abort "Workbrew is only supported on macOS 🖥️. Please use a macOS device to run this installer."
fi

ohai "Welcome to Workbrew! 🍻 Setting up your device for optimal performance."

# Check for Xcode Command Line Tools (CLT) on macOS
check_xcode_clt() {
  ohai "Checking for Xcode Command Line Tools... 🔍"
  if ! xcode-select -p &>/dev/null; then
    echo "🛠️ Xcode Command Line Tools not found. Installing..."
    touch "/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    CLT_PACKAGE="$(softwareupdate -l | grep -B 1 "Command Line Tools" | awk -F"*" '/^ *\*/ {print $2}' | sed -e 's/^ *Label: //' -e 's/^ *//' | sort -V | tail -n1)"
    sudo softwareupdate -i "$CLT_PACKAGE" --verbose
    rm -f "/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  fi
  ohai "✅ Xcode Command Line Tools are installed!"
}

# Install Workbrew and configure the agent with the provided API key
install_workbrew() {
  ohai "Starting Workbrew installation... 🚀"

  # Create necessary directories and apply permissions
  sudo mkdir -pv "/opt/workbrew/home/Library/Application Support/com.workbrew.workbrew-agent"
  sudo chmod 700 "/opt/workbrew/home/Library/Application Support/com.workbrew.workbrew-agent"

  # Save the API key securely
  echo "$API_KEY" | sudo tee "/opt/workbrew/home/Library/Application Support/com.workbrew.workbrew-agent/api_key" >/dev/null

  # Download and install the Workbrew agent
  echo "⬇️  Downloading the Workbrew agent package..."
  curl -O https://console.workbrew.com/downloads/macos/workbrew-agent.pkg || abort "Failed to download Workbrew agent package ❌."
  echo "📦 Installing the Workbrew agent package..."
  sudo installer -pkg workbrew-agent.pkg -target / || abort "Installation of Workbrew package failed 🚫."
  ohai "✅ Workbrew installation is complete! 🎉"
}

# Monitor the Workbrew agent logs for any errors during setup
monitor_logs() {
  LOG_FILE="/opt/workbrew/var/log/workbrew-agent.log"
  echo "👀 Monitoring Workbrew logs for any issues..."

  # Start background monitoring
  tail -Fn0 "$LOG_FILE" | while read line; do
    if [[ "$line" == *"ERROR"* ]]; then
      echo "⚠️  Uh-oh! Error detected in Workbrew logs: $line"
      echo "💡 Need help? Check out https://workbrew.com for support."
    fi
  done &
}

# Main script execution steps
check_xcode_clt
install_workbrew
monitor_logs

ohai "🎉 Workbrew setup is complete on macOS! Log monitoring is active."
echo "For more information, visit: https://workbrew.com 🍻"
