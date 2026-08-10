#!/usr/bin/env python3
"""
Health check script for Supabase local setup.
Checks the health of each service with retry logic and exponential backoff.
Provides detailed error reporting for troubleshooting.
"""

import subprocess
import sys
import time
import json
from typing import Dict, Optional, Tuple
from dataclasses import dataclass


@dataclass
class HealthCheckConfig:
    """Configuration for a service health check."""
    name: str
    container_name: str
    check_type: str  # 'postgres', 'http', 'tcp'
    endpoint: Optional[str] = None
    port: Optional[int] = None
    timeout: int = 5
    max_retries: int = 5
    initial_backoff: float = 1.0


# Health check configurations for each service
HEALTH_CHECKS = [
    HealthCheckConfig(
        name="PostgreSQL",
        container_name="supabase-postgres",
        check_type="postgres",
        port=5432,
        max_retries=5,
        initial_backoff=2.0
    ),
    HealthCheckConfig(
        name="PostgREST",
        container_name="supabase-rest",
        check_type="http",
        endpoint="http://localhost:3001/",
        max_retries=5,
        initial_backoff=1.0
    ),
    HealthCheckConfig(
        name="GoTrue Auth",
        container_name="supabase-auth",
        check_type="http",
        endpoint="http://localhost:9999/health",
        max_retries=5,
        initial_backoff=1.0
    ),
    HealthCheckConfig(
        name="Realtime",
        container_name="supabase-realtime",
        check_type="tcp",
        port=4000,
        max_retries=5,
        initial_backoff=1.0
    ),
    HealthCheckConfig(
        name="Storage",
        container_name="supabase-storage",
        check_type="http",
        endpoint="http://localhost:5000/status",
        max_retries=5,
        initial_backoff=1.0
    ),
    HealthCheckConfig(
        name="Kong Gateway",
        container_name="supabase-kong",
        check_type="http",
        endpoint="http://localhost:8095/",
        max_retries=5,
        initial_backoff=1.0
    ),
    HealthCheckConfig(
        name="Studio",
        container_name="supabase-studio",
        check_type="http",
        endpoint="http://localhost:3000/",
        max_retries=5,
        initial_backoff=1.0
    ),
]


