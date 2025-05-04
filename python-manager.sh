#!/bin/bash

# Python Installation/Removal Script
# This script automates the process of installing or removing Python versions
# Must be run with sudo privileges

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo privileges."
  exit 1
fi

# Function to display progress
function display_progress {
  local step=$1
  local total=$2
  local message=$3
  echo "---------------------------------------------"
  echo "Step $step of $total: $message"
  echo "---------------------------------------------"
}

# Function to install Python
function install_python {
  local PYTHON_VERSION=$1
  local TOTAL_STEPS=7

  # Step 1: Version already selected
  display_progress 1 "$TOTAL_STEPS" "Selected Python version $PYTHON_VERSION"

  # Step 2: Update system packages
  display_progress 2 "$TOTAL_STEPS" "Updating system packages"
  echo "Running: sudo apt update"
  if ! apt update -y; then
    echo "Error: Failed to update packages. Exiting."
    return 1
  fi

  # Step 3: Install prerequisites
  display_progress 3 "$TOTAL_STEPS" "Installing prerequisites"
  echo "Running: sudo apt install build-essential and other dependencies"
  if ! apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev; then
    echo "Error: Failed to install prerequisites. Exiting."
    return 1
  fi

  # Step 4: Download Python source
  display_progress 4 "$TOTAL_STEPS" "Downloading Python source"
  PYTHON_URL="https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz"
  PYTHON_TAR="Python-$PYTHON_VERSION.tgz"
  PYTHON_DIR="Python-$PYTHON_VERSION"

  echo "Downloading Python $PYTHON_VERSION from $PYTHON_URL"
  if ! wget --progress=bar:force:noscroll "$PYTHON_URL"; then
    echo "Error: Failed to download Python source. Check the version number and internet connection."
    return 1
  fi

  # Step 5: Extract Python source
  display_progress 5 "$TOTAL_STEPS" "Extracting Python source"
  echo "Extracting $PYTHON_TAR"
  if ! tar -xvf "$PYTHON_TAR"; then
    echo "Error: Failed to extract Python source. Exiting."
    return 1
  fi

  # Check if directory exists
  if [ ! -d "$PYTHON_DIR" ]; then
    echo "Error: Directory $PYTHON_DIR not found after extraction. Exiting."
    return 1
  fi

  # Step 6: Configure and compile Python
  display_progress 6 "$TOTAL_STEPS" "Configuring and compiling Python"

  # Use subshell to avoid having to cd back
  (
    if ! cd "$PYTHON_DIR"; then
      echo "Error: Could not change to directory $PYTHON_DIR. Exiting."
      return 1
    fi

    echo "Configuring Python with optimizations"
    if ! ./configure --enable-optimizations; then
      echo "Error: Configuration failed. Exiting."
      return 1
    fi

    # Determine number of cores to use for make
    CORES=2 # Default fallback
    CORE_COUNT=$(nproc 2>/dev/null)

    if [ -n "$CORE_COUNT" ] && [ "$CORE_COUNT" -gt 0 ]; then
      # Calculate 80% of available cores, round down
      CORES=$((CORE_COUNT * 8 / 10))
      # Ensure at least 1 core
      if [ "$CORES" -lt 1 ]; then
        CORES=1
      fi
      echo "Using $CORES cores for compilation (80% of $CORE_COUNT available cores)"
    else
      echo "Could not determine core count, using default of $CORES cores"
    fi

    echo "Compiling Python (this may take some time)"
    echo "Running: make -j $CORES"
    if ! make -j "$CORES"; then
      echo "Error: Compilation failed. Exiting."
      return 1
    fi

    echo "Installing Python"
    echo "Running: make altinstall"
    if ! make altinstall; then
      echo "Error: Installation failed. Exiting."
      return 1
    fi
  ) || return 1

  # Step 7: Reload shell and verify installation
  display_progress 7 "$TOTAL_STEPS" "Reloading shell and verifying installation"

  # Get major and minor version for the executable name (e.g., 3.10)
  PYTHON_MAJOR_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f1,2)
  PYTHON_EXECUTABLE="python$PYTHON_MAJOR_MINOR"

  # Reload shell configurations
  echo "Attempting to reload shell configurations"
  # shellcheck disable=SC1090,SC1091
  if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc" 2>/dev/null || echo "Note: Couldn't reload .bashrc within script"
  fi

  # shellcheck disable=SC1090,SC1091
  if [ -f "$HOME/.zshrc" ]; then
    source "$HOME/.zshrc" 2>/dev/null || echo "Note: Couldn't reload .zshrc within script"
  fi

  # Verify Python installation
  echo "Verifying Python installation"
  if command -v "$PYTHON_EXECUTABLE" &>/dev/null; then
    echo "Python $PYTHON_VERSION installed successfully!"
    echo "Python version details:"
    "$PYTHON_EXECUTABLE" --version
  else
    echo "Python executable $PYTHON_EXECUTABLE not found in PATH."
    echo "You may need to log out and log back in to update your PATH."
    echo "You can manually verify with: $PYTHON_EXECUTABLE --version"
  fi

  echo "Installation complete!"
  echo "Note: You may need to log out and log back in for shell changes to take effect."
  echo "You can run '$PYTHON_EXECUTABLE --version' to verify your installation."

  # Clean up
  echo "Do you want to remove the downloaded archive and source directory? (y/n)"
  read -r -p "This will remove $PYTHON_TAR and $PYTHON_DIR: " CLEAN_UP

  if [[ $CLEAN_UP == "y" || $CLEAN_UP == "Y" ]]; then
    echo "Cleaning up downloaded files..."
    rm -f "$PYTHON_TAR"
    rm -rf "${PYTHON_DIR:?}"
    echo "Cleanup complete."
  fi

  return 0
}

