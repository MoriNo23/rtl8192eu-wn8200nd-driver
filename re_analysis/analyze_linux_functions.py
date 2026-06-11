#!/usr/bin/env python3
import os
import re

def find_function_source(codebase_dir, function_name):
    """Find the source code of a function in the codebase"""
    for root, dirs, files in os.walk(codebase_dir):
        for file in files:
            if file.endswith('.c'):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r') as f:
                        content = f.read()
                        # Look for function definition
                        pattern = rf'^[a-zA-Z_][a-zA-Z0-9_\s\*]+\s+{function_name}\s*\('
                        if re.search(pattern, content, re.MULTILINE):
                            # Extract function body
                            lines = content.split('\n')
                            in_function = False
                            function_lines = []
                            brace_count = 0
                            
                            for i, line in enumerate(lines):
                                if re.search(pattern, line, re.MULTILINE):
                                    in_function = True
                                    function_lines.append((i+1, line))
                                    brace_count += line.count('{')
                                    brace_count -= line.count('}')
                                elif in_function:
                                    function_lines.append((i+1, line))
                                    brace_count += line.count('{')
                                    brace_count -= line.count('}')
                                    
                                    if brace_count <= 0:
                                        break
                            
                            if function_lines:
                                return file_path, function_lines
                except Exception as e:
                    continue
    return None, None

def extract_function_body(file_path, function_lines):
    """Extract just the function body from the lines"""
    body_lines = []
    for line_num, line in function_lines:
        body_lines.append(f"{line_num}: {line}")
    return '\n'.join(body_lines)

def analyze_key_functions():
    """Analyze key functions that might differ between Windows and Linux"""
    key_functions = [
        'beamforming_check_sounding_success',
        'rtw_ps_deny',
        'rtw_set_ps_mode',
        'rtw_set_chplan_cmd',
        'usb_read_port',
        'usb_write_port'
    ]
    
    codebase_dir = '/content/drive/MyDrive/DriverWifi/target'
    
    function_analysis = []
    
    for func_name in key_functions:
        file_path, lines = find_function_source(codebase_dir, func_name)
        if file_path:
            function_analysis.append({
                'function': func_name,
                'file': file_path,
                'lines_count': len(lines),
                'source': extract_function_body(file_path, lines)
            })
            print(f"Found {func_name} in {file_path}")
        else:
            print(f"Could not find {func_name}")
    
    return function_analysis

def main():
    functions = analyze_key_functions()
    
    with open('linux_key_functions.txt', 'w') as f:
        for func in functions:
            f.write(f"=== {func['function']} ===\n")
            f.write(f"File: {func['file']}\n")
            f.write(f"Lines: {func['lines_count']}\n")
            f.write(f"Source:\n{func['source']}\n\n")
    
    print(f"Analyzed {len(functions)} key functions")

if __name__ == '__main__':
    main()