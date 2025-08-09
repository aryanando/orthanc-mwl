# Hasta PACS Windows Setup - Troubleshooting Guide

## Quick Start
Use `startup.bat` for simple, reliable startup without custom plugins.

## Files
- `startup.bat` - Simple startup (recommended for most users)
- `startup-advanced.bat` - Advanced startup with plugin options
- `shutdown.bat` - Stop the PACS server  
- `status.bat` - Check server status

## Common Issues & Solutions

### Issue: "Orthanc failed to start within 30 seconds"
**Cause**: Plugin compatibility issues
**Solution**: 
1. Use `startup.bat` instead of `startup-advanced.bat`
2. Or remove/rename the `plugins` folder
3. Check Docker Desktop is running

### Issue: "Port already in use"
**Cause**: Another service is using ports 8042 or 4242
**Solution**:
```cmd
netstat -an | findstr ":8042"
netstat -an | findstr ":4242"
# Stop any services using these ports
```

### Issue: "Docker is not running"
**Solution**: Start Docker Desktop and wait for it to fully initialize

### Issue: Plugin Loading Errors
**Symptoms**: Container keeps restarting, logs show plugin errors
**Solution**: 
1. Move plugin files out of the `plugins` folder temporarily
2. Use `startup.bat` (which doesn't mount plugins)
3. Test if plugins are compatible one by one

## Checking Logs
```cmd
docker logs hasta-pacs -f
```

## Manual Container Management
```cmd
# Stop container
docker stop hasta-pacs

# Start existing container  
docker start hasta-pacs

# Remove container completely
docker rm hasta-pacs

# Access container shell
docker exec -it hasta-pacs /bin/bash
```

## Port Configuration
- HTTP/Web Interface: http://localhost:8042
- DICOM Port: 4242
- To change ports, edit the variables at the top of the startup scripts

## Data Persistence
All data is stored in:
- `db/` - DICOM database
- `worklists/` - Modality worklist files
- `config/` - Configuration files
- `logs/` - Log files

## Network Access
By default, the server is accessible from:
- Local machine: http://localhost:8042
- Network: http://[your-ip]:8042 (if firewall allows)

## Plugin Compatibility
The included plugins may not be compatible with the current Orthanc Docker image version. Use the advanced startup script to test plugin compatibility or stick with the simple startup for guaranteed functionality.
