# PowerShell wrapper for openFPGALoader running in WSL2
# This script converts Windows file paths to WSL paths and calls the WSL script

param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# Function to check if a string looks like a file path
function Test-IsFilePath {
    param([string]$Path)
    
    # Check for drive letter pattern (X:)
    if ($Path -match '^[A-Za-z]:') {
        return $true
    }
    
    # Check for path separators (backslashes or forward slashes)
    if ($Path -match '[\\/]') {
        return $true
    }
    
    # Check for file extensions (common FPGA file extensions) - this catches filenames like "foo.bit"
    if ($Path -match '\.(bit|bin|hex|svf|jed|isc|mcs|rpd|rbf|sof|pof)$') {
        return $true
    }
    
    # Check for relative paths starting with . or .. (e.g., ./foo.bit, ../design.bit)
    if ($Path -match '^\.\.?[\\/]') {
        return $true
    }
    
    return $false
}

# Function to convert Windows path to WSL path
function Convert-ToWslPath {
    param([string]$WindowsPath)
    
    # Convert backslashes to forward slashes
    $wslPath = $WindowsPath -replace '\\', '/'
    
    # Convert drive letters to /mnt/ format
    $wslPath = $wslPath -replace '^([A-Za-z]):', '/mnt/$1'
    
    return $wslPath
}

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Main execution
try {
    # Check if arguments are provided
    if ($Arguments.Count -eq 0) {
        Write-Error "No arguments provided"
        Write-Host "Usage: .\openFPGALoader.ps1 [openFPGALoader arguments...]"
        Write-Host "Example: .\openFPGALoader.ps1 -b arty-a7-35t C:\path\to\bitstream.bit"
        exit 1
    }
    
    # Build the argument string, converting the last argument (file path) to WSL format
    $args = @()
    $lastArg = $null
    
    # Process all arguments except the last one
    for ($i = 0; $i -lt ($Arguments.Count - 1); $i++) {
        $args += $Arguments[$i]
    }
    
    # Convert the last argument to WSL format only if it looks like a file path
    if ($Arguments.Count -gt 0) {
        $lastArg = $Arguments[-1]
        
        # Only convert if it looks like a file path
        if (Test-IsFilePath -Path $lastArg) {
            Write-Host "[DEBUG] Detected file path: $lastArg" -ForegroundColor Yellow
            # Check if it's a drive letter path (absolute Windows path)
            if ($lastArg -match '^[A-Za-z]:') {
                $lastArg = Convert-ToWslPath -WindowsPath $lastArg
            } else {
                Write-Host "[DEBUG] Converting relative path/filename to absolute WSL path" -ForegroundColor Yellow
                # For relative paths or just filenames, convert to absolute WSL path
                # Get current Windows directory and convert to WSL path
                $currentDir = (Get-Location).Path
                $currentDir = $currentDir -replace '\\', '/'
                $currentDir = $currentDir -replace '^([A-Za-z]):', '/mnt/$1'
                
                # Convert backslashes to forward slashes in the filename
                $lastArg = $lastArg -replace '\\', '/'
                
                # Combine current WSL directory with the filename
                $lastArg = "$currentDir/$lastArg"
            }
        }
    }
    
    # Combine all arguments
    $finalArgs = $args + $lastArg
    
    # Display conversion information
    if (Test-IsFilePath -Path $Arguments[-1]) {
        Write-Status "Converting Windows path to WSL path..."
        Write-Host "Original last argument: $($Arguments[-1])"
        Write-Host "Converted last argument: $lastArg"
    } else {
        Write-Status "Last argument does not appear to be a file path, passing as-is..."
        Write-Host "Last argument: $lastArg"
    }
    Write-Host ""
    
    # Call the WSL script with the converted arguments
    $wslCommand = "wsl ~/openFPGALoader.sh $finalArgs"
    Write-Status "Executing: $wslCommand"
    
    # Execute the WSL command
    $result = Invoke-Expression $wslCommand
    
    # Check the exit code
    if ($LASTEXITCODE -ne 0) {
        Write-Error "openFPGALoader failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    
    Write-Success "openFPGALoader completed successfully."
    
} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
} 