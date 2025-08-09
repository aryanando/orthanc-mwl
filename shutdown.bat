@echo off
setlocal

REM Hasta Radiologi PACS Server Shutdown Script (Windows)
REM Safely stops and optionally removes the Docker container

set CONTAINER_NAME=hasta-pacs

echo.
echo 🛑 Hasta Radiologi PACS Server Shutdown
echo ======================================

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo ❌ Error: Docker is not running!
    echo The container may already be stopped.
    pause
    exit /b 1
)

REM Check if container exists and is running
docker ps -q -f name=%CONTAINER_NAME% >nul 2>&1
if not errorlevel 1 (
    echo ⏹️  Stopping container: %CONTAINER_NAME%
    docker stop %CONTAINER_NAME%
    if not errorlevel 1 (
        echo ✅ Container stopped successfully
    ) else (
        echo ❌ Error stopping container
        pause
        exit /b 1
    )
) else (
    echo ℹ️  Container %CONTAINER_NAME% is not running
)

REM Ask if user wants to remove the container completely
echo.
echo Do you want to remove the container completely? [y/N]
echo (This will keep your data but require pulling the image again next time)
set /p REMOVE_CONTAINER=
if /i "%REMOVE_CONTAINER%"=="y" goto remove_container
if /i "%REMOVE_CONTAINER%"=="yes" goto remove_container
goto end

:remove_container
docker ps -aq -f name=%CONTAINER_NAME% >nul 2>&1
if not errorlevel 1 (
    echo 🗑️  Removing container: %CONTAINER_NAME%
    docker rm %CONTAINER_NAME%
    if not errorlevel 1 (
        echo ✅ Container removed successfully
    ) else (
        echo ❌ Error removing container
    )
) else (
    echo ℹ️  Container %CONTAINER_NAME% does not exist
)

:end
echo.
echo 🎯 Shutdown complete!
echo.
echo To start again: run startup.bat
echo To check status: run status.bat
echo.
pause
