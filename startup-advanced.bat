@echo off
setlocal enabledelayedexpansion

REM Hasta Radiologi PACS Server Startup Script (Windows) - Advanced Version
REM Docker container name: hasta-pacs
REM Provides persistent storage and proper configuration with plugin handling

set SCRIPT_DIR=%~dp0
set CONTAINER_NAME=hasta-pacs
set ORTHANC_IMAGE=orthancteam/orthanc
set HTTP_PORT=8042
set DICOM_PORT=4242
set USE_PLUGINS=false

echo.
echo 🏥 Hasta Radiologi PACS Server Startup (Advanced)
echo ===============================================
echo Container: %CONTAINER_NAME%
echo HTTP Port: %HTTP_PORT%
echo DICOM Port: %DICOM_PORT%
echo.

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo ❌ Error: Docker is not running!
    echo Please start Docker Desktop and try again.
    pause
    exit /b 1
)

REM Stop existing container if running
for /f %%i in ('docker ps -q -f name^=%CONTAINER_NAME% 2^>nul') do (
    echo ⏹️  Stopping existing container: %CONTAINER_NAME%
    docker stop %CONTAINER_NAME% >nul 2>&1
)

REM Remove existing container if it exists
for /f %%i in ('docker ps -aq -f name^=%CONTAINER_NAME% 2^>nul') do (
    echo 🗑️  Removing existing container: %CONTAINER_NAME%
    docker rm %CONTAINER_NAME% >nul 2>&1
)

REM Create persistent directories
echo 📁 Creating persistent directories...
if not exist "%SCRIPT_DIR%db" mkdir "%SCRIPT_DIR%db"
if not exist "%SCRIPT_DIR%worklists" mkdir "%SCRIPT_DIR%worklists"
if not exist "%SCRIPT_DIR%logs" mkdir "%SCRIPT_DIR%logs"

REM Handle plugins directory
if not exist "%SCRIPT_DIR%plugins" mkdir "%SCRIPT_DIR%plugins"

REM Check if user wants to use custom plugins
if exist "%SCRIPT_DIR%plugins\*.so" (
    echo.
    echo 🔌 Found custom plugins in plugins directory:
    dir /b "%SCRIPT_DIR%plugins\*.so" 2>nul
    echo.
    echo WARNING: Custom plugins can cause startup failures if incompatible.
    echo Do you want to try using these plugins? [y/N]
    set /p USE_PLUGINS_INPUT=
    if /i "!USE_PLUGINS_INPUT!"=="y" set USE_PLUGINS=true
    if /i "!USE_PLUGINS_INPUT!"=="yes" set USE_PLUGINS=true
)

REM Check if configuration file exists
if not exist "%SCRIPT_DIR%config\orthanc.json" (
    echo ❌ Error: Configuration file not found!
    echo Expected: %SCRIPT_DIR%config\orthanc.json
    pause
    exit /b 1
)

echo ✅ Configuration file found

REM Check if ports are available
netstat -an | findstr ":%HTTP_PORT% " | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo ❌ Error: Port %HTTP_PORT% is already in use!
    echo Please stop the service using this port and try again.
    pause
    exit /b 1
)

netstat -an | findstr ":%DICOM_PORT% " | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo ❌ Error: Port %DICOM_PORT% is already in use!
    echo Please stop the service using this port and try again.
    pause
    exit /b 1
)

echo ✅ Ports %HTTP_PORT% and %DICOM_PORT% are available

REM Pull latest Orthanc image
echo 📥 Pulling Orthanc Docker image...
docker pull %ORTHANC_IMAGE%
if errorlevel 1 (
    echo ❌ Error: Failed to pull Docker image!
    pause
    exit /b 1
)

REM Prepare Docker command
set DOCKER_CMD=docker run -d --name %CONTAINER_NAME% --restart unless-stopped --env=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin --env=SSL_CERT_DIR=/etc/ssl/certs --env=MALLOC_ARENA_MAX=5 --volume="%SCRIPT_DIR%config\orthanc.json:/etc/orthanc/orthanc.json" --volume="%SCRIPT_DIR%db:/var/lib/orthanc/db" --volume="%SCRIPT_DIR%worklists:/worklists" --network=bridge -p %DICOM_PORT%:4242 -p %HTTP_PORT%:8042 --label=org.opencontainers.image.ref.name=ubuntu --label=org.opencontainers.image.version=24.04 --runtime=runc

