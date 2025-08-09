#!/bin/bash

# Hasta Radiologi PACS Server Startup Script (Unix/Linux/macOS) - Advanced Version
# Docker container name: hasta-pacs
# Provides persistent storage and proper configuration with plugin handling

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="hasta-pacs"
ORTHANC_IMAGE="orthancteam/orthanc:latest"
ORTHANC_IMAGE_WITH_PLUGINS="orthancteam/orthanc-plugins:latest"
HTTP_PORT="8042"
DICOM_PORT="4242"
USE_PLUGINS="false"
USE_MINIMAL_CONFIG="false"

echo
echo "🏥 Hasta Radiologi PACS Server Startup (Advanced)"
echo "==============================================="
echo "Container: $CONTAINER_NAME"
echo "HTTP Port: $HTTP_PORT"
echo "DICOM Port: $DICOM_PORT"
echo

# Check if Docker is running
if ! docker info &>/dev/null; then
    echo "❌ Error: Docker is not running!"
    echo "Please start Docker and try again."
    read -p "Press any key to continue..."
    exit 1
fi

# Stop existing container if running
if [ "$(docker ps -q -f name=$CONTAINER_NAME 2>/dev/null)" ]; then
    echo "⏹️  Stopping existing container: $CONTAINER_NAME"
    docker stop $CONTAINER_NAME &>/dev/null
fi

# Remove existing container if it exists
if [ "$(docker ps -aq -f name=$CONTAINER_NAME 2>/dev/null)" ]; then
    echo "🗑️  Removing existing container: $CONTAINER_NAME"
    docker rm $CONTAINER_NAME &>/dev/null
fi

# Create persistent directories
echo "📁 Creating persistent directories..."
mkdir -p "$SCRIPT_DIR/db"
mkdir -p "$SCRIPT_DIR/worklists"
mkdir -p "$SCRIPT_DIR/logs"

# Handle plugins directory
mkdir -p "$SCRIPT_DIR/plugins"

