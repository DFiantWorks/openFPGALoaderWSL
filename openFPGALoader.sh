#!/bin/bash

# WSL wrapper for openFPGALoader with USB device management
# This script handles Digilent USB device attachment/detachment

set -e  # Exit on any error

# Configuration
DIGILENT_DEVICE_NAME="Digilent USB Device"
MAX_WAIT_TIME=30  # Maximum time to wait for device in seconds

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if usbipd is available
check_usbipd() {
    if ! command -v usbipd &> /dev/null; then
        print_error "usbipd command not found. Please install usbipd-win on Windows."
        print_status "Installation instructions: https://learn.microsoft.com/en-us/windows/wsl/connect-usb#install-the-usbipd-win-project"
        exit 1
    fi
}

# Function to find Digilent device bus ID and extract VID:PID
find_digilent_device() {
    print_status "Searching for Digilent USB device..."
    
    # Get device list from Windows
    local device_list
    device_list=$(powershell.exe -Command "usbipd list" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        print_error "Failed to get USB device list from Windows"
        return 1
    fi
    
    # Extract the line containing Digilent device
    local digilent_line
    digilent_line=$(echo "$device_list" | grep "$DIGILENT_DEVICE_NAME")
    
    if [ -z "$digilent_line" ]; then
        print_error "Digilent USB device not found in device list"
        echo "$device_list"
        return 1
    fi
    
    # Extract bus ID (first column)
    local busid
    busid=$(echo "$digilent_line" | awk '{print $1}')
    
    # Extract VID:PID (second column)
    local vid_pid
    vid_pid=$(echo "$digilent_line" | awk '{print $2}')
    
    # Split VID:PID into separate variables
    local vid
    local pid
    vid=$(echo "$vid_pid" | cut -d: -f1)
    pid=$(echo "$vid_pid" | cut -d: -f2)
    
    if [ -z "$vid" ] || [ -z "$pid" ]; then
        print_error "Failed to extract VID:PID from device line: $digilent_line"
        return 1
    fi
    
    print_success "Found Digilent device with bus ID: $busid, VID:PID: $vid:$pid"
    
    # Store VID and PID in global variables for use by other functions
    DIGILENT_VID="$vid"
    DIGILENT_PID="$pid"
    
    echo "$busid"
}

# Function to bind USB device
bind_usb_device() {
    local busid="$1"
    
    print_status "Binding USB device with bus ID: $busid"
    
    # Bind the device
    powershell.exe -Command "usbipd bind --busid $busid" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        print_error "Failed to bind USB device"
        return 1
    fi
    
    print_success "USB device bound successfully"
}

# Function to attach USB device to WSL
attach_usb_device() {
    local busid="$1"
    
    print_status "Attaching USB device to WSL..."
    
    # Attach the device to WSL
    powershell.exe -Command "usbipd attach --wsl --busid $busid" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        print_error "Failed to attach USB device to WSL"
        return 1
    fi
    
    print_success "USB device attached to WSL"
}

# Function to wait for device to appear in WSL
wait_for_device_in_wsl() {
    local busid="$1"
    local start_time=$(date +%s)
    
    print_status "Waiting for device to appear in WSL..."
    
    while true; do
        # Check if device is visible in WSL
        if lsusb | grep -q "$DIGILENT_VID:$DIGILENT_PID"; then
            print_success "Device detected in WSL"
            return 0
        fi
        
        # Check timeout
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -ge $MAX_WAIT_TIME ]; then
            print_error "Timeout waiting for device to appear in WSL"
            return 1
        fi
        
        sleep 1
    done
}

# Function to detach USB device
detach_usb_device() {
    local busid="$1"
    
    if [ -n "$busid" ]; then
        print_status "Detaching USB device..."
        powershell.exe -Command "usbipd detach --busid $busid" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            print_success "USB device detached successfully"
        else
            print_warning "Failed to detach USB device (it may have been disconnected manually)"
        fi
    fi
}

# Function to run openFPGALoader
run_openfpgaloader() {
    local args="$*"
    
    print_status "Running openFPGALoader with arguments: $args"
    
    # Check if openFPGALoader is available
    if ! command -v openFPGALoader &> /dev/null; then
        print_error "openFPGALoader not found in WSL"
        print_status "Please install openFPGALoader in WSL:"
        print_status "  Ubuntu/Debian: sudo apt install openfpgaloader"
        print_status "  Or build from source: https://github.com/trabucayre/openFPGALoader"
        return 1
    fi
    
    # Run openFPGALoader
    openFPGALoader $args
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        print_success "openFPGALoader completed successfully"
    else
        print_error "openFPGALoader failed with exit code $exit_code"
    fi
    
    return $exit_code
}

# Main execution
main() {
    print_status "Starting openFPGALoader WSL wrapper..."
    
    # Check if arguments are provided
    if [ $# -eq 0 ]; then
        print_error "No arguments provided"
        echo "Usage: $0 [openFPGALoader arguments...]"
        echo "Example: $0 -b arty-a7-35t /mnt/c/path/to/bitstream.bit"
        exit 1
    fi
    
    # Check if usbipd is available
    check_usbipd
    
    local busid=""
    local exit_code=0
    
    # Find and manage USB device
    busid=$(find_digilent_device)
    if [ $? -ne 0 ]; then
        print_error "Failed to find Digilent device"
        exit 1
    fi
    
    # Bind the device
    bind_usb_device "$busid"
    if [ $? -ne 0 ]; then
        print_error "Failed to bind USB device"
        exit 1
    fi
    
    # Attach the device to WSL
    attach_usb_device "$busid"
    if [ $? -ne 0 ]; then
        print_error "Failed to attach USB device"
        exit 1
    fi
    
    # Wait for device to appear in WSL
    wait_for_device_in_wsl "$busid"
    if [ $? -ne 0 ]; then
        print_error "Device did not appear in WSL"
        detach_usb_device "$busid"
        exit 1
    fi
    
    # Run openFPGALoader
    run_openfpgaloader "$@"
    exit_code=$?
    
    # Always try to detach the device
    detach_usb_device "$busid"
    
    exit $exit_code
}

# Trap to ensure device is detached on script exit
trap 'if [ -n "$busid" ]; then detach_usb_device "$busid"; fi' EXIT

# Run main function with all arguments
main "$@" 