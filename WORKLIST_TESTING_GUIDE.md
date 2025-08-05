# 🏥 DICOM Worklist Testing Guide

Complete guide for testing the Hasta Radiologi DICOM Worklist system with Orthanc and DCMTK.

## 📋 System Overview

This system provides a complete DICOM worklist solution including:
- **API Server**: Node.js/Fastify API for worklist generation (Port 3001)
- **Orthanc PACS**: DICOM server with worklist plugin (Ports 8042/4242)
- **DCMTK Tools**: Docker container for DICOM testing
- **File Integration**: Automatic worklist file management

## ⚙️ Configuration Setup

### Environment Configuration
The system uses environment variables for flexible configuration:

**1. Edit `.env` file in `hasta_radiologi` directory:**
```bash
# Worklist storage directory (supports absolute and relative paths)
ORTHANC_WORKLIST_DIR=f:\PROJECT\hasta-pacs\orthanc-mwl\worklists

# Alternative configurations:
# ORTHANC_WORKLIST_DIR=../orthanc-mwl/worklists  (relative path)
# ORTHANC_WORKLIST_DIR=/opt/orthanc/worklists     (Linux absolute)
```

**2. Test configuration:**
```powershell
cd f:\PROJECT\hasta-pacs\hasta_radiologi
node test/test-worklist-config.js
```

**Expected output:**
```
✅ DicomWorklistGenerator created successfully
📁 Configured worklist directory: f:\PROJECT\hasta-pacs\orthanc-mwl\worklists
✅ Worklist directory exists and is accessible
📄 Found X .wl files in directory
```

## 🚀 Quick Start Testing

### 1. Verify System Status

```powershell
# Check Orthanc container
docker ps | findstr orthanc

# Check API server
Invoke-RestMethod -Uri "http://localhost:3001/" -Method GET

# Check DCMTK client
docker ps | findstr dcmtk
```

### 2. Test Worklist Generation (API)

```powershell
# Simple worklist creation
$json = '{"patientId":"TEST001","patientName":"Test^Patient","patientBirthDate":"1990-01-01","patientSex":"M","accessionNumber":"ACC001","studyDescription":"Test Study","scheduledDate":"2025-01-15","scheduledTime":"10:00","modality":"CR"}'
Invoke-RestMethod -Uri "http://localhost:3001/api/orthanc/worklists" -Method POST -Body $json -ContentType "application/json"
```

### 3. Test DICOM C-FIND Queries

```bash
# Query all worklists
docker exec dcmtk-client findscu -v -W -aet WORKSTATION -aec ORTHANC -k "0010,0010=" -k "0010,0020=" localhost 4242

# Query specific accession number
docker exec dcmtk-client findscu -v -W -aet WORKSTATION -aec ORTHANC -k "0008,0050=ACC001" localhost 4242
```

## 🔧 Detailed Testing Procedures

### API Testing

#### 1. Health Check
```powershell
# Basic health check
Invoke-RestMethod -Uri "http://localhost:3001/health"

# API information
Invoke-RestMethod -Uri "http://localhost:3001/"
```

#### 2. Create Single Worklist
```powershell
$worklistData = @{
    patientId = "P123456"
    patientName = "Doe^John^Middle"
    patientBirthDate = "1985-03-15"
    patientSex = "M"
    accessionNumber = "ACC123456"
    studyDescription = "Chest X-Ray"
    scheduledDate = "2025-01-20"
    scheduledTime = "14:30"
    modality = "CR"
    scheduledStationAETitle = "XRAY01"
    scheduledProcedureStepDescription = "Posterior-Anterior and Lateral Chest"
    requestedProcedureDescription = "Chest Radiography"
    referringPhysician = "Dr. Smith^Jane"
    performingPhysician = "Dr. Johnson^Mike"
    institutionName = "Hasta Radiologi"
    departmentName = "Radiology"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3001/api/orthanc/worklists" -Method POST -Body $worklistData -ContentType "application/json"
```

#### 3. Create Batch Worklists
```powershell
$batchData = @(
    @{
        patientId = "P001"
        patientName = "Smith^Alice"
        patientBirthDate = "1992-05-20"
        patientSex = "F"
        accessionNumber = "BATCH001"
        modality = "CT"
    },
    @{
        patientId = "P002"
        patientName = "Brown^Bob"
        patientBirthDate = "1988-11-10"
        patientSex = "M"
        accessionNumber = "BATCH002"
        modality = "MR"
    }
) | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3001/api/orthanc/worklists/batch" -Method POST -Body $batchData -ContentType "application/json"
```

