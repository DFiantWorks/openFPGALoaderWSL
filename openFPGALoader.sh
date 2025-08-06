#!/bin/bash

# WSL wrapper for openFPGALoader with USB device management
# This script handles Digilent USB device attachment/detachment

# Configuration
DIGILENT_DEVICE_NAME="Digilent USB Device"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    # echo -e "${BLUE}[INFO]${NC} $1"
    :
}

print_success() {
    # echo -e "${GREEN}[SUCCESS]${NC} $1"
    :
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if usbipd is available
check_usbipd() {
    # Try to run usbipd list to check if it's available
    local output
    output=$(powershell.exe -Command "usbipd list" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -ne 0 ] || echo "$output" | grep -q "not recognized"; then
        print_error "usbipd command not found or not working."
        print_error "Please install usbipd-win on Windows:"
        print_error "Installation instructions: https://learn.microsoft.com/en-us/windows/wsl/connect-usb#install-the-usbipd-win-project"
        exit 1
    fi
}

# Function to find Digilent device bus ID and extract VID:PID
find_digilent_device() {
    print_status "Searching for Digilent USB device..."
    
    # Get device list from Windows
    local device_list
    device_list=$(powershell.exe -Command "usbipd list" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -ne 0 ] || echo "$device_list" | grep -q "not recognized"; then
        print_error "usbipd command not found or not working"
        print_error "Please install usbipd-win on Windows:"
        print_error "Installation instructions: https://learn.microsoft.com/en-us/windows/wsl/connect-usb#install-the-usbipd-win-project"
        return 1
    fi
    
    if [ -z "$device_list" ]; then
        print_error "usbipd list returned empty output"
        return 1
    fi
    
    # Extract only the Connected section (ignore Persisted section)
    local connected_section
    connected_section=$(echo "$device_list" | awk '/^Connected:/,/^Persisted:/ {if ($0 !~ /^Persisted:/) print}')
    
    if [ -z "$connected_section" ]; then
        print_error "No connected devices found in device list"
        return 1
    fi
    
    # Extract the line containing Digilent device from Connected section only
    local digilent_line
    digilent_line=$(echo "$connected_section" | grep "$DIGILENT_DEVICE_NAME" | head -1)
    
    if [ -z "$digilent_line" ]; then
        print_error "Digilent USB device not found in connected devices"
        print_error "Please ensure the Digilent device is connected."
        return 1
    fi
    
    # Check if this line has a bus ID format (contains digits-digits)
    if ! echo "$digilent_line" | grep -q "^[0-9]*-[0-9]*"; then
        print_error "Digilent device found but not in expected bus ID format: $digilent_line"
        return 1
    fi
    
    # Extract bus ID (first column)
    local busid
    busid=$(echo "$digilent_line" | awk '{print $1}')

    # Extract VID:PID (second column)
    local vid_pid
    vid_pid=$(echo "$digilent_line" | awk '{print $2}')
    
    # Extract STATE (last column) and remove carriage returns
    local state
    state=$(echo "$digilent_line" | awk '{print $NF}' | tr -d '\r')
    
    # Split VID:PID into separate variables
    local vid
    local pid
    vid=$(echo "$vid_pid" | cut -d: -f1)
    pid=$(echo "$vid_pid" | cut -d: -f2)
    
    if [ -z "$vid" ] || [ -z "$pid" ]; then
        print_error "Failed to extract VID:PID from device line: $digilent_line"
        return 1
    fi
    
    print_success "Found Digilent device with bus ID: $busid, VID:PID: $vid:$pid, STATE: $state"
    
    # Store BUSID, VID, PID and STATE in global variables for use by other functions
    BUSID="$busid"
    DIGILENT_VID="$vid"
    DIGILENT_PID="$pid"
    DEVICE_STATE="$state"
}

# Function to attach USB device to WSL
attach_usb_device() {
    
    print_status "Attaching USB device to WSL..."
    
    # Attach the device to WSL
    powershell.exe -Command "usbipd attach --wsl --busid $BUSID" 2>/dev/null

    if [ $? -ne 0 ]; then
        print_error "Failed to attach USB device to WSL"
        return 1
    fi
    
    print_success "USB device attached to WSL"
}

# Function to detach USB device
detach_usb_device() {
    
    if [ -n "$BUSID" ]; then
        print_status "Detaching USB device..."
        powershell.exe -Command "usbipd detach --busid $BUSID" 2>/dev/null
        
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
    find_digilent_device
    if [ $? -ne 0 ]; then
        exit 1
    fi

    # Check device state and handle accordingly
    if [ "$DEVICE_STATE" = "Attached" ]; then
        print_status "Device is already attached to WSL, skipping binding and attachment"
    elif [ "$DEVICE_STATE" = "Not shared" ]; then
        print_error "Device is not shared and needs to be bound first"
        print_error "Please run the following command in an elevated (admin) PowerShell console:"
        print_error "  usbipd bind --busid $BUSID"
        print_error "Then run this script again"
        exit 1
    else
        # Attach the device to WSL
        attach_usb_device
        if [ $? -ne 0 ]; then
            exit 1
        fi
        
        # Wait for device to be ready
        sleep 0.5
    fi
    
    # Run openFPGALoader
    run_openfpgaloader "$@"
    exit_code=$?
    
    # Always try to detach the device
    detach_usb_device
    trap - EXIT
    exit $exit_code
}

# Trap to ensure device is detached on script exit
trap 'if [ -n "$BUSID" ]; then detach_usb_device; fi' EXIT

# Run main function with all arguments
main "$@" 