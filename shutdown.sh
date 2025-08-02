#!/bin/bash

# Hasta Radiologi PACS Server Shutdown Script
# Gracefully stops the hasta-pacs Docker container

set -e

CONTAINER_NAME="hasta-pacs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏥 Hasta Radiologi PACS Server Shutdown${NC}"
echo "========================================"

# Check if container exists and is running
if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo -e "${YELLOW}⏹️  Stopping container: $CONTAINER_NAME${NC}"
    docker stop "$CONTAINER_NAME"
    echo -e "${GREEN}✅ Container stopped successfully${NC}"
elif docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
    echo -e "${YELLOW}ℹ️  Container $CONTAINER_NAME is already stopped${NC}"
else
    echo -e "${RED}❌ Container $CONTAINER_NAME not found${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Hasta PACS Server Stopped!${NC}"
echo ""
echo -e "${YELLOW}To start again:${NC} ./startup.sh"
echo -e "${YELLOW}To remove completely:${NC} docker rm $CONTAINER_NAME"
