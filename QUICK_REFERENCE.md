# 🚀 DICOM Worklist Quick Reference

## Configuration

### 📁 Worklist Directory Setup
The system reads the worklist storage path from environment variables:

**Edit `.env` file:**
```bash
# Set your worklist directory (supports absolute and relative paths)
ORTHANC_WORKLIST_DIR=f:\PROJECT\hasta-pacs\orthanc-mwl\worklists

# Alternative examples:
# ORTHANC_WORKLIST_DIR=../orthanc-mwl/worklists  (relative)
# ORTHANC_WORKLIST_DIR=/opt/orthanc/worklists     (Linux)
```

**Test configuration:**
```powershell
cd f:\PROJECT\hasta-pacs\hasta_radiologi
node test/test-worklist-config.js
```

## Essential Commands (Copy & Paste Ready)

### 🔍 Test System Status
```powershell
# Check all components
docker ps | findstr "orthanc\|dcmtk"
Invoke-RestMethod "http://localhost:3001/"
Invoke-RestMethod "http://localhost:8042/system" | Select-Object Version, DicomAet, DicomPort
```

### 📝 Create Test Worklist
```powershell
$json = '{"patientId":"QUICK001","patientName":"Test^Patient","patientBirthDate":"1990-01-01","patientSex":"M","accessionNumber":"QACC001","studyDescription":"Quick Test","scheduledDate":"2025-01-15","scheduledTime":"10:00","modality":"CR"}'
Invoke-RestMethod -Uri "http://localhost:3001/api/orthanc/worklists" -Method POST -Body $json -ContentType "application/json"
```

### 🔎 Query Worklists via DICOM

**Query All:**
```bash
docker exec dcmtk-client findscu -v -W -aet WORKSTATION -aec ORTHANC -k "0010,0010=" -k "0010,0020=" localhost 4242
```

**Query by Accession:**
```bash
docker exec dcmtk-client findscu -v -W -aet WORKSTATION -aec ORTHANC -k "0008,0050=QACC001" localhost 4242
```

**Query with Details:**
```bash
docker exec dcmtk-client findscu -v -W -aet WORKSTATION -aec ORTHANC -k "0008,0050=QACC001" -k "0010,0010=" -k "0010,0020=" -k "0040,0100[0].0008,0060=" -k "0040,0100[0].0040,0002=" localhost 4242
```

## 📊 Expected Results

### ✅ Successful API Response:
```json
{
  "success": true,
  "message": "Worklist created successfully",
  "data": {
    "filename": "QACC001_1754276954695.wl",
    "filepath": "...",
    "size": 680
  }
}
```

### ✅ Successful DICOM Query:
```
I: Association Accepted (Max Send PDV: 16372)
I: ---------------------------
I: Find Response: 1 (Pending)
I: (0008,0050) SH [QACC001]
I: (0010,0010) PN [TEST^PATIENT]
I: (0010,0020) LO [QUICK001]
I: Received Final Find Response (Success)
```

## 🛠️ Quick Fixes

### Problem: Authorization Rejected
```bash
# Add to orthanc.json DicomModalities section:
"WORKSTATION": ["WORKSTATION", "127.0.0.1", 11112]
# Then restart: docker restart hasta-pacs
```

### Problem: API Not Responding
```powershell
cd f:\PROJECT\hasta-pacs\hasta_radiologi
npm run dev
```

### Problem: No DICOM Response
```bash
# Check Orthanc logs
docker logs hasta-pacs --tail 10
# Restart if needed
docker restart hasta-pacs
```

## 🎯 One-Line Status Check
```powershell
Write-Host "API:" $(try{(Invoke-RestMethod "http://localhost:3001/").message}catch{"FAILED"}) "| Orthanc:" $(try{(Invoke-RestMethod "http://localhost:8042/system").Version}catch{"FAILED"}) "| DICOM:" $(if((docker exec dcmtk-client echoscu -aet WORKSTATION -aec ORTHANC localhost 4242 2>&1; $LASTEXITCODE -eq 0)){"OK"}else{"FAILED"})
```

---
**Quick Test File**: `WORKLIST_TESTING_GUIDE.md` | **Version**: 1.0 | **Updated**: Aug 4, 2025
