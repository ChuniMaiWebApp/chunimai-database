"""
Bug Condition Exploration Test for Supabase Services Restart Fix

**Validates: Requirements 2.1, 2.2, 2.3**

This test MUST FAIL on unfixed code to confirm the bug exists.
The test checks for:
- Auth service fails with "password authentication failed for user supabase_auth_admin"
- Storage service fails with "relation storage.objects does not exist"
- Realtime service fails with "APP_NAME not available"
- Services show continuous restart behavior

EXPECTED OUTCOME ON UNFIXED CODE: Test FAILS (this proves the bug exists)
EXPECTED OUTCOME AFTER FIX: Test PASSES (this confirms the bug is fixed)
"""
import subprocess
import time
import pytest
from pathlib import Path


# Get the project root directory
PROJECT_ROOT = Path(__file__).parent.parent


def get_service_status(service_name):
    """
    Get the status of a Docker Compose service
    
    Returns:
        dict: Service status information including state, restart count, and logs
    """
    try:
        # Get service status
        result = subprocess.run(
            ["docker", "compose", "ps", "--format", "json", service_name],
            cwd=str(PROJECT_ROOT),
            capture_output=True,
            text=True,
            timeout=10
        )
        
        # Get service logs
        logs_result = subprocess.run(
            ["docker", "compose", "logs", "--tail", "50", service_name],
            cwd=str(PROJECT_ROOT),
            capture_output=True,
            text=True,
            timeout=10
        )
        
        return {
            "status_output": result.stdout,
            "logs": logs_result.stdout,
            "returncode": result.returncode
        }
    except subprocess.TimeoutExpired:
        return {
            "status_output": "",
            "logs": "",
            "returncode": -1,
            "error": "timeout"
        }
    except Exception as e:
        return {
            "status_output": "",
            "logs": "",
            "returncode": -1,
            "error": str(e)
        }


def check_service_health(service_name, expected_healthy=True, timeout=60):
    """
    Check if a service is healthy and not restarting
    
    Args:
        service_name: Name of the Docker Compose service
        expected_healthy: Whether the service should be healthy
        timeout: Maximum time to wait for service to stabilize
    
    Returns:
        dict: Health check results including status, restart count, and error messages
    """
    start_time = time.time()
    restart_count = 0
    last_status = None
    error_messages = []
    
    while time.time() - start_time < timeout:
        status_info = get_service_status(service_name)
        logs = status_info.get("logs", "")
        
        # Check for specific error messages in logs
        if "schema \"auth\" does not exist" in logs or 'schema "auth" does not exist' in logs:
            error_messages.append("schema auth does not exist")
        if "schema \"storage\" does not exist" in logs or 'schema "storage" does not exist' in logs:
            error_messages.append("schema storage does not exist")
        if "APP_NAME not available" in logs:
            error_messages.append("APP_NAME not available")
        
        # Check if service is restarting by looking for restart indicators in logs
        if "Restarting" in status_info.get("status_output", ""):
            restart_count += 1
        
        # Check current status
        current_status = status_info.get("status_output", "")
        if current_status != last_status:
            last_status = current_status
        
        time.sleep(2)
    
    return {
        "service": service_name,
        "restart_count": restart_count,
        "error_messages": error_messages,
        "logs_sample": logs[:500] if logs else "",
        "is_healthy": restart_count == 0 and len(error_messages) == 0
    }


@pytest.mark.skipif(
    subprocess.run(["docker", "compose", "version"], capture_output=True).returncode != 0,
    reason="Docker Compose not available"
)
def test_auth_service_starts_successfully():
    """
    Property 1: Bug Condition - Auth Service Khởi Động Thành Công
    
    Test that Auth service starts successfully without schema errors.
    
    **Validates: Requirements 2.1**
    
    EXPECTED ON UNFIXED CODE: FAILS with "schema auth does not exist"
    EXPECTED AFTER FIX: PASSES with healthy service status
    """
    # Start services
    subprocess.run(
        ["docker", "compose", "up", "-d", "postgres", "auth"],
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        timeout=60
    )
    
    # Wait for postgres to be ready
    time.sleep(10)
    
    # Check auth service health
    health_result = check_service_health("auth", expected_healthy=True, timeout=30)
    
    # Assertions for expected behavior (will fail on unfixed code)
    assert health_result["is_healthy"], (
        f"Auth service is not healthy. "
        f"Restart count: {health_result['restart_count']}, "
        f"Errors: {health_result['error_messages']}, "
        f"Logs sample: {health_result['logs_sample']}"
    )
    
    assert health_result["restart_count"] == 0, (
        f"Auth service restarted {health_result['restart_count']} times. "
        f"Expected 0 restarts for healthy service."
    )
    
    assert "schema auth does not exist" not in str(health_result["error_messages"]), (
        f"Auth service has schema errors: {health_result['error_messages']}"
    )


