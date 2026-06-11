#!/usr/bin/env python3
import requests
import json
import os

# Read Linux functions analysis
with open('/content/drive/MyDrive/DriverWifi/reverse_engineering/linux_key_functions.txt', 'r') as f:
    linux_functions_content = f.read()

# Read PE imports analysis
with open('/content/drive/MyDrive/DriverWifi/reverse_engineering/backport_candidates.csv', 'r') as f:
    pe_candidates = f.read()

# Read Realtek strings from binary
with open('/content/drive/MyDrive/DriverWifi/reverse_engineering/strings_rtk.txt', 'r') as f:
    binary_strings = f.read()

# OpenRouter API configuration
API_KEY = os.environ.get('OPENROUTER_API_KEY')
API_URL = "https://openrouter.ai/api/v1/chat/completions"

def analyze_with_llm(function_name, linux_code, binary_info):
    """Use LLM to analyze if there are backport opportunities"""
    
    prompt = f"""You are a reverse engineering expert specializing in Windows/Linux driver analysis. 

I need you to analyze potential backport opportunities from a Windows RTL8192EU driver (SDK v2.0) to Linux.

## Context:
- Binary: Windows RTL8192EU driver (rtwlanu.sys, PE x64)
- Target: Linux driver in TL-WN8200ND-driver repo (optimization-wn8200nd branch)
- Binary Realtek strings found: {binary_strings[:500]}
- PE imports include power management functions: NdisMIdleNotificationComplete, NdisMIdleNotificationConfirm
- PE imports include wireless functions: NdisMIndicateReceiveNetBufferLists, NdisMSendNetBufferListsComplete

## Current Linux function:
{function_name}
```c
{linux_code[:2000]}
```

## Analysis needed:
1. Based on the function name and code, what does this function do in the Linux driver?
2. Given that the Windows binary has power management functions (NdisMIdleNotification*) and specific beamforming strings (HalSetBeamforming*), is this function likely to have different implementations in Windows vs Linux?
3. Are there specific features or optimizations in this function that might be improved in the Windows version?
4. Is this function a candidate for backport from Windows to Linux?

## Format your response as:
**Function Purpose:** [brief description]
**Windows vs Linux Differences:** [analysis based on the context]
**Backport Candidate:** [yes/no/partial] 
**Reason:** [specific reason]
**Expected Impact:** [stability/performance/features]
**Difficulty:** [low/medium/high]
"""

    try:
        response = requests.post(
            API_URL,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {API_KEY}",
            },
            json={
                "model": "nvidia/nemotron-3-ultra-550b-a55b:free",
                "messages": [
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                "reasoning": {
                    "enabled": True
                }
            }
        )
        
        if response.status_code == 200:
            result = response.json()
            return result['choices'][0]['message']['content']
        else:
            return f"API Error: {response.status_code} - {response.text}"
            
    except Exception as e:
        return f"Error: {str(e)}"

def analyze_functions():
    """Analyze each key function with LLM"""
    
    # Parse the linux functions file to extract individual functions
    functions = []
    current_function = None
    current_source = []
    
    with open('/content/drive/MyDrive/DriverWifi/reverse_engineering/linux_key_functions.txt', 'r') as f:
        for line in f:
            if line.startswith('=== '):
                if current_function:
                    functions.append({
                        'name': current_function,
                        'source': '\n'.join(current_source)
                    })
                current_function = line.strip('= \n')
                current_source = []
            elif line.startswith('File:') or line.startswith('Lines:'):
                continue
            else:
                current_source.append(line)
        
        # Add last function
        if current_function:
            functions.append({
                'name': current_function,
                'source': '\n'.join(current_source)
            })
    
    # Create analysis directory
    os.makedirs('/content/drive/MyDrive/DriverWifi/reverse_engineering/analysis', exist_ok=True)
    
    # Analyze each function
    for func in functions:
        print(f"Analyzing {func['name']}...")
        
        analysis = analyze_with_llm(
            func['name'],
            func['source'],
            binary_strings
        )
        
        # Save analysis
        safe_name = func['name'].replace('(', '_').replace(')', '_').replace('*', '_')
        with open(f'/content/drive/MyDrive/DriverWifi/reverse_engineering/analysis/{safe_name}_analysis.txt', 'w') as f:
            f.write(f"Function: {func['name']}\n\n")
            f.write(analysis)
        
        print(f"Analysis saved for {func['name']}")
    
    print(f"Completed analysis of {len(functions)} functions")

if __name__ == '__main__':
    analyze_functions()