@echo off
setlocal

REM Hasta Radiologi PACS Server Status Script (Windows)
REM Shows current status and useful information

set CONTAINER_NAME=hasta-pacs
set HTTP_PORT=8042
set DICOM_PORT=4242

echo.
echo 📊 Hasta Radiologi PACS Server Status
echo ====================================

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker Status: Not running
    echo Please start Docker Desktop
    goto end
)
echo ✅ Docker Status: Running

REM Check container status
docker ps -q -f name=%CONTAINER_NAME% >nul 2>&1
if not errorlevel 1 (
    echo ✅ Container Status: Running
    
    REM Get container details
    echo.
    echo 📋 Container Details:
    for /f "tokens=*" %%i in ('docker ps --filter name^=%CONTAINER_NAME% --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"') do echo   %%i
    
    REM Check if web interface is accessible
    echo.
    echo 🌐 Web Interface Check:
    curl -s "http://localhost:%HTTP_PORT%/system" >nul 2>&1
    if not errorlevel 1 (
        echo ✅ Web interface accessible at http://localhost:%HTTP_PORT%
        
        REM Get system info
        echo.
        echo 📊 System Information:
        curl -s "http://localhost:%HTTP_PORT%/system" 2>nul | findstr "Version\|Name"
        
        REM Check plugin status
        echo.
        echo 🔌 Plugin Status:
        for /f %%i in ('curl -s "http://localhost:%HTTP_PORT%/plugins" 2^>nul ^| findstr /c:"[" ^| find /c "["') do (
            if %%i gtr 0 (
                echo ✅ Plugins loaded
            ) else (
                echo ⚠️  No plugins loaded
            )
        )
        
        REM Check studies count
        echo.
        echo 📁 Database Status:
        for /f %%i in ('curl -s "http://localhost:%HTTP_PORT%/statistics" 2^>nul ^| findstr "CountStudies" ^| findstr /o "[0-9]"') do (
            echo Studies count available via API
        )
        
    ) else (
        echo ❌ Web interface not accessible
        echo Container may be starting up or have issues
    )
    
) else (
    REM Check if container exists but is stopped
    docker ps -aq -f name=%CONTAINER_NAME% >nul 2>&1
    if not errorlevel 1 (
        echo ⏹️  Container Status: Stopped
        echo.
        echo To start: run startup.bat
        echo To remove: docker rm %CONTAINER_NAME%
    ) else (
        echo ❌ Container Status: Not found
        echo.
        echo To create and start: run startup.bat
    )
)

REM Check port usage
echo.
echo 🔌 Port Status:
netstat -an | findstr ":%HTTP_PORT% " | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo ✅ Port %HTTP_PORT% (HTTP): In use
) else (
    echo ⚪ Port %HTTP_PORT% (HTTP): Available
)

netstat -an | findstr ":%DICOM_PORT% " | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo ✅ Port %DICOM_PORT% (DICOM): In use  
) else (
    echo ⚪ Port %DICOM_PORT% (DICOM): Available
)

:end
echo.
echo 💡 Management Commands:
echo   Start server:   startup.bat
echo   Stop server:    shutdown.bat
echo   View logs:      docker logs %CONTAINER_NAME% -f
echo   Shell access:   docker exec -it %CONTAINER_NAME% /bin/bash
echo.
pause
