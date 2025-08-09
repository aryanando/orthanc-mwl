# Hasta Radiologi PACS Server

Docker-based Orthanc PACS server with persistent storage and DICOMweb support.

## Container Information
- **Container Name**: `hasta-pacs`
- **Image**: `orthancteam/orthanc`
- **HTTP Port**: `8042`
- **DICOM Port**: `4242`

## Quick Start

### 1. Start the PACS Server
```bash
./startup.sh
```

### 2. Check Status
```bash
./status.sh
```

### 3. Stop the Server
```bash
./shutdown.sh
```

## Directory Structure
```
orthanc-mwl/
├── startup.sh          # Start the PACS server
├── shutdown.sh         # Stop the PACS server
├── status.sh           # Check server status
├── config/
│   └── orthanc.json    # Orthanc configuration
├── db/                # Persistent database storage (created automatically)
├── plugins/           # Orthanc plugins directory
├── worklists/         # DICOM worklists
└── logs/              # Log files
```

## Features

### ✅ Persistent Storage
- All DICOM data is stored in `./db/`
- Configuration in `./config/orthanc.json`
- Plugins in `./plugins/`
- Worklists in `./worklists/`
- Logs in `./logs/`

### ✅ Container Management
- Auto-restart unless manually stopped
- Health checks and startup verification
- Proper port conflict detection

### ✅ DICOMweb Support
- REST API at `http://localhost:8042`
- DICOMweb endpoints at `http://localhost:8042/dicom-web/`
- CORS enabled for web applications

### ✅ Security
- Authentication disabled for development
- CORS headers configured
- Remote access allowed

## Usage Examples

### Access Web Interface
```bash
open http://localhost:8042
```

### View System Information
```bash
curl http://localhost:8042/system | jq
```

### List Studies
```bash
curl http://localhost:8042/studies | jq
```

### DICOMweb Studies
```bash
curl http://localhost:8042/dicom-web/studies | jq
```

### Send DICOM File
```bash
storescu -aec ORTHANC localhost 4242 file.dcm
```

## Container Management

### View Logs
```bash
docker logs hasta-pacs -f
```

### Shell Access
```bash
docker exec -it hasta-pacs /bin/bash
```

### Restart Container
```bash
docker restart hasta-pacs
```

### Remove Container (stops and deletes)
```bash
docker stop hasta-pacs
docker rm hasta-pacs
```

## Troubleshooting

### Container Won't Start
1. Check if ports 8042 and 4242 are available:
   ```bash
   lsof -i :8042
   lsof -i :4242
   ```

2. Check Docker is running:
   ```bash
   docker info
   ```

3. View startup logs:
   ```bash
   docker logs hasta-pacs
   ```

### Cannot Connect to PACS
1. Check container status:
   ```bash
   ./status.sh
   ```

2. Test HTTP endpoint:
   ```bash
   curl http://localhost:8042/system
   ```

3. Test DICOM port:
   ```bash
   nc -z localhost 4242
   ```

### Data Recovery
All data is stored persistently in:
- `./db/` - DICOM database
- `./plugins/` - Orthanc plugins
- `./worklists/` - DICOM worklists
- `./logs/` - Server logs

To backup:
```bash
tar -czf hasta-pacs-backup.tar.gz db/ plugins/ worklists/ config/
```

To restore:
```bash
tar -xzf hasta-pacs-backup.tar.gz
./startup.sh
```

## Integration with OHIF Viewer

The PACS server is configured to work with OHIF viewer via proxy:
- OHIF runs on `http://localhost:3000`
- Proxy routes `/dicom-web` requests to Orthanc
- CORS headers allow cross-origin requests

## Configuration

Edit `config/orthanc.json` to modify:
- Authentication settings
- Plugin configurations
- Network settings
- Storage options

After changing configuration, restart the container:
```bash
./shutdown.sh
./startup.sh
```
