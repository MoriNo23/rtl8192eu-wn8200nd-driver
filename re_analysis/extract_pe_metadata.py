#!/usr/bin/env python3
import pefile
import re
import sys

def extract_pe_metadata(sys_path):
    try:
        pe = pefile.PE(sys_path)
        
        print("=== PE Metadata ===")
        if hasattr(pe, 'FileInfo'):
            for fileinfo in pe.FileInfo:
                if hasattr(fileinfo, 'Key') and fileinfo.Key.decode() == 'StringFileInfo':
                    for string_table in fileinfo.StringTable:
                        for entry in string_table.entries.items():
                            if b'FileVersion' in entry[0] or b'ProductVersion' in entry[0]:
                                print(f"{entry[0].decode()}: {entry[1].decode()}")
        
        print("\n=== Imports ===")
        if hasattr(pe, 'DIRECTORY_ENTRY_IMPORT'):
            for entry in pe.DIRECTORY_ENTRY_IMPORT:
                print(f"DLL: {entry.dll.decode()}")
                for imp in entry.imports:
                    if imp.name:
                        print(f"  {imp.name.decode()}")
        
        print("\n=== Exports ===")
        if hasattr(pe, 'DIRECTORY_ENTRY_EXPORT'):
            for exp in pe.DIRECTORY_ENTRY_EXPORT.symbols:
                if exp.name:
                    print(f"{exp.name.decode()} @ {exp.address}")
        
        pe.close()
        return True
    except Exception as e:
        print(f"Error: {e}")
        return False

def filter_rtk_strings(strings_file, output_file):
    prefixes = ['rtw_', 'Rtw', 'hal_', 'Hal', 'odm_', 'ODM_', 'usb_', 'phy_']
    
    with open(strings_file, 'r', encoding='utf-8', errors='ignore') as f:
        strings = f.readlines()
    
    filtered = []
    for s in strings:
        s = s.strip()
        if any(s.startswith(p) for p in prefixes):
            filtered.append(s)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        for s in filtered:
            f.write(s + '\n')
    
    print(f"Filtered {len(filtered)} strings from {len(strings)} total")
    return len(filtered)

if __name__ == '__main__':
    sys_path = '/content/drive/MyDrive/DriverWifi/reverse_engineering/rtl8192eu.sys'
    
    if extract_pe_metadata(sys_path):
        print("\n=== String Filtering ===")
        count = filter_rtk_strings('strings_raw.txt', 'strings_rtk.txt')
        print(f"Found {count} Realtek-related strings")
    else:
        sys.exit(1)