@pytest.mark.skipif(
    subprocess.run(["docker", "compose", "version"], capture_output=True).returncode != 0,
    reason="Docker Compose not available"
)
def test_storage_service_starts_successfully():
    """
    Property 1: Bug Condition - Storage Service Khởi Động Thành Công
    
    Test that Storage service starts successfully without schema errors.
    
    **Validates: Requirements 2.2**
    
    EXPECTED ON UNFIXED CODE: FAILS with "schema storage does not exist"
    EXPECTED AFTER FIX: PASSES with healthy service status
    """
    # Start services
    subprocess.run(
        ["docker", "compose", "up", "-d", "postgres", "storage"],
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        timeout=60
    )
    
    # Wait for postgres to be ready
    time.sleep(10)
    
    # Check storage service health
    health_result = check_service_health("storage", expected_healthy=True, timeout=30)
    
    # Assertions for expected behavior (will fail on unfixed code)
    assert health_result["is_healthy"], (
        f"Storage service is not healthy. "
        f"Restart count: {health_result['restart_count']}, "
        f"Errors: {health_result['error_messages']}, "
        f"Logs sample: {health_result['logs_sample']}"
    )
    
    assert health_result["restart_count"] == 0, (
        f"Storage service restarted {health_result['restart_count']} times. "
        f"Expected 0 restarts for healthy service."
    )
    
    assert "schema storage does not exist" not in str(health_result["error_messages"]), (
        f"Storage service has schema errors: {health_result['error_messages']}"
    )


@pytest.mark.skipif(
    subprocess.run(["docker", "compose", "version"], capture_output=True).returncode != 0,
    reason="Docker Compose not available"
)
def test_realtime_service_starts_successfully():
    """
    Property 1: Bug Condition - Realtime Service Khởi Động Thành Công
    
    Test that Realtime service starts successfully without configuration errors.
    
    **Validates: Requirements 2.3**
    
    EXPECTED ON UNFIXED CODE: FAILS with "APP_NAME not available" or similar config error
    EXPECTED AFTER FIX: PASSES with healthy service status
    """
    # Start services
    subprocess.run(
        ["docker", "compose", "up", "-d", "postgres", "realtime"],
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        timeout=60
    )
    
    # Wait for postgres to be ready
    time.sleep(10)
    
    # Check realtime service health
    health_result = check_service_health("realtime", expected_healthy=True, timeout=30)
    
    # Assertions for expected behavior (will fail on unfixed code)
    assert health_result["is_healthy"], (
        f"Realtime service is not healthy. "
        f"Restart count: {health_result['restart_count']}, "
        f"Errors: {health_result['error_messages']}, "
        f"Logs sample: {health_result['logs_sample']}"
    )
    
    assert health_result["restart_count"] == 0, (
        f"Realtime service restarted {health_result['restart_count']} times. "
        f"Expected 0 restarts for healthy service."
    )
    
    assert "APP_NAME" not in str(health_result["error_messages"]), (
        f"Realtime service has configuration errors: {health_result['error_messages']}"
    )


@pytest.mark.skipif(
    subprocess.run(["docker", "compose", "version"], capture_output=True).returncode != 0,
    reason="Docker Compose not available"
)
def test_all_services_maintain_healthy_status():
    """
    Property 1: Bug Condition - All Services Maintain Healthy Status
    
    Test that Auth, Storage, and Realtime services all maintain healthy status
    with no restarts after 60 seconds.
    
    **Validates: Requirements 2.1, 2.2, 2.3**
    
    EXPECTED ON UNFIXED CODE: FAILS with continuous restart behavior
    EXPECTED AFTER FIX: PASSES with all services healthy
    """
    # Start all services
    subprocess.run(
        ["docker", "compose", "up", "-d"],
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        timeout=60
    )
    
    # Wait for postgres to be ready
    time.sleep(15)
    
    # Check health of all three services
    services = ["auth", "storage", "realtime"]
    results = {}
    
    for service in services:
        results[service] = check_service_health(service, expected_healthy=True, timeout=45)
    
    # Collect all failures
    failures = []
    for service, result in results.items():
        if not result["is_healthy"]:
            failures.append(
                f"{service}: restart_count={result['restart_count']}, "
                f"errors={result['error_messages']}"
            )
    
    # Assert all services are healthy
    assert len(failures) == 0, (
        f"One or more services are not healthy:\n" + "\n".join(failures)
    )
    
    # Assert no restarts for any service
    for service, result in results.items():
        assert result["restart_count"] == 0, (
            f"{service} service restarted {result['restart_count']} times. "
            f"Expected 0 restarts."
        )
