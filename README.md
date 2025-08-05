# openFPGALoader Windows/WSL Wrapper

This project provides Windows and WSL wrapper scripts for [openFPGALoader](https://github.com/trabucayre/openFPGALoader) that automatically handle USB device attachment/detachment for Digilent FPGA programming devices.

## Features

- **Automatic USB Device Management**: Automatically detects, binds, and attaches Digilent USB devices to WSL
- **Path Conversion**: Converts Windows file paths to WSL paths automatically
- **Error Handling**: Comprehensive error handling and cleanup
- **Colored Output**: Clear status messages with color coding
- **Cross-Platform**: Works seamlessly between Windows and WSL2

## Prerequisites

### Windows Requirements

1. **Windows 11** (Build 22000 or later) or **Windows 10** with WSL from Microsoft Store
2. **WSL2** installed and configured
3. **usbipd-win** installed on Windows

### WSL Requirements

1. **Linux distribution** (Ubuntu recommended)
2. **openFPGALoader** installed in WSL
3. **lsusb** command available

## Installation

### 1. Install usbipd-win on Windows

Follow the [Microsoft guide](https://learn.microsoft.com/en-us/windows/wsl/connect-usb#install-the-usbipd-win-project) or use winget:

```powershell
winget install --interactive --exact dorssel.usbipd-win
```

### 2. Install openFPGALoader in WSL

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install openfpgaloader

# Or build from source
git clone https://github.com/trabucayre/openFPGALoader.git
cd openFPGALoader
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
```

### 3. Copy Scripts to WSL

Copy the `openFPGALoader.sh` script to your WSL home directory:

```bash
# From Windows, copy the script to WSL
copy openFPGALoader.sh %USERPROFILE%\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState\rootfs\home\YOUR_WSL_USERNAME\
```

Or manually copy the script content to `~/openFPGALoader.sh` in WSL.

Make the script executable:

```bash
chmod +x ~/openFPGALoader.sh
```

### 4. Copy Windows Script

Copy `openFPGALoader.bat` to a directory in your Windows PATH or use it from the current directory.

## Usage

### Basic Usage

```cmd
# Program to SRAM (volatile)
openFPGALoader.bat -b arty-a7-35t C:\path\to\your\bitstream.bit

# Program to flash (persistent)
openFPGALoader.bat -b arty-a7-35t -f C:\path\to\your\bitstream.bit

# Use specific cable
openFPGALoader.bat -c digilent C:\path\to\your\bitstream.bit
```

### Advanced Usage

```cmd
# List supported boards
openFPGALoader.bat --list-boards

# List supported cables
openFPGALoader.bat --list-cables

# Verbose output
openFPGALoader.bat -v -b arty-a7-35t C:\path\to\your\bitstream.bit
```

## How It Works

1. **Windows Script (`openFPGALoader.bat`)**:
   - Converts Windows file paths to WSL paths
   - Calls the WSL script with converted arguments
   - Handles error reporting

2. **WSL Script (`openFPGALoader.sh`)**:
   - Detects Digilent USB device using `usbipd list`
   - Binds the device with `usbipd bind`
   - Attaches device to WSL with `usbipd attach`
   - Waits for device to appear in WSL using `lsusb`
   - Runs `openFPGALoader` with provided arguments
   - Detaches device when complete

## Supported Devices

This wrapper is specifically designed for **Digilent USB devices** with VID:PID `0403:6010`. The script automatically detects devices with the name "Digilent USB Device".

## Troubleshooting

### Common Issues

1. **"usbipd command not found"**
   - Install usbipd-win on Windows
   - Ensure it's added to PATH

2. **"Digilent USB device not found"**
   - Check if device is connected
   - Verify device appears in `usbipd list` output
   - Ensure device name matches "Digilent USB Device"

3. **"openFPGALoader not found in WSL"**
   - Install openFPGALoader in WSL
   - Verify installation with `which openFPGALoader`

4. **"Device did not appear in WSL"**
   - Check WSL kernel version (requires 5.10.60.1 or higher)
   - Update WSL: `wsl --update`
   - Restart WSL: `wsl --shutdown`

5. **Permission denied errors**
   - Run Windows script as Administrator
   - Check udev rules in WSL for USB device access

### Debug Mode

To see detailed output, you can run the WSL script directly:

```bash
# In WSL
~/openFPGALoader.sh -v -b arty-a7-35t /mnt/c/path/to/bitstream.bit
```

### Manual USB Device Management

If automatic management fails, you can manually manage the USB device:

```powershell
# In Windows PowerShell (as Administrator)
usbipd list
usbipd bind --busid 2-5
usbipd attach --wsl --busid 2-5
```

```bash
# In WSL
lsusb  # Verify device appears
openFPGALoader -b arty-a7-35t /mnt/c/path/to/bitstream.bit
```

```powershell
# In Windows PowerShell (as Administrator)
usbipd detach --busid 2-5
```

## Configuration

You can modify the following variables in `openFPGALoader.sh`:

- `DIGILENT_VID`: Vendor ID (default: "0403")
- `DIGILENT_PID`: Product ID (default: "6010")
- `DIGILENT_DEVICE_NAME`: Device name to search for (default: "Digilent USB Device")
- `MAX_WAIT_TIME`: Maximum time to wait for device in seconds (default: 30)

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is licensed under the same license as openFPGALoader.

## References

- [openFPGALoader Documentation](https://trabucayre.github.io/openFPGALoader/)
- [Microsoft WSL USB Device Guide](https://learn.microsoft.com/en-us/windows/wsl/connect-usb)
- [usbipd-win Project](https://github.com/dorssel/usbipd-win) 