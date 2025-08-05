@echo off
echo.
echo ==========================================
echo   DICOM Worklist System - Quick Test
echo ==========================================
echo.

:: Test API
echo [1/4] Testing API Server...
curl -s http://localhost:3001/ >nul 2>&1
if %errorlevel% equ 0 (
    echo   ✓ API Server: Running
) else (
    echo   ✗ API Server: Failed
)

:: Test Orthanc HTTP
echo [2/4] Testing Orthanc HTTP...
curl -s http://localhost:8042/system >nul 2>&1
if %errorlevel% equ 0 (
    echo   ✓ Orthanc HTTP: Running
) else (
    echo   ✗ Orthanc HTTP: Failed
)

:: Test Orthanc DICOM
echo [3/4] Testing DICOM Connectivity...
docker exec dcmtk-client echoscu -aet WORKSTATION -aec ORTHANC localhost 4242 >nul 2>&1
if %errorlevel% equ 0 (
    echo   ✓ DICOM Connection: Working
) else (
    echo   ✗ DICOM Connection: Failed
)

:: Test Worklist Query
echo [4/4] Testing Worklist Query...
docker exec dcmtk-client findscu -v -W -aet WORKSTATION -aec ORTHANC -k "0010,0010=" -k "0010,0020=" localhost 4242 2>&1 | findstr "Success" >nul
if %errorlevel% equ 0 (
    echo   ✓ Worklist Query: Working
) else (
    echo   ✗ Worklist Query: Failed
)

echo.
echo ==========================================
echo For detailed testing: test-worklist-system.ps1
echo For quick commands: QUICK_REFERENCE.md
echo ==========================================
echo.
pause
