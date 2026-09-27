#!/usr/bin/env python3
"""
Inventory verification script that walks the repository and compares file counts
against the master inventory.
"""
import os
import json
from pathlib import Path

def get_subsystem_name(filepath):
    """Determine subsystem name based on file path."""
    # Convert to Path object for easier handling
    path = Path(filepath)
    
    # Get the first directory component (subsystem)
    parts = [p for p in path.parts if p not in ('.', '..')]
    if not parts:
        return "other"
    
    subsystem = parts[0]
    
    # Handle special cases for subsystem names
    if subsystem in ('apps', 'gitops', 'infra', 'config', 'scripts', 'docs', 'tests', 'other'):
        return subsystem
    
    # Check if it's a subsystem based on known patterns
    if any(subsystem.startswith(prefix) for prefix in ('apps-', 'gitops-', 'infra-', 'config-', 'docs-', 'tests-', 'scripts-', 'other-')):
        # Extract the subsystem part
        if subsystem.startswith('apps-'):
            return 'apps'
        elif subsystem.startswith('gitops-'):
            return 'gitops'
        elif subsystem.startswith('infra-'):
            return 'infra'
        elif subsystem.startswith('config-'):
            return 'config'
        elif subsystem.startswith('docs-'):
            return 'docs'
        elif subsystem.startswith('tests-'):
            return 'tests'
        elif subsystem.startswith('scripts-'):
            return 'scripts'
        elif subsystem.startswith('other-'):
            return 'other'
    
    return "other"

def count_files_in_repository():
    """Walk repository and count files by subsystem."""
    file_counts = {}
    ignored_dirs = {'.git', 'skills', 'memory'}
    
    # Walk through the repository root
    for root, dirs, files in os.walk('.'): 
        # Skip ignored directories
        dirs[:] = [d for d in dirs if d not in ignored_dirs]
        
        # Count files in this directory
        for file in files:
            full_path = os.path.join(root, file)
            # Skip hidden files in root (but not in subdirectories)
            if root == '.' and file.startswith('.'): 
                continue
                
            subsystem = get_subsystem_name(full_path)
            file_counts[subsystem] = file_counts.get(subsystem, 0) + 1
    
    return file_counts

def main():
    # Read master inventory
    with open('reports/inventory/master-inventory.json', 'r') as f:
        master_inventory = json.load(f)
    
    # Get file counts from repository
    file_counts = count_files_in_repository()
    
    # Prepare results
    matches = []
    mismatches = []
    
    # Compare with master inventory
    for subsystem_info in master_inventory['subsystems']:
        subsystem_name = subsystem_info['name']
        expected_count = subsystem_info['total_files']
        actual_count = file_counts.get(subsystem_name, 0)
        
        if expected_count == actual_count:
            matches.append({
                'name': subsystem_name,
                'expected': expected_count,
                'actual': actual_count
            })
        else:
            mismatches.append({
                'name': subsystem_name,
                'expected': expected_count,
                'actual': actual_count
            })
    
    # Write verification report
    report = {
        'matches': matches,
        'mismatches': mismatches
    }
    
    with open('reports/inventory/verification-report.json', 'w') as f:
        json.dump(report, f, indent=2)
    
    return 0

if __name__ == '__main__':
    exit(main())
