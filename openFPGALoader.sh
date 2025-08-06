#!/bin/bash

# WSL wrapper for openFPGALoader with USB device management
# This script handles FPGA programming cable attachment/detachment for all supported cables

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CABLES_LIST_FILE="$SCRIPT_DIR/cables.list"

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

# Function to read supported VID:PID combinations from cables.list
read_supported_cables() {
    if [ ! -f "$CABLES_LIST_FILE" ]; then
        print_error "Cables list file not found: $CABLES_LIST_FILE"
        return 1
    fi
    
    # Read all non-empty lines from cables.list
    SUPPORTED_CABLES=()
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
            # Remove any whitespace and carriage returns
            line=$(echo "$line" | tr -d '\r' | xargs)
            if [[ -n "$line" ]]; then
                SUPPORTED_CABLES+=("$line")
            fi
        fi
    done < "$CABLES_LIST_FILE"
    
    if [ ${#SUPPORTED_CABLES[@]} -eq 0 ]; then
        print_error "No supported cables found in $CABLES_LIST_FILE"
        return 1
    fi
    
    print_status "Loaded ${#SUPPORTED_CABLES[@]} supported cable types from $CABLES_LIST_FILE"
}

# Function to find FPGA programming cables matching supported cables
find_fpga_cables() {
    print_status "Searching for FPGA programming cables..."
    
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
    
    # Find cables that match any of our supported VID:PID combinations
    FOUND_CABLES=()
    local cable_count=0
    
    # Parse the device list using column positions from header
    local parsed_devices
    parsed_devices=$(echo "$device_list" | awk '
    /^Connected:/ { in_connected=1; next }
    /^Persisted:/ { in_connected=0 }
    in_connected && /^BUSID/ { 
        # Save column positions from header
        busid_start = index($0, "BUSID")
        vidpid_start = index($0, "VID:PID")
        device_start = index($0, "DEVICE")
        state_start = index($0, "STATE")
        next
    }
    in_connected && NF && /^[0-9]*-[0-9]*/ {
        # Extract using substr based on positions
        busid = substr($0, busid_start, vidpid_start - busid_start)
        vidpid = substr($0, vidpid_start, device_start - vidpid_start)
        device = substr($0, device_start, state_start - device_start)
        state = substr($0, state_start)
        
        # Remove leading/trailing whitespace and carriage returns
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", busid)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", vidpid)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", device)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", state)
        gsub(/\r/, "", state)
        
        printf "%s|%s|%s\n", busid, vidpid, state
    }')
    
    # Process each parsed device
    while IFS='|' read -r busid device_vid_pid state; do
        if [ -n "$busid" ] && [ -n "$device_vid_pid" ] && [ -n "$state" ]; then
            # Check if this VID:PID matches any of our supported cables
            for vid_pid in "${SUPPORTED_CABLES[@]}"; do
                if [ "$device_vid_pid" = "$vid_pid" ]; then
                    FOUND_CABLES+=("$busid|$device_vid_pid|$state")
                    cable_count=$((cable_count + 1))
                    print_success "Found FPGA programming cable: Bus ID: $busid, VID:PID: $device_vid_pid, STATE: $state"
                    break
                fi
            done
        fi
    done <<< "$parsed_devices"
    
    if [ $cable_count -eq 0 ]; then
        print_error "No FPGA programming cables found matching supported cable types"
        print_error "Please ensure an FPGA programming cable is connected."
        return 1
    fi
    
    print_success "Found $cable_count FPGA programming cable(s)"
}

# Function to parse cable info from cable string
parse_cable_info() {
    local cable_info="$1"
    
    # Parse cable info (busid|vid_pid|state)
    local busid=$(echo "$cable_info" | cut -d'|' -f1)
    local vid_pid=$(echo "$cable_info" | cut -d'|' -f2)
    local state=$(echo "$cable_info" | cut -d'|' -f3)
    
    # Split VID:PID into separate variables
    local vid=$(echo "$vid_pid" | cut -d: -f1)
    local pid=$(echo "$vid_pid" | cut -d: -f2)
    
    if [ -z "$busid" ] || [ -z "$vid" ] || [ -z "$pid" ]; then
        print_error "Failed to parse cable information: $cable_info"
        return 1
    fi
    
    echo "$busid|$vid:$pid|$state"
}

# Function to attach USB device to WSL
attach_usb_device() {
    local busid="$1"
    print_status "Attaching USB device (Bus ID: $busid) to WSL..."
    
    # Attach the device to WSL
    powershell.exe -Command "usbipd attach --wsl --busid $busid" 2>/dev/null

    if [ $? -ne 0 ]; then
        print_error "Failed to attach USB device (Bus ID: $busid) to WSL"
        return 1
    fi
    
    print_success "USB device (Bus ID: $busid) attached to WSL"
}

# Function to detach USB device
detach_usb_device() {
    local busid="$1"
    if [ -n "$busid" ]; then
        print_status "Detaching USB device (Bus ID: $busid)..."
        powershell.exe -Command "usbipd detach --busid $busid" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            print_success "USB device (Bus ID: $busid) detached successfully"
        else
            print_warning "Failed to detach USB device (Bus ID: $busid) (it may have been disconnected manually)"
        fi
    fi
}

# Function to attach all found cables
attach_all_cables() {
    local attached_cables=()
    
    for cable_info in "${FOUND_CABLES[@]}"; do
        local parsed_info
        parsed_info=$(parse_cable_info "$cable_info")
        if [ $? -ne 0 ]; then
            continue
        fi
        
        local busid=$(echo "$parsed_info" | cut -d'|' -f1)
        local state=$(echo "$parsed_info" | cut -d'|' -f3)

        if [ "$state" = "Attached" ]; then
            print_status "Cable (Bus ID: $busid) is already attached to WSL, skipping attachment"
            attached_cables+=("$busid")
        elif [ "$state" = "Not shared" ]; then
            print_error "Cable (Bus ID: $busid) is not shared and needs to be bound first"
            print_error "Please run the following command in an elevated (admin) PowerShell console:"
            print_error "  usbipd bind --busid $busid"
            print_error "Then run this script again"
            return 1
        else
            # Attach the cable to WSL
            attach_usb_device "$busid"
            if [ $? -eq 0 ]; then
                attached_cables+=("$busid")
            fi
        fi
    done
    
    # Store attached cables for later detachment
    ATTACHED_CABLES=("${attached_cables[@]}")
}

# Function to detach all attached cables
detach_all_cables() {
    for busid in "${ATTACHED_CABLES[@]}"; do
        detach_usb_device "$busid"
    done
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
    
    # Read supported cables from cables.list
    read_supported_cables
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    local exit_code=0
    
    # Find FPGA programming cables
    find_fpga_cables
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    # Attach all found cables
    attach_all_cables
    if [ $? -ne 0 ]; then
        exit 1
    fi

    # Wait for cables to be ready
    sleep 0.5
    
    # Run openFPGALoader
    run_openfpgaloader "$@"
    exit_code=$?
    
    # Always try to detach all cables
    detach_all_cables
    trap - EXIT
    exit $exit_code
}

# Trap to ensure all cables are detached on script exit
trap 'if [ ${#ATTACHED_CABLES[@]} -gt 0 ]; then detach_all_cables; fi' EXIT

# Run main function with all arguments
main "$@" 