def check_container_running(container_name: str) -> Tuple[bool, Optional[str]]:
    """
    Check if a Docker container is running.
    Returns (is_running, error_message).
    """
    try:
        result = subprocess.run(
            ['docker', 'inspect', '-f', '{{.State.Running}}', container_name],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode != 0:
            return False, f"Container not found: {container_name}"
        
        is_running = result.stdout.strip().lower() == 'true'
        
        if not is_running:
            # Get container status
            status_result = subprocess.run(
                ['docker', 'inspect', '-f', '{{.State.Status}}', container_name],
                capture_output=True,
                text=True,
                timeout=5
            )
            status = status_result.stdout.strip() if status_result.returncode == 0 else 'unknown'
            return False, f"Container is not running (status: {status})"
        
        return True, None
        
    except subprocess.TimeoutExpired:
        return False, "Docker command timed out"
    except subprocess.SubprocessError as e:
        return False, f"Docker command failed: {str(e)}"
    except FileNotFoundError:
        return False, "Docker command not found. Is Docker installed?"


def check_postgres_health(container_name: str, timeout: int) -> Tuple[bool, Optional[str]]:
    """
    Check PostgreSQL health using pg_isready.
    Returns (is_healthy, error_message).
    """
    try:
        result = subprocess.run(
            ['docker', 'exec', container_name, 'pg_isready', '-U', 'postgres'],
            capture_output=True,
            text=True,
            timeout=timeout
        )
        
        if result.returncode == 0:
            return True, None
        else:
            return False, f"pg_isready failed: {result.stderr.strip() or result.stdout.strip()}"
            
    except subprocess.TimeoutExpired:
        return False, f"Health check timed out after {timeout}s"
    except subprocess.SubprocessError as e:
        return False, f"Health check command failed: {str(e)}"


def check_http_health(endpoint: str, timeout: int) -> Tuple[bool, Optional[str]]:
    """
    Check HTTP endpoint health using curl.
    Returns (is_healthy, error_message).
    """
    try:
        result = subprocess.run(
            ['curl', '-f', '-s', '-o', '/dev/null', '-w', '%{http_code}', '--max-time', str(timeout), endpoint],
            capture_output=True,
            text=True,
            timeout=timeout + 1
        )
        
        status_code = result.stdout.strip()
        
        # Accept 2xx and 3xx status codes as healthy
        if status_code and status_code[0] in ['2', '3']:
            return True, None
        else:
            return False, f"HTTP request failed with status code: {status_code or 'unknown'}"
            
    except subprocess.TimeoutExpired:
        return False, f"HTTP request timed out after {timeout}s"
    except subprocess.SubprocessError as e:
        return False, f"HTTP request failed: {str(e)}"
    except FileNotFoundError:
        # Fallback: try with Python's urllib if curl is not available
        try:
            import urllib.request
            import urllib.error
            
            req = urllib.request.Request(endpoint, method='GET')
            with urllib.request.urlopen(req, timeout=timeout) as response:
                if 200 <= response.status < 400:
                    return True, None
                else:
                    return False, f"HTTP request failed with status code: {response.status}"
        except urllib.error.URLError as e:
            return False, f"HTTP request failed: {str(e)}"
        except Exception as e:
            return False, f"HTTP request failed: {str(e)}"


def check_tcp_health(port: int, timeout: int) -> Tuple[bool, Optional[str]]:
    """
    Check TCP port connectivity.
    Returns (is_healthy, error_message).
    """
    import socket
    
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex(('localhost', port))
        sock.close()
        
        if result == 0:
            return True, None
        else:
            return False, f"TCP connection failed to port {port}"
            
    except socket.timeout:
        return False, f"TCP connection timed out after {timeout}s"
    except Exception as e:
        return False, f"TCP connection failed: {str(e)}"


def get_container_logs(container_name: str, lines: int = 20) -> str:
    """
    Get recent logs from a container for debugging.
    """
    try:
        result = subprocess.run(
            ['docker', 'logs', '--tail', str(lines), container_name],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            return result.stdout + result.stderr
        else:
            return f"Failed to get logs: {result.stderr}"
            
    except Exception as e:
        return f"Failed to get logs: {str(e)}"


def perform_health_check(config: HealthCheckConfig) -> Tuple[bool, Optional[str], int]:
    """
    Perform health check with retry logic and exponential backoff.
    Returns (is_healthy, error_message, attempts).
    """
    # First check if container is running
    is_running, error = check_container_running(config.container_name)
    if not is_running:
        return False, error, 0
    
    # Perform health check with retries
    backoff = config.initial_backoff
    
    for attempt in range(1, config.max_retries + 1):
        # Perform the appropriate health check
        if config.check_type == 'postgres':
            is_healthy, error = check_postgres_health(config.container_name, config.timeout)
        elif config.check_type == 'http':
            is_healthy, error = check_http_health(config.endpoint, config.timeout)
        elif config.check_type == 'tcp':
            is_healthy, error = check_tcp_health(config.port, config.timeout)
        else:
            return False, f"Unknown check type: {config.check_type}", attempt
        
        if is_healthy:
            return True, None, attempt
        
        # If not the last attempt, wait with exponential backoff
        if attempt < config.max_retries:
            time.sleep(backoff)
            backoff *= 2  # Exponential backoff
    
    return False, error, config.max_retries


def print_health_status(results: Dict[str, Tuple[bool, Optional[str], int]]) -> bool:
    """
    Print health check results in a readable format.
    Returns True if all services are healthy, False otherwise.
    """
    all_healthy = True
    healthy_services = []
    unhealthy_services = []
    
    for config in HEALTH_CHECKS:
        is_healthy, error, attempts = results[config.name]
        
        if is_healthy:
            healthy_services.append((config.name, attempts))
        else:
            unhealthy_services.append((config.name, error, config.container_name))
            all_healthy = False
    
    # Print healthy services
    if healthy_services:
        print("[OK] Healthy services:")
        for name, attempts in healthy_services:
            retry_info = f" (after {attempts} attempt{'s' if attempts > 1 else ''})" if attempts > 1 else ""
            print(f"  - {name}{retry_info}")
        print()
    
    # Print unhealthy services
    if unhealthy_services:
        print("[FAIL] Unhealthy services:")
        print()
        
        for name, error, container_name in unhealthy_services:
            print(f"  {name}:")
            print(f"    Error: {error}")
            print(f"    Container: {container_name}")
            print()
            print(f"    Recent logs:")
            logs = get_container_logs(container_name, lines=10)
            for line in logs.splitlines()[-10:]:
                print(f"      {line}")
            print()
        
        print("Troubleshooting suggestions:")
        print("  1. Check container logs: docker logs <container-name>")
        print("  2. Restart the stack: docker-compose restart")
        print("  3. Check for port conflicts: python scripts/check_ports.py")
        print("  4. Verify configuration: python scripts/validate_config.py")
        print("  5. Check Docker resources (memory, CPU)")
        print()
        
        return False
    
    print("[OK] All services are healthy!")
    print()
    
    return True


def main():
    """
    Main entry point.
    """
    # Set UTF-8 encoding for Windows console
    if sys.platform == 'win32':
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except AttributeError:
            # Python < 3.7
            import codecs
            sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    
    print("Checking health of Supabase services...")
    print()
    
    results = {}
    
    for config in HEALTH_CHECKS:
        print(f"Checking {config.name}...", end=' ', flush=True)
        is_healthy, error, attempts = perform_health_check(config)
        results[config.name] = (is_healthy, error, attempts)
        
        if is_healthy:
            print("OK")
        else:
            print("FAIL")
    
    print()
    
    all_healthy = print_health_status(results)
    
    # Exit with appropriate code
    sys.exit(0 if all_healthy else 1)


if __name__ == '__main__':
    main()