REM Add plugins volume if requested
if "%USE_PLUGINS%"=="true" (
    echo 🔌 Starting with custom plugins enabled...
    set DOCKER_CMD=!DOCKER_CMD! --volume="%SCRIPT_DIR%plugins:/usr/share/orthanc/plugins"
) else (
    echo 🚀 Starting without custom plugins for maximum compatibility...
)

REM Start Orthanc container
echo 🚀 Starting Hasta PACS container...
%DOCKER_CMD% %ORTHANC_IMAGE%

if errorlevel 1 (
    echo ❌ Error: Failed to start container!
    pause
    exit /b 1
)

REM Wait for container to start
echo ⏳ Waiting for container to start...
timeout /t 3 /nobreak >nul

REM Check if container is running
docker ps -q -f name=%CONTAINER_NAME% >nul 2>&1
if errorlevel 1 (
    echo ❌ Error: Container failed to start!
    echo Container logs:
    docker logs %CONTAINER_NAME%
    
    if "%USE_PLUGINS%"=="true" (
        echo.
        echo 💡 TIP: Try running without custom plugins if startup fails
        echo    Delete or move files from the plugins directory
    )
    pause
    exit /b 1
)

REM Wait for Orthanc to be ready
echo ⏳ Waiting for Orthanc to be ready...
set /a counter=0
:wait_loop
set /a counter+=1
curl -s "http://localhost:%HTTP_PORT%/system" >nul 2>&1
if not errorlevel 1 (
    echo ✅ Orthanc is ready!
    goto :orthanc_ready
)

if %counter% geq 30 (
    echo ❌ Error: Orthanc failed to start within 30 seconds
    echo Container logs:
    docker logs %CONTAINER_NAME%
    
    if "%USE_PLUGINS%"=="true" (
        echo.
        echo 💡 Plugin compatibility issue detected!
        echo    Try running the script again without plugins
    )
    pause
    exit /b 1
)

timeout /t 1 /nobreak >nul
goto :wait_loop

:orthanc_ready

REM Get system information
echo 📊 System Information:
curl -s "http://localhost:%HTTP_PORT%/system" 2>nul

REM Check plugins
echo.
echo 🔌 Checking loaded plugins:
curl -s "http://localhost:%HTTP_PORT%/plugins" 2>nul

REM Check DICOMweb functionality
echo.
echo 🌐 Testing DICOMweb endpoint:
curl -s "http://localhost:%HTTP_PORT%/dicom-web/studies" >nul 2>&1
if not errorlevel 1 (
    echo ✅ DICOMweb endpoint is working
) else (
    echo ⚠️  DICOMweb endpoint not responding ^(may need plugin^)
)

echo.
echo 🎉 Hasta PACS Server Started Successfully!
echo =======================================
echo Container Name: %CONTAINER_NAME%
echo Web Interface: http://localhost:%HTTP_PORT%
echo DICOM Port: %DICOM_PORT%
echo Data Directory: %SCRIPT_DIR%db
echo Config File: %SCRIPT_DIR%config\orthanc.json
if "%USE_PLUGINS%"=="true" (
    echo Plugins: Custom plugins enabled
) else (
    echo Plugins: Using built-in plugins only
)
echo.
echo Management Commands:
echo   View logs:    docker logs %CONTAINER_NAME% -f
echo   Stop server:  docker stop %CONTAINER_NAME%
echo   Start server: docker start %CONTAINER_NAME%
echo   Remove:       docker rm %CONTAINER_NAME%
echo   Shell access: docker exec -it %CONTAINER_NAME% /bin/bash
echo.
echo 📚 API Endpoints:
echo   System info:  http://localhost:%HTTP_PORT%/system
echo   Studies:      http://localhost:%HTTP_PORT%/studies
echo   Patients:     http://localhost:%HTTP_PORT%/patients
echo   DICOMweb:     http://localhost:%HTTP_PORT%/dicom-web/studies
echo.
echo Server is ready for DICOM operations!
echo.
pause
