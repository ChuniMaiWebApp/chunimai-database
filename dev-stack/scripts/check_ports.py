#!/usr/bin/env python3
"""
Port availability checker for Supabase local setup.
Checks if required ports are available and lists conflicting processes.
Works on Windows, Linux, and macOS.
"""

import subprocess
import sys
import platform
from typing import List, Dict, Optional


# Required ports for Supabase services
REQUIRED_PORTS = {
    3000: "Studio (Web UI)",
    3001: "PostgREST (REST API)",
    4000: "Realtime",
    5000: "Storage API",
    5432: "PostgreSQL",
    8095: "Kong Gateway",
    9999: "GoTrue (Auth API)"
}


def check_port_windows(port: int) -> Optional[Dict[str, str]]:
    """
    Check if a port is in use on Windows using netstat.
    Returns process info if port is in use, None otherwise.
    """
    try:
        # Use netstat to find processes using the port
        result = subprocess.run(
            ['netstat', '-ano'],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode != 0:
            return None
        
        # Parse netstat output
        for line in result.stdout.splitlines():
            if f':{port}' in line and 'LISTENING' in line:
                parts = line.split()
                if len(parts) >= 5:
                    pid = parts[-1]
                    
                    # Get process name using tasklist
                    try:
                        task_result = subprocess.run(
                            ['tasklist', '/FI', f'PID eq {pid}', '/FO', 'CSV', '/NH'],
                            capture_output=True,
                            text=True,
                            timeout=5
                        )
                        
                        if task_result.returncode == 0 and task_result.stdout:
                            # Parse CSV output
                            process_line = task_result.stdout.strip().split(',')
                            if len(process_line) >= 1:
                                process_name = process_line[0].strip('"')
                                return {
                                    'pid': pid,
                                    'process': process_name,
                                    'address': parts[1] if len(parts) > 1 else 'unknown'
                                }
                    except (subprocess.TimeoutExpired, subprocess.SubprocessError):
                        return {
                            'pid': pid,
                            'process': 'unknown',
                            'address': parts[1] if len(parts) > 1 else 'unknown'
                        }
        
        return None
    except (subprocess.TimeoutExpired, subprocess.SubprocessError, FileNotFoundError):
        return None


def check_port_unix(port: int) -> Optional[Dict[str, str]]:
    """
    Check if a port is in use on Unix-like systems using lsof or ss.
    Returns process info if port is in use, None otherwise.
    """
    try:
        # Try lsof first
        result = subprocess.run(
            ['lsof', '-i', f':{port}', '-sTCP:LISTEN'],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0 and result.stdout:
            lines = result.stdout.strip().split('\n')
            if len(lines) > 1:
                # Parse lsof output (skip header)
                parts = lines[1].split()
                if len(parts) >= 2:
                    return {
                        'pid': parts[1],
                        'process': parts[0],
                        'address': parts[8] if len(parts) > 8 else 'unknown'
                    }
    except (subprocess.TimeoutExpired, subprocess.SubprocessError, FileNotFoundError):
        pass
    
    try:
        # Try ss as fallback
        result = subprocess.run(
            ['ss', '-tlnp', f'sport = :{port}'],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0 and result.stdout:
            lines = result.stdout.strip().split('\n')
            if len(lines) > 1:
                # Parse ss output
                for line in lines[1:]:
                    if f':{port}' in line:
                        parts = line.split()
                        if len(parts) >= 6:
                            # Extract PID and process from users column
                            users_info = parts[-1]
                            if 'pid=' in users_info:
                                pid = users_info.split('pid=')[1].split(',')[0].split(')')[0]
                                process = users_info.split('("')[1].split('"')[0] if '("' in users_info else 'unknown'
                                return {
                                    'pid': pid,
                                    'process': process,
                                    'address': parts[3] if len(parts) > 3 else 'unknown'
                                }
    except (subprocess.TimeoutExpired, subprocess.SubprocessError, FileNotFoundError):
        pass
    
    return None


def check_port(port: int) -> Optional[Dict[str, str]]:
    """
    Check if a port is in use (cross-platform).
    Returns process info if port is in use, None otherwise.
    """
    system = platform.system()
    
    if system == 'Windows':
        return check_port_windows(port)
    else:
        return check_port_unix(port)


def get_kill_command(pid: str) -> str:
    """
    Get the appropriate kill command for the current platform.
    """
    system = platform.system()
    
    if system == 'Windows':
        return f'taskkill /PID {pid} /F'
    else:
        return f'kill -9 {pid}'


def check_all_ports() -> Dict[int, Optional[Dict[str, str]]]:
    """
    Check all required ports and return their status.
    """
    results = {}
    
    for port in REQUIRED_PORTS.keys():
        results[port] = check_port(port)
    
    return results


def print_results(results: Dict[int, Optional[Dict[str, str]]]) -> bool:
    """
    Print the results of port checking.
    Returns True if all ports are available, False otherwise.
    """
    conflicts = []
    available = []
    
    for port, info in results.items():
        service_name = REQUIRED_PORTS[port]
        
        if info:
            conflicts.append((port, service_name, info))
        else:
            available.append((port, service_name))
    
    # Print available ports
    if available:
        print("✓ Available ports:")
        for port, service in available:
            print(f"  - Port {port} ({service})")
        print()
    
    # Print conflicts
    if conflicts:
        print("✗ Port conflicts detected:")
        print()
        
        for port, service, info in conflicts:
            print(f"  Port {port} ({service}):")
            print(f"    Process: {info['process']}")
            print(f"    PID: {info['pid']}")
            print(f"    Address: {info['address']}")
            print(f"    To stop: {get_kill_command(info['pid'])}")
            print()
        
        print("Suggested solutions:")
        print("  1. Stop the conflicting processes using the commands above")
        print("  2. Change the port mappings in docker-compose.yml")
        print("  3. Stop Docker containers if they're from a previous run:")
        print("     docker-compose down")
        print()
        
        return False
    
    print("✓ All required ports are available!")
    print("You can start the Supabase stack now.")
    print()
    
    return True


def main():
    """
    Main entry point.
    """
    print("Checking port availability for Supabase local setup...")
    print()
    
    results = check_all_ports()
    all_available = print_results(results)
    
    # Exit with appropriate code
    sys.exit(0 if all_available else 1)


if __name__ == '__main__':
    main()
