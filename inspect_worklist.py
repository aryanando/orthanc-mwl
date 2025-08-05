#!/usr/bin/env python3
"""
Simple DICOM Worklist File Inspector
Reads and displays DICOM worklist file contents
"""

import os
import sys

try:
    import pydicom
    from pydicom.errors import InvalidDicomError
except ImportError:
    print("❌ Error: pydicom is required")
    print("Install with: pip install pydicom")
    sys.exit(1)

def inspect_worklist_file(filename):
    """Inspect a DICOM worklist file"""
    try:
        print(f"🔍 Inspecting: {filename}")
        print("=" * 50)
        
        # Read DICOM file
        ds = pydicom.dcmread(filename)
        
        print("📋 Basic Information:")
        print(f"   SOPClassUID: {getattr(ds, 'SOPClassUID', 'N/A')}")
        print(f"   Patient Name: {getattr(ds, 'PatientName', 'N/A')}")
        print(f"   Patient ID: {getattr(ds, 'PatientID', 'N/A')}")
        print(f"   Patient Birth Date: {getattr(ds, 'PatientBirthDate', 'N/A')}")
        print(f"   Patient Sex: {getattr(ds, 'PatientSex', 'N/A')}")
        print(f"   Accession Number: {getattr(ds, 'AccessionNumber', 'N/A')}")
        
        # Check for Scheduled Procedure Step Sequence
        if hasattr(ds, 'ScheduledProcedureStepSequence'):
            print("\n🗓️ Scheduled Procedure Step:")
            sps = ds.ScheduledProcedureStepSequence[0]
            print(f"   Modality: {getattr(sps, 'Modality', 'N/A')}")
            print(f"   Start Date: {getattr(sps, 'ScheduledProcedureStepStartDate', 'N/A')}")
            print(f"   Start Time: {getattr(sps, 'ScheduledProcedureStepStartTime', 'N/A')}")
            print(f"   AE Title: {getattr(sps, 'ScheduledStationAETitle', 'N/A')}")
            print(f"   Description: {getattr(sps, 'ScheduledProcedureStepDescription', 'N/A')}")
        
        # Check for Requested Procedure
        print(f"\n📝 Requested Procedure: {getattr(ds, 'RequestedProcedureDescription', 'N/A')}")
        print(f"   Study Description: {getattr(ds, 'StudyDescription', 'N/A')}")
        print(f"   Referring Physician: {getattr(ds, 'ReferringPhysicianName', 'N/A')}")
        
        print(f"\n📊 File Size: {os.path.getsize(filename)} bytes")
        print("✅ File inspection completed")
        
        return True
        
    except InvalidDicomError:
        print(f"❌ Error: {filename} is not a valid DICOM file")
        return False
    except Exception as e:
        print(f"❌ Error reading file: {e}")
        return False

def main():
    worklist_dir = "worklists"
    
    if not os.path.exists(worklist_dir):
        print(f"❌ Worklist directory '{worklist_dir}' not found")
        return
    
    # Find DICOM files
    dcm_files = [f for f in os.listdir(worklist_dir) if f.endswith('.dcm')]
    
    if not dcm_files:
        print("❌ No DICOM files found in worklist directory")
        return
    
    print("🏥 DICOM Worklist File Inspector")
    print("=" * 50)
    print(f"📁 Directory: {worklist_dir}")
    print(f"📊 Found {len(dcm_files)} DICOM files")
    print()
    
    # Inspect first file as example
    first_file = os.path.join(worklist_dir, dcm_files[0])
    inspect_worklist_file(first_file)

if __name__ == "__main__":
    main()
