#!/bin/bash

# Hasta Radiologi PACS Server Startup Script
# Docker container name: hasta-pacs
# Provides persistent storage and proper configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="hasta-pacs"
ORTHANC_IMAGE="orthancteam/orthanc"
HTTP_PORT="8042"
DICOM_PORT="4242"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏥 Hasta Radiologi PACS Server Startup${NC}"
echo "========================================"
echo "Container: $CONTAINER_NAME"
echo "HTTP Port: $HTTP_PORT"
echo "DICOM Port: $DICOM_PORT"
echo ""

echo "SCRIPT_DIR is $SCRIPT_DIR"
ls -l "$SCRIPT_DIR/plugins"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: Docker is not running!${NC}"
    echo "Please start Docker Desktop and try again."
    exit 1
fi

# Stop existing container if running
if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo -e "${YELLOW}⏹️  Stopping existing container: $CONTAINER_NAME${NC}"
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

# Remove existing container if it exists
if docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
    echo -e "${YELLOW}🗑️  Removing existing container: $CONTAINER_NAME${NC}"
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

# Create persistent directories
echo -e "${BLUE}📁 Creating persistent directories...${NC}"
mkdir -p "$SCRIPT_DIR/db"
mkdir -p "$SCRIPT_DIR/plugins"
mkdir -p "$SCRIPT_DIR/worklists"
mkdir -p "$SCRIPT_DIR/logs"

# Set proper permissions
chmod 755 "$SCRIPT_DIR/db"
chmod 755 "$SCRIPT_DIR/plugins"
chmod 755 "$SCRIPT_DIR/worklists"
chmod 755 "$SCRIPT_DIR/logs"
chmod 644 "$SCRIPT_DIR/config/orthanc.json"

# Check if configuration file exists
if [ ! -f "$SCRIPT_DIR/config/orthanc.json" ]; then
    echo -e "${RED}❌ Error: Configuration file not found!${NC}"
    echo "Expected: $SCRIPT_DIR/config/orthanc.json"
    exit 1
fi

echo -e "${GREEN}✅ Configuration file found${NC}"

# Check if ports are available
if lsof -Pi :$HTTP_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: Port $HTTP_PORT is already in use!${NC}"
    echo "Please stop the service using this port and try again."
    exit 1
fi

if lsof -Pi :$DICOM_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: Port $DICOM_PORT is already in use!${NC}"
    echo "Please stop the service using this port and try again."
    exit 1
fi

echo -e "${GREEN}✅ Ports $HTTP_PORT and $DICOM_PORT are available${NC}"

# Pull latest Orthanc image
echo -e "${BLUE}📥 Pulling Orthanc Docker image...${NC}"
docker pull "$ORTHANC_IMAGE"

# Start Orthanc container with persistent storage
echo -e "${BLUE}🚀 Starting Hasta PACS container...${NC}"
docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --env=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    --env=SSL_CERT_DIR=/etc/ssl/certs \
    --env=MALLOC_ARENA_MAX=5 \
    --volume="$SCRIPT_DIR/config/orthanc.json:/etc/orthanc/orthanc.json" \
    --volume="$SCRIPT_DIR/db:/var/lib/orthanc/db" \
    --volume="$SCRIPT_DIR/worklists:/worklists" \
    --volume="$SCRIPT_DIR/plugins:/usr/share/orthanc/plugins" \
    --network=bridge \
    -p "$DICOM_PORT:4242" \
    -p "$HTTP_PORT:8042" \
    --label='org.opencontainers.image.ref.name=ubuntu' \
    --label='org.opencontainers.image.version=24.04' \
    --runtime=runc \
    "$ORTHANC_IMAGE"

# Wait for container to start
echo -e "${YELLOW}⏳ Waiting for container to start...${NC}"
sleep 3

# Check if container is running
if ! docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo -e "${RED}❌ Error: Container failed to start!${NC}"
    echo "Container logs:"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
    exit 1
fi

# Wait for Orthanc to be ready
echo -e "${YELLOW}⏳ Waiting for Orthanc to be ready...${NC}"
for i in {1..30}; do
    if curl -s "http://localhost:$HTTP_PORT/system" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Orthanc is ready!${NC}"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ Error: Orthanc failed to start within 30 seconds${NC}"
        echo "Container logs:"
        docker logs "$CONTAINER_NAME" 2>&1 | tail -20
        exit 1
    fi
    
    sleep 1
done

# Get system information
echo -e "${BLUE}📊 System Information:${NC}"
SYSTEM_INFO=$(curl -s "http://localhost:$HTTP_PORT/system" 2>/dev/null || echo "{}")
echo "$SYSTEM_INFO" | python3 -m json.tool 2>/dev/null || echo "Could not parse system info"

# Check plugins
echo -e "${BLUE}🔌 Checking plugins:${NC}"
PLUGINS=$(curl -s "http://localhost:$HTTP_PORT/plugins" 2>/dev/null || echo "[]")
echo "$PLUGINS" | python3 -m json.tool 2>/dev/null || echo "Could not parse plugins info"

# Check DICOMweb functionality
echo -e "${BLUE}🌐 Testing DICOMweb endpoint:${NC}"
if curl -s "http://localhost:$HTTP_PORT/dicom-web/studies" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ DICOMweb endpoint is working${NC}"
else
    echo -e "${YELLOW}⚠️  DICOMweb endpoint not responding (may need plugin)${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Hasta PACS Server Started Successfully!${NC}"
echo "======================================="
echo -e "Container Name: ${BLUE}$CONTAINER_NAME${NC}"
echo -e "Web Interface: ${BLUE}http://localhost:$HTTP_PORT${NC}"
echo -e "DICOM Port: ${BLUE}$DICOM_PORT${NC}"
echo -e "Data Directory: ${BLUE}$SCRIPT_DIR/db${NC}"
echo -e "Config File: ${BLUE}$SCRIPT_DIR/config/orthanc.json${NC}"
echo ""
echo -e "${YELLOW}Management Commands:${NC}"
echo "  View logs:    docker logs $CONTAINER_NAME -f"
echo "  Stop server:  docker stop $CONTAINER_NAME"
echo "  Start server: docker start $CONTAINER_NAME"
echo "  Remove:       docker rm $CONTAINER_NAME"
echo "  Shell access: docker exec -it $CONTAINER_NAME /bin/bash"
echo ""
echo -e "${BLUE}📚 API Endpoints:${NC}"
echo "  System info:  http://localhost:$HTTP_PORT/system"
echo "  Studies:      http://localhost:$HTTP_PORT/studies"
echo "  Patients:     http://localhost:$HTTP_PORT/patients"
echo "  DICOMweb:     http://localhost:$HTTP_PORT/dicom-web/studies"
echo ""
echo -e "${GREEN}Server is ready for DICOM operations!${NC}"