#### 4. List Worklists
```powershell
# Get all worklist files
$worklists = Invoke-RestMethod -Uri "http://localhost:3001/api/orthanc/worklists"
Write-Host "Total worklists: $($worklists.data.count)"

# Get statistics
Invoke-RestMethod -Uri "http://localhost:3001/api/orthanc/worklists/stats"
```

### DICOM Testing

#### 1. Basic Connectivity Test
```bash
# Test DICOM echo (connectivity)
docker exec dcmtk-client echoscu -aet WORKSTATION -aec ORTHANC localhost 4242
```

#### 2. Worklist Query Examples

**Query All Worklists:**
```bash
docker exec dcmtk-client findscu -v -W -aet WORKSTATION -aec ORTHANC -k "0010,0010=" -k "0010,0020=" localhost 4242
```

**Query by Patient Name:**
```bash
docker exec dcmtk-client findscu -v -W -aet WORKSTATION -aec ORTHANC -k "0010,0010=DOE^JOHN*" localhost 4242
```

**Query by Patient ID:**
```bash
docker exec dcmtk-client findscu -v -W -aet WORKSTATION -aec ORTHANC -k "0010,0020=P123456" localhost 4242
```

**Query by Accession Number:**
```bash
docker exec dcmtk-client findscu -v -W -aet WORKSTATION -aec ORTHANC -k "0008,0050=ACC123456" localhost 4242
```

**Query by Modality:**
```bash
docker exec dcmtk-client findscu -v -W -aet WORKSTATION -aec ORTHANC -k "0040,0100[0].0008,0060=CT" localhost 4242
```

**Query by Scheduled Date:**
```bash
docker exec dcmtk-client findscu -v -W -aet WORKSTATION -aec ORTHANC -k "0040,0100[0].0040,0002=20250120" localhost 4242
```

#### 3. Detailed Information Query
```bash
# Get comprehensive worklist information
docker exec dcmtk-client findscu -v -W -aet WORKSTATION -aec ORTHANC \
  -k "0008,0050=ACC123456" \
  -k "0010,0010=" \
  -k "0010,0020=" \
  -k "0010,0030=" \
  -k "0010,0040=" \
  -k "0040,0100[0].0008,0060=" \
  -k "0040,0100[0].0040,0002=" \
  -k "0040,0100[0].0040,0003=" \
  -k "0040,0100[0].0040,0009=" \
  localhost 4242
```

## 📊 DICOM Tag Reference

### Patient Level Tags
- `(0010,0010)` - Patient Name
- `(0010,0020)` - Patient ID  
- `(0010,0030)` - Patient Birth Date
- `(0010,0040)` - Patient Sex

### Study Level Tags
- `(0008,0050)` - Accession Number
- `(0008,1030)` - Study Description
- `(0020,000D)` - Study Instance UID

### Scheduled Procedure Step Tags (in sequence 0040,0100)
- `(0008,0060)` - Modality
- `(0040,0001)` - Scheduled Station AE Title
- `(0040,0002)` - Scheduled Procedure Step Start Date
- `(0040,0003)` - Scheduled Procedure Step Start Time
- `(0040,0006)` - Scheduled Performing Physician Name
- `(0040,0007)` - Scheduled Procedure Step Description
- `(0040,0009)` - Scheduled Procedure Step ID

## 🛠️ Command Reference

