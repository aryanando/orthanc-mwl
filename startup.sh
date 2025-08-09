#!/bin/bash

# Comprehensive PACS (Orthanc) Container Setup Script
# This script checks the environment and sets up the Orthanc PACS container

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_NAME="hasta-pacs-official"
ORTHANC_IMAGE="jodogne/orthanc-plugins:latest"
WEB_PORT=8042
DICOM_PORT=4242

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1  # Port is in use
    else
        return 0  # Port is available
    fi
}

# Function to check Docker installation and status
check_docker() {
    print_status "Checking Docker installation..."
    
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install Docker first."
        print_status "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    print_success "Docker is installed"
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    print_success "Docker daemon is running"
    
    # Display Docker version
    local docker_version=$(docker --version)
    print_status "Docker version: $docker_version"
}

# Function to check system requirements
check_system_requirements() {
    print_status "Checking system requirements..."
    
    # Check available disk space (at least 1GB)
    local available_space=$(df -k . | awk 'NR==2 {print $4}')
    local required_space=1048576  # 1GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        print_warning "Low disk space. Available: $(($available_space/1024))MB, Recommended: 1GB+"
    else
        print_success "Sufficient disk space available"
    fi
    
    # Check available memory
    if command_exists free; then
        local available_mem=$(free -m | awk 'NR==2{print $7}')
        if [ "$available_mem" -lt 512 ]; then
            print_warning "Low available memory: ${available_mem}MB"
        else
            print_success "Sufficient memory available: ${available_mem}MB"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS memory check
        local total_mem=$(sysctl -n hw.memsize)
        local total_mem_gb=$((total_mem / 1024 / 1024 / 1024))
        print_status "Total system memory: ${total_mem_gb}GB"
    fi
}

# Function to check ports availability
check_ports() {
    print_status "Checking port availability..."
    
    if ! check_port $WEB_PORT; then
        print_error "Port $WEB_PORT is already in use"
        print_status "You can check what's using the port with: lsof -i :$WEB_PORT"
        exit 1
    fi
    print_success "Port $WEB_PORT is available"
    
    if ! check_port $DICOM_PORT; then
        print_error "Port $DICOM_PORT is already in use"
        print_status "You can check what's using the port with: lsof -i :$DICOM_PORT"
        exit 1
    fi
    print_success "Port $DICOM_PORT is available"
}

# Function to create required directories
create_directories() {
    print_status "Creating required directories..."
    
    local dirs=("db" "config" "worklists")
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_success "Created directory: $dir"
        else
            print_status "Directory already exists: $dir"
        fi
    done
}

# Function to check required files
check_required_files() {
    print_status "Checking required configuration files..."
    
    if [ ! -f "config/orthanc-minimal.json" ]; then
        print_warning "Configuration file 'config/orthanc-minimal.json' not found"
        print_status "Creating a basic configuration file..."
        
        cat > config/orthanc-minimal.json << EOF
{
  "Name": "Hasta PACS Official",
  "StorageDirectory": "/var/lib/orthanc/db",
  "IndexDirectory": "/var/lib/orthanc/db",
  "RemoteAccessAllowed": true,
  "AuthenticationEnabled": false,
  "HttpPort": 8042,
  "DicomPort": 4242,
  "DicomModalities": {},
  "OrthancPeers": {},
  "DefaultEncoding": "Latin1",
  "HttpsPort": 8043,
  "SslEnabled": false,
  "Worklists": {
    "Enable": true,
    "Database": "/worklists"
  }
}
EOF
        print_success "Created basic configuration file"
    else
        print_success "Configuration file found"
    fi
}

# Function to check if container already exists
check_existing_container() {
    print_status "Checking for existing container..."
    
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        print_warning "Container '$CONTAINER_NAME' already exists"
        
        # Check if it's running
        if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            print_status "Container is currently running"
            print_status "Stopping existing container..."
            docker stop "$CONTAINER_NAME"
        fi
        
        print_status "Removing existing container..."
        docker rm "$CONTAINER_NAME"
        print_success "Removed existing container"
    fi
}

# Function to pull Docker image
pull_docker_image() {
    print_status "Pulling Docker image: $ORTHANC_IMAGE"
    
    if docker pull "$ORTHANC_IMAGE"; then
        print_success "Successfully pulled Docker image"
    else
        print_error "Failed to pull Docker image"
        exit 1
    fi
}

# Function to start the container
start_container() {
    print_status "Starting Orthanc PACS container..."
    
    local container_id=$(docker run -d \
        --name "$CONTAINER_NAME" \
        -p "$WEB_PORT:8042" \
        -p "$DICOM_PORT:4242" \
        -v "$(pwd)/db:/var/lib/orthanc/db" \
        -v "$(pwd)/config/orthanc-minimal.json:/etc/orthanc/orthanc.json" \
        -v "$(pwd)/worklists:/worklists" \
        "$ORTHANC_IMAGE")
    
    if [ $? -eq 0 ]; then
        print_success "Container started successfully"
        print_status "Container ID: $container_id"
    else
        print_error "Failed to start container"
        exit 1
    fi
}

# Function to verify container is running
verify_container() {
    print_status "Verifying container status..."
    
    sleep 3  # Give container time to start
    
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$CONTAINER_NAME.*Up"; then
        print_success "Container is running successfully"
        
        # Display container information
        print_status "Container details:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "$CONTAINER_NAME"
        
        print_status "Waiting for Orthanc to be ready..."
        local max_attempts=30
        local attempt=0
        
        while [ $attempt -lt $max_attempts ]; do
            if curl -s -f "http://localhost:$WEB_PORT/system" >/dev/null 2>&1; then
                print_success "Orthanc is ready and responding"
                break
            fi
            
            attempt=$((attempt + 1))
            sleep 2
            echo -n "."
        done
        
        if [ $attempt -eq $max_attempts ]; then
            print_warning "Orthanc may not be fully ready yet. Check logs: docker logs $CONTAINER_NAME"
        fi
        
    else
        print_error "Container failed to start properly"
        print_status "Checking container logs..."
        docker logs "$CONTAINER_NAME"
        exit 1
    fi
}

# Function to display connection information
display_connection_info() {
    print_success "=== Orthanc PACS Setup Complete ==="
    echo
    print_status "Web Interface: http://localhost:$WEB_PORT"
    print_status "DICOM Port: $DICOM_PORT"
    print_status "Container Name: $CONTAINER_NAME"
    echo
    print_status "Useful commands:"
    echo "  View logs:        docker logs $CONTAINER_NAME"
    echo "  Stop container:   docker stop $CONTAINER_NAME"
    echo "  Start container:  docker start $CONTAINER_NAME"
    echo "  Remove container: docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME"
    echo
    print_status "Data directories:"
    echo "  Database:     $(pwd)/db"
    echo "  Config:       $(pwd)/config"
    echo "  Worklists:    $(pwd)/worklists"
}

# Function to handle cleanup on script exit
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "Script failed. Check the error messages above."
        print_status "You can clean up with: docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Main execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Comprehensive Orthanc PACS Setup     ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    
    check_docker
    check_system_requirements
    check_ports
    create_directories
    check_required_files
    check_existing_container
    pull_docker_image
    start_container
    verify_container
    display_connection_info
    
    print_success "Setup completed successfully!"
}

# Run main function
main "$@"