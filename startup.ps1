# Comprehensive PACS (Orthanc) Container Setup Script for Windows PowerShell
# This script checks the environment and sets up the Orthanc PACS container

param(
    [switch]$Force,
    [string]$ContainerName = "hasta-pacs-official",
    [string]$OrthancImage = "jodogne/orthanc-plugins:latest",
    [int]$WebPort = 8042,
    [int]$DicomPort = 4242
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Color functions for output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to check if command exists
function Test-CommandExists {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# Function to check if port is available
function Test-PortAvailable {
    param([int]$Port)
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
        $listener.Start()
        $listener.Stop()
        return $true
    }
    catch {
        return $false
    }
}

# Function to check Docker installation and status
function Test-Docker {
    Write-Info "Checking Docker installation..."
    
    if (-not (Test-CommandExists "docker")) {
        Write-Error "Docker is not installed. Please install Docker Desktop first."
        Write-Info "Visit: https://docs.docker.com/desktop/install/windows/"
        exit 1
    }
    
    Write-Success "Docker is installed"
    
    # Check if Docker daemon is running
    try {
        docker info | Out-Null
        Write-Success "Docker daemon is running"
    }
    catch {
        Write-Error "Docker daemon is not running. Please start Docker Desktop."
        exit 1
    }
    
    # Display Docker version
    $dockerVersion = docker --version
    Write-Info "Docker version: $dockerVersion"
}

# Function to check system requirements
function Test-SystemRequirements {
    Write-Info "Checking system requirements..."
    
    # Check available disk space (at least 1GB)
    $currentDrive = (Get-Location).Drive
    $freeSpace = (Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$($currentDrive.Name)'").FreeSpace
    $freeSpaceGB = [math]::Round($freeSpace / 1GB, 2)
    
    if ($freeSpaceGB -lt 1) {
        Write-Warning "Low disk space. Available: ${freeSpaceGB}GB, Recommended: 1GB+"
    }
    else {
        Write-Success "Sufficient disk space available: ${freeSpaceGB}GB"
    }
    
    # Check available memory
    $totalMemory = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory
    $totalMemoryGB = [math]::Round($totalMemory / 1GB, 2)
    Write-Info "Total system memory: ${totalMemoryGB}GB"
}

# Function to check ports availability
function Test-Ports {
    Write-Info "Checking port availability..."
    
    if (-not (Test-PortAvailable $WebPort)) {
        Write-Error "Port $WebPort is already in use"
        Write-Info "You can check what's using the port with: netstat -ano | findstr :$WebPort"
        exit 1
    }
    Write-Success "Port $WebPort is available"
    
    if (-not (Test-PortAvailable $DicomPort)) {
        Write-Error "Port $DicomPort is already in use"
        Write-Info "You can check what's using the port with: netstat -ano | findstr :$DicomPort"
        exit 1
    }
    Write-Success "Port $DicomPort is available"
}

# Function to create required directories
function New-RequiredDirectories {
    Write-Info "Creating required directories..."
    
    $directories = @("db", "config", "worklists")
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Success "Created directory: $dir"
        }
        else {
            Write-Info "Directory already exists: $dir"
        }
    }
}

# Function to check required files
function Test-RequiredFiles {
    Write-Info "Checking required configuration files..."
    
    $configFile = "config\orthanc-minimal.json"
    if (-not (Test-Path $configFile)) {
        Write-Warning "Configuration file '$configFile' not found"
        Write-Info "Creating a basic configuration file..."
        
        $config = @{
            "Name" = "Hasta PACS Official"
            "StorageDirectory" = "/var/lib/orthanc/db"
            "IndexDirectory" = "/var/lib/orthanc/db"
            "RemoteAccessAllowed" = $true
            "AuthenticationEnabled" = $false
            "HttpPort" = 8042
            "DicomPort" = 4242
            "DicomModalities" = @{}
            "OrthancPeers" = @{}
            "DefaultEncoding" = "Latin1"
            "HttpsPort" = 8043
            "SslEnabled" = $false
            "Worklists" = @{
                "Enable" = $true
                "Database" = "/worklists"
            }
        }
        
        $config | ConvertTo-Json -Depth 10 | Set-Content $configFile -Encoding UTF8
        Write-Success "Created basic configuration file"
    }
    else {
        Write-Success "Configuration file found"
    }
}