### Essential DCMTK Parameters
- `-W`: Use Worklist SOP Class (Modality Worklist Information Find)
- `-aet WORKSTATION`: Source Application Entity Title (must be in Orthanc config)
- `-aec ORTHANC`: Called Application Entity Title (Orthanc's AE title)
- `-v`: Verbose output
- `-k "tag=value"`: Search key specification

### Port Configuration
- **API Server**: `http://localhost:3001`
- **Orthanc HTTP**: `http://localhost:8042`
- **Orthanc DICOM**: `localhost:4242`

## 🔍 Troubleshooting

### Common Issues

#### 1. "DICOM authorization rejected for AET"
**Problem**: AE Title not configured in Orthanc
**Solution**: Add AE title to `config/orthanc.json` DicomModalities section:
```json
"DicomModalities": {
  "WORKSTATION": ["WORKSTATION", "127.0.0.1", 11112],
  "FINDSCU": ["FINDSCU", "172.17.0.1", 104]
}
```

#### 2. "Connection refused" or "Peer aborted Association"
**Problem**: Network connectivity or container issues
**Solutions**:
- Check if Orthanc container is running: `docker ps | findstr orthanc`
- Verify port access: `Test-NetConnection -ComputerName localhost -Port 4242`
- Restart Orthanc: `docker restart hasta-pacs`

#### 3. "UnableToProcess" response
**Problem**: Missing query parameters or invalid worklist files
**Solutions**:
- Ensure using `-W` flag for worklist queries
- Use proper AE title: `-aet WORKSTATION`
- Check worklist files exist: `docker exec hasta-pacs ls -la /worklists/`

#### 4. API POST requests failing
**Problem**: Service configuration or missing data
**Solutions**:
- Verify API is running: `Invoke-RestMethod "http://localhost:3001/"`
- Check required fields in POST body
- Review service logs: `docker logs hasta-pacs`

### Log Analysis
```bash
# Check Orthanc logs
docker logs hasta-pacs --tail 20

# Check for specific errors
docker logs hasta-pacs 2>&1 | findstr -i error

# Monitor real-time logs
docker logs hasta-pacs -f
```

## 📝 Test Scripts

### Quick Validation Script (PowerShell)
```powershell
# Save as quick-test.ps1
Write-Host "🏥 DICOM Worklist System Test" -ForegroundColor Cyan

# Test API
try {
    $api = Invoke-RestMethod "http://localhost:3001/"
    Write-Host "✅ API Running: $($api.message)" -ForegroundColor Green
} catch {
    Write-Host "❌ API Error: $_" -ForegroundColor Red
}

# Test Orthanc
try {
    $orthanc = Invoke-RestMethod "http://localhost:8042/system"
    Write-Host "✅ Orthanc Running: Version $($orthanc.Version)" -ForegroundColor Green
} catch {
    Write-Host "❌ Orthanc Error: $_" -ForegroundColor Red
}

# Test DICOM connectivity
$dicomTest = docker exec dcmtk-client echoscu -aet WORKSTATION -aec ORTHANC localhost 4242 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ DICOM Connection Working" -ForegroundColor Green
} else {
    Write-Host "❌ DICOM Connection Failed" -ForegroundColor Red
}
```

### Sample Data Creation Script
```powershell
# Create test worklists
$testPatients = @(
    @{ patientId="TEST001"; patientName="Doe^John"; accessionNumber="ACC001"; modality="CR" },
    @{ patientId="TEST002"; patientName="Smith^Jane"; accessionNumber="ACC002"; modality="CT" },
    @{ patientId="TEST003"; patientName="Brown^Bob"; accessionNumber="ACC003"; modality="MR" }
)

foreach ($patient in $testPatients) {
    $json = $patient | ConvertTo-Json
    try {
        $result = Invoke-RestMethod -Uri "http://localhost:3001/api/orthanc/worklists" -Method POST -Body $json -ContentType "application/json"
        Write-Host "✅ Created worklist for $($patient.patientName)" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to create worklist for $($patient.patientName): $_" -ForegroundColor Red
    }
}
```

## 🎯 Success Criteria

A successful test should show:
1. ✅ API responds to health checks
2. ✅ Worklist creation returns success
3. ✅ Files appear in `/worklists/` directory  
4. ✅ DICOM C-FIND returns "Success" status
5. ✅ Query results contain expected patient data

## 📚 Additional Resources

- **API Documentation**: `f:\PROJECT\hasta-pacs\hasta_radiologi\postman\README.md`
- **Postman Collection**: `f:\PROJECT\hasta-pacs\hasta_radiologi\postman\Hasta_Radiologi_API.postman_collection.json`
- **DCMTK Documentation**: https://dicom.offis.de/dcmtk.php.en
- **Orthanc Documentation**: https://book.orthanc-server.com/

---

**System Status**: ✅ Fully Operational  
**Last Updated**: August 4, 2025  
**Version**: 1.0.0
