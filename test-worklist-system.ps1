#!/usr/bin/env pwsh
<#
.SYNOPSIS
    DICOM Worklist System Test Script
.DESCRIPTION
    Comprehensive test of the Hasta Radiologi DICOM Worklist system
    Tests API, Orthanc, and DICOM connectivity with sample data
.EXAMPLE
    .\test-worklist-system.ps1
#>

# Colors for output
$Green = @{ForegroundColor = "Green"}
$Red = @{ForegroundColor = "Red"}
$Yellow = @{ForegroundColor = "Yellow"}
$Cyan = @{ForegroundColor = "Cyan"}

Write-Host "🏥 DICOM Worklist System - Comprehensive Test" @Cyan
Write-Host "=============================================" @Cyan

$testResults = @{
    API = $false
    Orthanc = $false
    DICOM = $false
    WorklistCreation = $false
    WorklistQuery = $false
}

# Test 1: API Health Check
Write-Host "`n1. Testing API Server..." @Yellow
try {
    $apiResponse = Invoke-RestMethod -Uri "http://localhost:3001/" -TimeoutSec 10
    Write-Host "   ✅ API Server: $($apiResponse.message) v$($apiResponse.version)" @Green
    $testResults.API = $true
} catch {
    Write-Host "   ❌ API Server: Failed - $($_.Exception.Message)" @Red
}

# Test 2: Orthanc Health Check  
Write-Host "`n2. Testing Orthanc PACS..." @Yellow
try {
    $orthancResponse = Invoke-RestMethod -Uri "http://localhost:8042/system" -TimeoutSec 10
    Write-Host "   ✅ Orthanc PACS: Version $($orthancResponse.Version), AE Title: $($orthancResponse.DicomAet)" @Green
    $testResults.Orthanc = $true
} catch {
    Write-Host "   ❌ Orthanc PACS: Failed - $($_.Exception.Message)" @Red
}

# Test 3: DICOM Connectivity
Write-Host "`n3. Testing DICOM Connectivity..." @Yellow
try {
    $dicomTest = docker exec dcmtk-client echoscu -aet WORKSTATION -aec ORTHANC localhost 4242 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ DICOM Echo: Connection successful" @Green
        $testResults.DICOM = $true
    } else {
        Write-Host "   ❌ DICOM Echo: Connection failed" @Red
        Write-Host "   Error: $dicomTest" @Red
    }
} catch {
    Write-Host "   ❌ DICOM Echo: Failed - $($_.Exception.Message)" @Red
}

# Test 4: Worklist Creation
Write-Host "`n4. Testing Worklist Creation..." @Yellow
$testWorklist = @{
    patientId = "TESTSCRIPT001"
    patientName = "ScriptTest^Patient^Auto"
    patientBirthDate = "1990-01-01"
    patientSex = "M"
    accessionNumber = "SCRIPT$(Get-Date -Format 'HHmmss')"
    studyDescription = "Script Test Study"
    scheduledDate = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")
    scheduledTime = "10:00"
    modality = "CR"
    scheduledStationAETitle = "TESTSTATION"
    institutionName = "Hasta Radiologi Test"
    departmentName = "Quality Assurance"
} | ConvertTo-Json

try {
    $createResponse = Invoke-RestMethod -Uri "http://localhost:3001/api/orthanc/worklists" -Method POST -Body $testWorklist -ContentType "application/json" -TimeoutSec 15
    if ($createResponse.success) {
        Write-Host "   ✅ Worklist Creation: Success" @Green
        Write-Host "   File: $($createResponse.data.filename)" @Green
        $testAccession = ($testWorklist | ConvertFrom-Json).accessionNumber
        $testResults.WorklistCreation = $true
    } else {
        Write-Host "   ❌ Worklist Creation: Failed - $($createResponse.message)" @Red
    }
} catch {
    Write-Host "   ❌ Worklist Creation: Failed - $($_.Exception.Message)" @Red
}

# Test 5: DICOM Worklist Query
if ($testResults.WorklistCreation -and $testResults.DICOM) {
    Write-Host "`n5. Testing DICOM Worklist Query..." @Yellow
    try {
        $queryResult = docker exec dcmtk-client findscu -W -aet WORKSTATION -aec ORTHANC -k "0008,0050=$testAccession" localhost 4242 2>&1
        if ($queryResult -match "Success" -and $queryResult -match $testAccession) {
            Write-Host "   ✅ DICOM Query: Successfully found test worklist" @Green
            $testResults.WorklistQuery = $true
        } else {
            Write-Host "   ❌ DICOM Query: Test worklist not found" @Red
            Write-Host "   Response: $($queryResult -join ' ')" @Red
        }
    } catch {
        Write-Host "   ❌ DICOM Query: Failed - $($_.Exception.Message)" @Red
    }
} else {
    Write-Host "`n5. Skipping DICOM Query (prerequisites failed)" @Yellow
}

# Test 6: Query All Worklists
Write-Host "`n6. Testing General Worklist Query..." @Yellow
try {
    $allQueryResult = docker exec dcmtk-client findscu -W -aet WORKSTATION -aec ORTHANC -k "0010,0010=" -k "0010,0020=" localhost 4242 2>&1
    $patientCount = ($allQueryResult | Select-String "Find Response:").Count
    if ($allQueryResult -match "Success" -and $patientCount -gt 0) {
        Write-Host "   ✅ General Query: Found $patientCount worklist entries" @Green
    } else {
        Write-Host "   ❌ General Query: No worklists found or query failed" @Red
    }
} catch {
    Write-Host "   ❌ General Query: Failed - $($_.Exception.Message)" @Red
}

# Summary
Write-Host "`n" + "="*50 @Cyan
Write-Host "📊 TEST SUMMARY" @Cyan
Write-Host "="*50 @Cyan

$passedTests = ($testResults.Values | Where-Object { $_ -eq $true }).Count
$totalTests = $testResults.Count

foreach ($test in $testResults.GetEnumerator()) {
    $status = if ($test.Value) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($test.Value) { $Green } else { $Red }
    Write-Host "$($test.Key.PadRight(20)): $status" @color
}

Write-Host "`nOverall Result: $passedTests/$totalTests tests passed" @Cyan

if ($passedTests -eq $totalTests) {
    Write-Host "`n🎉 ALL TESTS PASSED! System is fully operational." @Green
    Write-Host "Your DICOM Worklist system is ready for production use." @Green
} elseif ($passedTests -ge 3) {
    Write-Host "`n⚠️  PARTIAL SUCCESS: Core functionality working." @Yellow
    Write-Host "Some advanced features may need attention." @Yellow
} else {
    Write-Host "`n❌ SYSTEM ISSUES DETECTED" @Red
    Write-Host "Please check the failed components and refer to the troubleshooting guide." @Red
}

Write-Host "`n📚 For detailed testing procedures, see: WORKLIST_TESTING_GUIDE.md" @Cyan
Write-Host "🚀 For quick commands, see: QUICK_REFERENCE.md" @Cyan

# Pause to see results
Write-Host "`nPress any key to continue..." @Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
