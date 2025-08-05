# Get All Worklists from Orthanc Server
# Multiple methods to retrieve worklist information

Write-Host "🏥 HASTA PACS - Get All Worklists" -ForegroundColor Cyan
Write-Host "=" * 40 -ForegroundColor Cyan
Write-Host ""

# Method 1: Direct file system access
Write-Host "📁 Method 1: File System Access" -ForegroundColor Yellow
Write-Host "Listing DICOM worklist files from Orthanc directory:" -ForegroundColor Gray
Write-Host ""

$worklistFiles = Get-ChildItem "worklists\*.dcm" -ErrorAction SilentlyContinue
if ($worklistFiles) {
    Write-Host "✅ Found $($worklistFiles.Count) worklist files:" -ForegroundColor Green
    
    $worklistFiles | ForEach-Object {
        $sizeKB = [math]::Round($_.Length / 1024, 2)
        $created = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        Write-Host "   📄 $($_.Name)" -ForegroundColor Cyan
        Write-Host "      Size: $($_.Length) bytes (${sizeKB} KB)" -ForegroundColor Gray
        Write-Host "      Created: $created" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Summary statistics
    $totalSize = ($worklistFiles | Measure-Object -Property Length -Sum).Sum
    $totalSizeKB = [math]::Round($totalSize / 1024, 2)
    $avgSize = [math]::Round($totalSize / $worklistFiles.Count, 0)
    
    Write-Host "📊 Summary Statistics:" -ForegroundColor Yellow
    Write-Host "   Total Files: $($worklistFiles.Count)" -ForegroundColor Gray
    Write-Host "   Total Size: $totalSize bytes (${totalSizeKB} KB)" -ForegroundColor Gray
    Write-Host "   Average Size: $avgSize bytes" -ForegroundColor Gray
} else {
    Write-Host "❌ No worklist files found" -ForegroundColor Red
}

Write-Host ""
Write-Host "=" * 40 -ForegroundColor Cyan

# Method 2: Check Orthanc system info
Write-Host ""
Write-Host "🔧 Method 2: Orthanc System Information" -ForegroundColor Yellow
Write-Host "Checking Orthanc server status and worklist plugin:" -ForegroundColor Gray
Write-Host ""

try {
    $system = Invoke-RestMethod -Uri "http://localhost:8042/system" -TimeoutSec 5
    Write-Host "✅ Orthanc Server Status:" -ForegroundColor Green
    Write-Host "   Version: $($system.Version)" -ForegroundColor Gray
    Write-Host "   DICOM AET: $($system.DicomAet)" -ForegroundColor Gray
    Write-Host "   DICOM Port: $($system.DicomPort)" -ForegroundColor Gray
    
    # Check plugins
    $plugins = Invoke-RestMethod -Uri "http://localhost:8042/plugins" -TimeoutSec 5
    if ($plugins -contains "worklists") {
        Write-Host "   Worklist Plugin: ✅ Loaded" -ForegroundColor Green
        
        # Get plugin info
        $pluginInfo = Invoke-RestMethod -Uri "http://localhost:8042/plugins/worklists" -TimeoutSec 5
        Write-Host "   Plugin Version: $($pluginInfo.Version)" -ForegroundColor Gray
    } else {
        Write-Host "   Worklist Plugin: ❌ Not loaded" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Cannot connect to Orthanc server" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=" * 40 -ForegroundColor Cyan

# Method 3: DICOM query information
Write-Host ""
Write-Host "🔍 Method 3: DICOM Query Information" -ForegroundColor Yellow
Write-Host "How to query worklists using DICOM C-FIND:" -ForegroundColor Gray
Write-Host ""

Write-Host "📋 DICOM Worklist Query Parameters:" -ForegroundColor Cyan
Write-Host "   Server: localhost (or your Orthanc server IP)" -ForegroundColor Gray
Write-Host "   Port: 4242" -ForegroundColor Gray
Write-Host "   AE Title: ORTHANC" -ForegroundColor Gray
Write-Host "   Query Level: WORKLIST" -ForegroundColor Gray
Write-Host ""

Write-Host "💻 Example DCMTK Command:" -ForegroundColor Cyan
Write-Host "   findscu -k `"0008,0052=WORKLIST`" -k `"0010,0010=`" -k `"0010,0020=`" localhost 4242" -ForegroundColor Gray
Write-Host ""

Write-Host "🔧 Example Python pynetdicom Code:" -ForegroundColor Cyan
Write-Host @"
   from pynetdicom import AE
   from pynetdicom.sop_class import ModalityWorklistInformationFind
   from pydicom.dataset import Dataset
   
   ae = AE()
   ae.add_requested_context(ModalityWorklistInformationFind)
   
   ds = Dataset()
   ds.QueryRetrieveLevel = 'WORKLIST'
   ds.AccessionNumber = ''  # Empty = get all
   ds.PatientName = ''      # Empty = get all
   
   assoc = ae.associate('localhost', 4242, ae_title='ORTHANC')
   if assoc.is_established:
       responses = assoc.send_c_find(ds, ModalityWorklistInformationFind)
       for (status, identifier) in responses:
           if status and status.Status == 0xFF00:  # Pending
               print(f"Patient: {identifier.PatientName}")
               print(f"Accession: {identifier.AccessionNumber}")
"@ -ForegroundColor Gray

Write-Host ""
Write-Host "=" * 40 -ForegroundColor Cyan

# Method 4: Show available access methods
Write-Host ""
Write-Host "🌐 Method 4: API and Web Access" -ForegroundColor Yellow
Write-Host "Available endpoints and interfaces:" -ForegroundColor Gray
Write-Host ""

Write-Host "📡 REST API Endpoints:" -ForegroundColor Cyan
Write-Host "   Orthanc Web Interface: http://localhost:8042" -ForegroundColor Gray
Write-Host "   Orthanc System Info: http://localhost:8042/system" -ForegroundColor Gray
Write-Host "   Orthanc Plugins: http://localhost:8042/plugins" -ForegroundColor Gray
Write-Host "   Orthanc Modalities: http://localhost:8042/modalities" -ForegroundColor Gray
Write-Host ""

Write-Host "🔌 Hasta Radiologi API:" -ForegroundColor Cyan
Write-Host "   API Base: http://localhost:3001" -ForegroundColor Gray
Write-Host "   Worklist List: http://localhost:3001/api/orthanc/worklists" -ForegroundColor Gray
Write-Host "   Worklist Stats: http://localhost:3001/api/orthanc/worklists/stats" -ForegroundColor Gray
Write-Host "   Health Check: http://localhost:3001/health" -ForegroundColor Gray
Write-Host ""

Write-Host "🖥️ Web Interfaces:" -ForegroundColor Cyan
Write-Host "   OHIF Viewer: http://localhost:3000" -ForegroundColor Gray
Write-Host "   Orthanc Explorer: http://localhost:8042/app/explorer.html" -ForegroundColor Gray
Write-Host ""

Write-Host "🎉 All methods available for worklist access!" -ForegroundColor Green
Write-Host "Choose the method that best fits your integration needs." -ForegroundColor Gray