# Function to check if container already exists
function Test-ExistingContainer {
    Write-Info "Checking for existing container..."
    
    $existingContainer = docker ps -a --format "table {{.Names}}" | Select-String -Pattern "^$ContainerName`$"
    
    if ($existingContainer) {
        Write-Warning "Container '$ContainerName' already exists"
        
        # Check if it's running
        $runningContainer = docker ps --format "table {{.Names}}" | Select-String -Pattern "^$ContainerName`$"
        if ($runningContainer) {
            Write-Info "Container is currently running"
            Write-Info "Stopping existing container..."
            docker stop $ContainerName | Out-Null
        }
        
        Write-Info "Removing existing container..."
        docker rm $ContainerName | Out-Null
        Write-Success "Removed existing container"
    }
}

# Function to pull Docker image
function Get-DockerImage {
    Write-Info "Pulling Docker image: $OrthancImage"
    
    try {
        docker pull $OrthancImage | Out-Null
        Write-Success "Successfully pulled Docker image"
    }
    catch {
        Write-Error "Failed to pull Docker image"
        exit 1
    }
}

# Function to start the container
function Start-Container {
    Write-Info "Starting Orthanc PACS container..."
    
    $currentPath = (Get-Location).Path.Replace('\', '/')
    
    try {
        $containerId = docker run -d `
            --name $ContainerName `
            -p "${WebPort}:8042" `
            -p "${DicomPort}:4242" `
            -v "${currentPath}/db:/var/lib/orthanc/db" `
            -v "${currentPath}/config/orthanc-minimal.json:/etc/orthanc/orthanc.json" `
            -v "${currentPath}/worklists:/worklists" `
            $OrthancImage
        
        Write-Success "Container started successfully"
        Write-Info "Container ID: $containerId"
    }
    catch {
        Write-Error "Failed to start container"
        exit 1
    }
}

# Function to verify container is running
function Test-Container {
    Write-Info "Verifying container status..."
    
    Start-Sleep -Seconds 3  # Give container time to start
    
    $runningContainer = docker ps --format "table {{.Names}}`t{{.Status}}" | Select-String -Pattern "$ContainerName.*Up"
    
    if ($runningContainer) {
        Write-Success "Container is running successfully"
        
        # Display container information
        Write-Info "Container details:"
        docker ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" | Select-String -Pattern $ContainerName
        
        Write-Info "Waiting for Orthanc to be ready..."
        $maxAttempts = 30
        $attempt = 0
        
        while ($attempt -lt $maxAttempts) {
            try {
                $response = Invoke-WebRequest -Uri "http://localhost:$WebPort/system" -UseBasicParsing -TimeoutSec 2
                if ($response.StatusCode -eq 200) {
                    Write-Success "Orthanc is ready and responding"
                    break
                }
            }
            catch {
                # Continue waiting
            }
            
            $attempt++
            Start-Sleep -Seconds 2
            Write-Host "." -NoNewline
        }
        
        if ($attempt -eq $maxAttempts) {
            Write-Warning "Orthanc may not be fully ready yet. Check logs: docker logs $ContainerName"
        }
    }
    else {
        Write-Error "Container failed to start properly"
        Write-Info "Checking container logs..."
        docker logs $ContainerName
        exit 1
    }
}

# Function to display connection information
function Show-ConnectionInfo {
    Write-Success "=== Orthanc PACS Setup Complete ==="
    Write-Host ""
    Write-Info "Web Interface: http://localhost:$WebPort"
    Write-Info "DICOM Port: $DicomPort"
    Write-Info "Container Name: $ContainerName"
    Write-Host ""
    Write-Info "Useful commands:"
    Write-Host "  View logs:        docker logs $ContainerName"
    Write-Host "  Stop container:   docker stop $ContainerName"
    Write-Host "  Start container:  docker start $ContainerName"
    Write-Host "  Remove container: docker stop $ContainerName; docker rm $ContainerName"
    Write-Host ""
    Write-Info "Data directories:"
    Write-Host "  Database:     $(Get-Location)\db"
    Write-Host "  Config:       $(Get-Location)\config"
    Write-Host "  Worklists:    $(Get-Location)\worklists"
}

# Main execution
function Main {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Comprehensive Orthanc PACS Setup     " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Test-Docker
        Test-SystemRequirements
        Test-Ports
        New-RequiredDirectories
        Test-RequiredFiles
        Test-ExistingContainer
        Get-DockerImage
        Start-Container
        Test-Container
        Show-ConnectionInfo
        
        Write-Success "Setup completed successfully!"
    }
    catch {
        Write-Error "Script failed: $($_.Exception.Message)"
        Write-Info "You can clean up with: docker stop $ContainerName; docker rm $ContainerName"
        exit 1
    }
}

# Run main function
Main
