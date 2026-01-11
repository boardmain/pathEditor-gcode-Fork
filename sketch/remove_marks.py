#!/usr/bin/env python3
import sys
import re
import os

def clean_gcode(file_path):
    if not os.path.exists(file_path):
        print(f"Error: File {file_path} not found.")
        sys.exit(1)

    with open(file_path, 'r') as f:
        content = f.read()

    # Define the pattern for the registration marks.
    # Based on user description: 7 lines total.
    # G0 Z... ;
    # G0 X... Y... ; Initial position
    # G0 Z... ;
    # F... ; Linear speed
    # G1 ...
    # G1 ...
    # G0 Z... ; pen up
    
    # We use regex to match this specific block structure.
    # We look for exactly TWO 'G1' commands effectively.
    
    # Notes on regex:
    # - `G0 Z.*? ;` matches the first Z up line (non-greedy to avoid eating file).
    # - `G0 X.*? Y.*? ; Initial position` matches the specific start line comments from vpype config.
    # - We match the rest line by line.
    
    pattern = (
        r"G0 Z.*? ;\n"
        r"G0 X.*? Y.*? ; Initial position\n"
        r"G0 Z.*? ;\n"
        r"F.*? ; Linear speed\n"
        r"G1 .*?\n"
        r"G1 .*?\n"
        r"G0 Z.*? ; pen up"
    )
    
    # Function to replace Z moves with Z0.0 inside the found block
    def neutralize_z(match):
        block = match.group(0)
        # Replace any G0 Z<value> with G0 Z0.0
        return re.sub(r"G0 Z[\d\.]+", "G0 Z0.0", block)

    # Find all matches and replace them
    if re.search(pattern, content, re.MULTILINE):
        matches = re.findall(pattern, content, re.MULTILINE)
        print(f"Found {len(matches)} registration mark blocks. Neutralizing them (setting Z to 0.0)...")
        new_content = re.sub(pattern, neutralize_z, content, flags=re.MULTILINE)
        
        with open(file_path, 'w') as f:
            f.write(new_content)
        print("G-code modified successfully.")
    else:
        print("No registration marks found to modify.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 remove_marks.py <gcode_file>")
        sys.exit(1)
    
    clean_gcode(sys.argv[1])