# Function to remove Python
function remove_python {
  local PYTHON_VERSION=$1
  local TOTAL_STEPS=2

  # Get major and minor version for the executable name (e.g., 3.10)
  PYTHON_MAJOR_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f1,2)
  PYTHON_EXECUTABLE="python$PYTHON_MAJOR_MINOR"

  # Step 1: Check if Python version exists
  display_progress 1 "$TOTAL_STEPS" "Checking if Python $PYTHON_VERSION is installed"

  # Get the installation path
  PYTHON_PATH=$(which "$PYTHON_EXECUTABLE" 2>/dev/null)

  if [ -z "$PYTHON_PATH" ]; then
    echo "Error: Python $PYTHON_VERSION ($PYTHON_EXECUTABLE) not found in PATH."
    echo "Cannot remove a version that is not installed."
    return 1
  fi

  echo "Found Python installation at: $PYTHON_PATH"

  # Determine installation prefix (usually /usr/local)
  INSTALL_PREFIX=$(dirname "$(dirname "$PYTHON_PATH")")
  echo "Installation prefix appears to be: $INSTALL_PREFIX"

  # Step 2: Remove Python files
  display_progress 2 "$TOTAL_STEPS" "Removing Python $PYTHON_VERSION"

  echo "This will remove Python $PYTHON_VERSION from your system."
  echo "Warning: This action cannot be undone!"
  read -r -p "Are you sure you want to continue? (y/n): " CONFIRM

  if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
    echo "Operation cancelled."
    return 1
  fi

  echo "Removing Python $PYTHON_VERSION files..."

  # Remove binaries
  rm -fv "$INSTALL_PREFIX/bin/$PYTHON_EXECUTABLE"
  rm -fv "$INSTALL_PREFIX/bin/pip$PYTHON_MAJOR_MINOR"
  rm -fv "$INSTALL_PREFIX/bin/idle$PYTHON_MAJOR_MINOR"
  rm -fv "$INSTALL_PREFIX/bin/pydoc$PYTHON_MAJOR_MINOR"
  rm -fv "$INSTALL_PREFIX/bin/2to3-$PYTHON_MAJOR_MINOR"

  # Remove libraries
  rm -rfv "${INSTALL_PREFIX:?}/lib/$PYTHON_EXECUTABLE"
  rm -fv "$INSTALL_PREFIX/lib/libpython$PYTHON_MAJOR_MINOR"*.a
  rm -fv "$INSTALL_PREFIX/lib/pkgconfig/python-$PYTHON_MAJOR_MINOR"*.pc

  # Remove include files
  rm -rfv "$INSTALL_PREFIX/include/$PYTHON_EXECUTABLE"

  # Remove man pages
  rm -fv "$INSTALL_PREFIX/share/man/man1/$PYTHON_EXECUTABLE.1"

  echo "Python $PYTHON_VERSION removal complete!"
  return 0
}

# Main menu function
function show_menu {
  clear
  echo "========================================"
  echo "        Python Manager Script"
  echo "========================================"
  echo "1. Install Python"
  echo "2. Remove Python"
  echo "3. Exit"
  echo "========================================"
  read -r -p "Please select an option [1-3]: " MENU_OPTION

  case $MENU_OPTION in
  1)
    read -r -p "Enter the Python version you want to install (e.g., 3.10.0): " PYTHON_VERSION
    if [[ ! $PYTHON_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "Invalid version format. Please use format like 3.10.0"
      read -r -p "Press Enter to continue..."
      show_menu
    else
      install_python "$PYTHON_VERSION"
      read -r -p "Press Enter to return to the menu..."
      show_menu
    fi
    ;;
  2)
    read -r -p "Enter the Python version you want to remove (e.g., 3.10.0): " PYTHON_VERSION
    if [[ ! $PYTHON_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "Invalid version format. Please use format like 3.10.0"
      read -r -p "Press Enter to continue..."
      show_menu
    else
      remove_python "$PYTHON_VERSION"
      read -r -p "Press Enter to return to the menu..."
      show_menu
    fi
    ;;
  3)
    echo "Exiting. Goodbye!"
    exit 0
    ;;
  *)
    echo "Invalid option. Please try again."
    read -r -p "Press Enter to continue..."
    show_menu
    ;;
  esac
}

show_menu
