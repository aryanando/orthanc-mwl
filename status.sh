#!/bin/bash

# Hasta Radiologi PACS Server Status Script
# Shows status and information about the hasta-pacs container

CONTAINER_NAME="hasta-pacs"
HTTP_PORT="8042"
DICOM_PORT="4242"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏥 Hasta Radiologi PACS Server Status${NC}"
echo "======================================="

# Check if container exists
if ! docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
    echo -e "${RED}❌ Container '$CONTAINER_NAME' not found${NC}"
    echo ""
    echo -e "${YELLOW}To create and start:${NC} ./startup.sh"
    exit 1
fi

# Check container status
if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo -e "${GREEN}✅ Container Status: RUNNING${NC}"
    
    # Get container info
    CONTAINER_ID=$(docker ps -q -f name="$CONTAINER_NAME")
    echo -e "${BLUE}Container ID:${NC} $CONTAINER_ID"
    
    # Check uptime
    CREATED=$(docker inspect --format='{{.Created}}' "$CONTAINER_NAME" 2>/dev/null)
    echo -e "${BLUE}Created:${NC} $CREATED"
    
    # Check ports
    echo -e "${BLUE}Port Mappings:${NC}"
    docker port "$CONTAINER_NAME" 2>/dev/null || echo "  No port mappings found"
    
    # Test HTTP endpoint
    echo ""
    echo -e "${BLUE}🌐 Service Status:${NC}"
    if curl -s "http://localhost:$HTTP_PORT/system" >/dev/null 2>&1; then
        echo -e "  HTTP API: ${GREEN}✅ Available at http://localhost:$HTTP_PORT${NC}"
        
        # Get basic stats
        STUDIES=$(curl -s "http://localhost:$HTTP_PORT/studies" 2>/dev/null | jq length 2>/dev/null || echo "N/A")
        PATIENTS=$(curl -s "http://localhost:$HTTP_PORT/patients" 2>/dev/null | jq length 2>/dev/null || echo "N/A")
        
        echo -e "  Studies: ${BLUE}$STUDIES${NC}"
        echo -e "  Patients: ${BLUE}$PATIENTS${NC}"
        
        # Test DICOMweb
        if curl -s "http://localhost:$HTTP_PORT/dicom-web/studies" >/dev/null 2>&1; then
            echo -e "  DICOMweb: ${GREEN}✅ Available${NC}"
        else
            echo -e "  DICOMweb: ${YELLOW}⚠️  Not responding${NC}"
        fi
    else
        echo -e "  HTTP API: ${RED}❌ Not responding${NC}"
    fi
    
    # Check DICOM port
    if nc -z localhost "$DICOM_PORT" 2>/dev/null; then
        echo -e "  DICOM Port: ${GREEN}✅ $DICOM_PORT open${NC}"
    else
        echo -e "  DICOM Port: ${RED}❌ $DICOM_PORT not accessible${NC}"
    fi
    
else
    echo -e "${YELLOW}⏸️  Container Status: STOPPED${NC}"
    echo ""
    echo -e "${YELLOW}To start:${NC} docker start $CONTAINER_NAME"
    echo -e "${YELLOW}Or use:${NC} ./startup.sh"
fi

# Show resource usage if running
if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo ""
    echo -e "${BLUE}📊 Resource Usage:${NC}"
    docker stats "$CONTAINER_NAME" --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null || echo "  Stats not available"
fi

echo ""
echo -e "${BLUE}🛠️  Management Commands:${NC}"
echo "  View logs:    docker logs $CONTAINER_NAME -f"
echo "  Stop:         ./shutdown.sh"
echo "  Restart:      docker restart $CONTAINER_NAME"
echo "  Shell:        docker exec -it $CONTAINER_NAME /bin/bash"
echo "  Remove:       docker rm $CONTAINER_NAME (after stopping)"
