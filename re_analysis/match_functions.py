#!/usr/bin/env python3
import re
import csv

def load_strings(strings_file):
    with open(strings_file, 'r') as f:
        return [line.strip() for line in f if line.strip()]

def load_linux_funcs(funcs_file):
    with open(funcs_file, 'r') as f:
        return set(line.strip() for line in f if line.strip())

def extract_function_names_from_strings(strings):
    """Extract function names from strings that look like function names"""
    function_names = set()
    for s in strings:
        # Match patterns like "hal_Associate_8192EU", "rtw_xyz", etc.
        if re.match(r'^[a-z_][a-z0-9_]*$', s, re.IGNORECASE):
            function_names.add(s)
    return function_names

def match_strings_to_linux_funcs(strings, linux_funcs):
    """Match strings from binary to Linux function names"""
    matches = []
    for s in strings:
        # Try exact match
        if s in linux_funcs:
            matches.append((s, s, 'exact'))
        # Try partial match
        else:
            for func in linux_funcs:
                if s.lower() in func.lower() or func.lower() in s.lower():
                    matches.append((s, func, 'partial'))
                    break
    return matches

def main():
    # Load strings from binary
    strings_rtk = load_strings('strings_rtk.txt')
    strings_raw = load_strings('strings_raw.txt')
    
    # Load Linux function names
    linux_funcs_mori = load_linux_funcs('linux_funcs_mori.txt')
    linux_funcs_mange = load_linux_funcs('linux_funcs_mange.txt')
    linux_funcs_8812au = load_linux_funcs('linux_funcs_8812au.txt')
    
    # Extract function names from strings
    func_names_from_strings = extract_function_names_from_strings(strings_rtk)
    
    # Match to Linux functions
    matches_mori = match_strings_to_linux_funcs(func_names_from_strings, linux_funcs_mori)
    matches_mange = match_strings_to_linux_funcs(func_names_from_strings, linux_funcs_mange)
    matches_8812au = match_strings_to_linux_funcs(func_names_from_strings, linux_funcs_8812au)
    
    # Combine and deduplicate matches
    all_matches = []
    seen = set()
    
    for match in matches_mori:
        key = match[1]  # function name
        if key not in seen:
            all_matches.append((match[1], match[0], 'mori', match[2]))
            seen.add(key)
    
    for match in matches_mange:
        key = match[1]
        if key not in seen:
            all_matches.append((match[1], match[0], 'mange', match[2]))
            seen.add(key)
    
    for match in matches_8812au:
        key = match[1]
        if key not in seen:
            all_matches.append((match[1], match[0], '8812au', match[2]))
            seen.add(key)
    
    # Write to CSV
    with open('function_map.csv', 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['matched_linux_name', 'binary_string', 'source_repo', 'match_type'])
        for match in all_matches:
            writer.writerow(match)
    
    print(f"Found {len(all_matches)} matches between binary strings and Linux functions")
    print(f"Exact matches: {sum(1 for m in all_matches if m[3] == 'exact')}")
    print(f"Partial matches: {sum(1 for m in all_matches if m[3] == 'partial')}")

if __name__ == '__main__':
    main()