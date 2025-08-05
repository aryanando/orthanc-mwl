#!/usr/bin/env python3
"""
Simple DICOM Worklist Query Test
Tests the Orthanc worklist functionality using pynetdicom
"""

import sys
import json
from datetime import datetime

try:
    from pynetdicom import AE, debug_logger
    from pynetdicom.sop_class import ModalityWorklistInformationFind
    from pydicom.dataset import Dataset
    debug_logger()
except ImportError:
    print("❌ Error: pynetdicom and pydicom are required")
    print("Install with: pip install pynetdicom pydicom")
    sys.exit(1)

def test_worklist_query():
    """Test DICOM worklist query against Orthanc"""
    
    print("🔍 Testing DICOM Worklist Query")
    print("=" * 40)
    
    # Application Entity
    ae = AE()
    ae.add_requested_context(ModalityWorklistInformationFind)
    
    # Create identifier dataset for worklist query
    ds = Dataset()
    ds.QueryRetrieveLevel = 'WORKLIST'
    ds.AccessionNumber = ''  # Query for all accession numbers
    ds.PatientName = ''      # Query for all patient names
    ds.PatientID = ''        # Query for all patient IDs
    ds.ScheduledProcedureStepSequence = [Dataset()]
    ds.ScheduledProcedureStepSequence[0].Modality = ''
    ds.ScheduledProcedureStepSequence[0].ScheduledStationAETitle = ''
    ds.ScheduledProcedureStepSequence[0].ScheduledProcedureStepStartDate = ''
    ds.ScheduledProcedureStepSequence[0].ScheduledProcedureStepStartTime = ''
    
    try:
        # Connect to Orthanc DICOM server
        print(f"🔗 Connecting to Orthanc at localhost:4242...")
        assoc = ae.associate('localhost', 4242, ae_title='ORTHANC')
        
        if assoc.is_established:
            print("✅ Association established")
            
            # Send C-FIND request
            print("📋 Sending worklist query...")
            responses = assoc.send_c_find(ds, ModalityWorklistInformationFind)
            
            worklist_count = 0
            for (status, identifier) in responses:
                if status:
                    if status.Status == 0xFF00:  # Pending
                        worklist_count += 1
                        print(f"\n📄 Worklist {worklist_count}:")
                        
                        # Print key worklist information
                        if hasattr(identifier, 'PatientName'):
                            print(f"   Patient: {identifier.PatientName}")
                        if hasattr(identifier, 'PatientID'):
                            print(f"   Patient ID: {identifier.PatientID}")
                        if hasattr(identifier, 'AccessionNumber'):
                            print(f"   Accession: {identifier.AccessionNumber}")
                        
                        # Check scheduled procedure step
                        if hasattr(identifier, 'ScheduledProcedureStepSequence'):
                            sps = identifier.ScheduledProcedureStepSequence[0]
                            if hasattr(sps, 'Modality'):
                                print(f"   Modality: {sps.Modality}")
                            if hasattr(sps, 'ScheduledProcedureStepStartDate'):
                                print(f"   Date: {sps.ScheduledProcedureStepStartDate}")
                            if hasattr(sps, 'ScheduledProcedureStepStartTime'):
                                print(f"   Time: {sps.ScheduledProcedureStepStartTime}")
                                
                    elif status.Status == 0x0000:  # Success
                        print(f"\n✅ Query completed successfully!")
                        print(f"📊 Total worklists found: {worklist_count}")
                        break
                else:
                    print("❌ Connection failure")
                    break
            
            # Release association
            assoc.release()
            
        else:
            print("❌ Failed to establish association")
            print("   Check if Orthanc DICOM server is running on port 4242")
            
    except Exception as e:
        print(f"❌ Error during worklist query: {e}")
        return False
    
    return worklist_count > 0

def check_worklist_files():
    """Check the worklist files in the directory"""
    import os
    import glob
    
    print("\n📁 Checking Worklist Files")
    print("=" * 30)
    
    worklist_dir = "worklists"
    if not os.path.exists(worklist_dir):
        print(f"❌ Worklist directory '{worklist_dir}' not found")
        return
    
    dcm_files = glob.glob(os.path.join(worklist_dir, "*.dcm"))
    print(f"📊 Found {len(dcm_files)} DICOM worklist files:")
    
    for i, file_path in enumerate(dcm_files[:5], 1):  # Show first 5
        filename = os.path.basename(file_path)
        size = os.path.getsize(file_path)
        print(f"   {i}. {filename} ({size} bytes)")
    
    if len(dcm_files) > 5:
        print(f"   ... and {len(dcm_files) - 5} more files")

if __name__ == "__main__":
    print("🏥 Hasta PACS - Worklist Test")
    print("=" * 50)
    print(f"📅 Test Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # Check files first
    check_worklist_files()
    
    # Test worklist query
    success = test_worklist_query()
    
    print("\n" + "=" * 50)
    if success:
        print("🎉 Worklist test completed successfully!")
    else:
        print("⚠️  Worklist test encountered issues")
        print("💡 Make sure:")
        print("   - Orthanc is running on port 4242")
        print("   - Worklist plugin is enabled")
        print("   - DICOM files are in /worklists directory")