# Check if user wants to use custom plugins
if ls "$SCRIPT_DIR/plugins"/*.so &>/dev/null; then
    echo
    echo "🔌 Found custom plugins in plugins directory:"
    ls -1 "$SCRIPT_DIR/plugins"/*.so 2>/dev/null | xargs -n1 basename
    echo
    echo "WARNING: Custom plugins can cause startup failures if incompatible."
    read -p "Do you want to try using these plugins? [y/N] " USE_PLUGINS_INPUT
    if [[ "$USE_PLUGINS_INPUT" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        USE_PLUGINS="true"
    fi
fi

# Check if configuration file exists
if [ ! -f "$SCRIPT_DIR/config/orthanc.json" ]; then
    echo "❌ Error: Configuration file not found!"
    echo "Expected: $SCRIPT_DIR/config/orthanc.json"
    echo
    echo "🔧 Creating a minimal configuration directory and file..."
    mkdir -p "$SCRIPT_DIR/config"
    
    # Create a minimal orthanc.json configuration
    cat > "$SCRIPT_DIR/config/orthanc.json" << 'EOF'
{
  "Name": "Hasta PACS Server",
  "StorageDirectory": "/var/lib/orthanc/db",
  "IndexDirectory": "/var/lib/orthanc/db",
  "StorageCompression": false,
  "MaximumStorageSize": 0,
  "MaximumPatientCount": 0,
  "HttpPort": 8042,
  "DicomPort": 4242,
  "RemoteAccessAllowed": true,
  "AuthenticationEnabled": false,
  "SslEnabled": false,
  "HttpsCertificate": "",
  "HttpsKey": "",
  "HttpThreadsCount": 50,
  "HttpTimeout": 30,
  "HttpRequestTimeout": 30,
  "DicomThreadsCount": 4,
  "DefaultEncoding": "Latin1",
  "AcceptedTransferSyntaxes": [ "1.2.840.10008.1.2*" ],
  "DeidentifyLogs": true,
  "DeidentifyLogsDicomVersion": "2017c",
  "LogExportedResources": false,
  "KeepAlive": true,
  "TcpNoDelay": true,
  "HttpCompressionEnabled": true,
  "Worklists": {
    "Enable": true,
    "Database": "/worklists"
  },
  "DicomWeb": {
    "Enable": false,
    "Root": "/dicom-web/",
    "EnableWado": true,
    "WadoRoot": "/wado",
    "Ssl": false,
    "QidoRoot": "/qido",
    "StowRoot": "/stow"
  }
}
EOF
    
    echo "✅ Created minimal configuration file"
    USE_MINIMAL_CONFIG="true"
else
    echo "✅ Configuration file found"
fi

# Check if ports are available
if lsof -i :$HTTP_PORT &>/dev/null; then
    echo "❌ Error: Port $HTTP_PORT is already in use!"
    echo "Please stop the service using this port and try again."
    read -p "Press any key to continue..."
    exit 1
fi

if lsof -i :$DICOM_PORT &>/dev/null; then
    echo "❌ Error: Port $DICOM_PORT is already in use!"
    echo "Please stop the service using this port and try again."
    read -p "Press any key to continue..."
    exit 1
fi

echo "✅ Ports $HTTP_PORT and $DICOM_PORT are available"

# Pull latest Orthanc image
echo "📥 Pulling Orthanc Docker image..."

# Determine which image to use
SELECTED_IMAGE="$ORTHANC_IMAGE"

# Check if the config mentions DICOMweb or plugins
if grep -q '"DicomWeb"' "$SCRIPT_DIR/config/orthanc.json" 2>/dev/null || grep -q '"Plugins"' "$SCRIPT_DIR/config/orthanc.json" 2>/dev/null; then
    if [ "$USE_MINIMAL_CONFIG" = "false" ]; then
        echo "🔌 Configuration mentions plugins or DICOMweb, using plugin-enabled image..."
        SELECTED_IMAGE="$ORTHANC_IMAGE_WITH_PLUGINS"
    fi
fi

if ! docker pull "$SELECTED_IMAGE"; then
    echo "❌ Error: Failed to pull Docker image: $SELECTED_IMAGE"
    echo "🔄 Trying fallback image: $ORTHANC_IMAGE"
    SELECTED_IMAGE="$ORTHANC_IMAGE"
    if ! docker pull "$SELECTED_IMAGE"; then
        echo "❌ Error: Failed to pull fallback Docker image!"
        read -p "Press any key to continue..."
        exit 1
    fi
fi

echo "✅ Using image: $SELECTED_IMAGE"

# Prepare Docker command
DOCKER_CMD="docker run -d --name $CONTAINER_NAME --restart unless-stopped \
    --env=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    --env=SSL_CERT_DIR=/etc/ssl/certs \
    --env=MALLOC_ARENA_MAX=5 \
    --volume=\"$SCRIPT_DIR/config/orthanc.json:/etc/orthanc/orthanc.json\" \
    --volume=\"$SCRIPT_DIR/db:/var/lib/orthanc/db\" \
    --volume=\"$SCRIPT_DIR/worklists:/worklists\" \
    --network=bridge \
    -p $DICOM_PORT:4242 \
    -p $HTTP_PORT:8042 \
    --label=org.opencontainers.image.ref.name=ubuntu \
    --label=org.opencontainers.image.version=24.04 \
    --runtime=runc"

# Add plugins volume if requested
if [ "$USE_PLUGINS" = "true" ]; then
    echo "🔌 Starting with custom plugins enabled..."
    DOCKER_CMD="$DOCKER_CMD --volume=\"$SCRIPT_DIR/plugins:/usr/share/orthanc/plugins\""
else
    echo "🚀 Starting without custom plugins for maximum compatibility..."
fi

# Start Orthanc container
echo "🚀 Starting Hasta PACS container..."
eval $DOCKER_CMD "$SELECTED_IMAGE"

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to start container!"
    echo "🔄 Trying with fallback configuration..."
    
    # If we used the plugins image, try the basic image
    if [ "$SELECTED_IMAGE" = "$ORTHANC_IMAGE_WITH_PLUGINS" ]; then
        echo "🔄 Retrying with basic Orthanc image (no plugins)..."
        SELECTED_IMAGE="$ORTHANC_IMAGE"
        docker pull "$SELECTED_IMAGE"
        eval $DOCKER_CMD "$SELECTED_IMAGE"
        
        if [ $? -ne 0 ]; then
            echo "❌ Error: Failed to start container with fallback image!"
            read -p "Press any key to continue..."
            exit 1
        fi
    else
        read -p "Press any key to continue..."
        exit 1
    fi
fi

# Wait for container to start
echo "⏳ Waiting for container to start..."
sleep 3

# Check if container is running
if ! docker ps -q -f name=$CONTAINER_NAME &>/dev/null; then
    echo "❌ Error: Container failed to start!"
    echo "Container logs:"
    docker logs $CONTAINER_NAME
    
    if [ "$USE_PLUGINS" = "true" ]; then
        echo
        echo "💡 TIP: Try running without custom plugins if startup fails"
        echo "    Delete or move files from the plugins directory"
    fi
    read -p "Press any key to continue..."
    exit 1
fi

# Wait for Orthanc to be ready
echo "⏳ Waiting for Orthanc to be ready..."
counter=0
while true; do
    counter=$((counter + 1))
    if curl -s "http://localhost:$HTTP_PORT/system" &>/dev/null; then
        echo "✅ Orthanc is ready!"
        break
    fi
    
    if [ $counter -ge 30 ]; then
        echo "❌ Error: Orthanc failed to start within 30 seconds"
        echo "Container logs:"
        docker logs $CONTAINER_NAME
        
        if [ "$USE_PLUGINS" = "true" ]; then
            echo
            echo "💡 Plugin compatibility issue detected!"
            echo "    Try running the script again without plugins"
        fi
        read -p "Press any key to continue..."
        exit 1
    fi
    
    sleep 1
done

# Get system information
echo "📊 System Information:"
curl -s "http://localhost:$HTTP_PORT/system" 2>/dev/null

# Check plugins
echo
echo "🔌 Checking loaded plugins:"
curl -s "http://localhost:$HTTP_PORT/plugins" 2>/dev/null

# Check DICOMweb functionality
echo
echo "🌐 Testing DICOMweb endpoint:"
if curl -s "http://localhost:$HTTP_PORT/dicom-web/studies" &>/dev/null; then
    echo "✅ DICOMweb endpoint is working"
else
    echo "⚠️  DICOMweb endpoint not responding (may need plugin)"
fi

echo
echo "🎉 Hasta PACS Server Started Successfully!"
echo "======================================="
echo "Container Name: $CONTAINER_NAME"
echo "Image Used: $SELECTED_IMAGE"
echo "Web Interface: http://localhost:$HTTP_PORT"
echo "DICOM Port: $DICOM_PORT"
echo "Data Directory: $SCRIPT_DIR/db"
echo "Config File: $SCRIPT_DIR/config/orthanc.json"
if [ "$USE_MINIMAL_CONFIG" = "true" ]; then
    echo "Configuration: Minimal auto-generated config"
elif [ "$USE_PLUGINS" = "true" ]; then
    echo "Plugins: Custom plugins enabled"
else
    echo "Plugins: Using built-in plugins only"
fi
echo
echo "Management Commands:"
echo "  View logs:    docker logs $CONTAINER_NAME -f"
echo "  Stop server:  docker stop $CONTAINER_NAME"
echo "  Start server: docker start $CONTAINER_NAME"
echo "  Remove:       docker rm $CONTAINER_NAME"
echo "  Shell access: docker exec -it $CONTAINER_NAME /bin/bash"
echo
echo "📚 API Endpoints:"
echo "  System info:  http://localhost:$HTTP_PORT/system"
echo "  Studies:      http://localhost:$HTTP_PORT/studies"
echo "  Patients:     http://localhost:$HTTP_PORT/patients"
echo "  DICOMweb:     http://localhost:$HTTP_PORT/dicom-web/studies"
echo
echo "🔧 Troubleshooting:"
echo "  If startup fails, check:"
echo "  1. Docker is running and has sufficient resources"
echo "  2. Ports $HTTP_PORT and $DICOM_PORT are not in use"
echo "  3. Configuration file syntax is valid JSON"
echo "  4. Plugin files (*.so) are compatible with Orthanc version"
echo "  5. Try removing custom plugins from plugins/ directory"
echo
echo "Server is ready for DICOM operations!"
echo
read -p "Press any key to continue..."
