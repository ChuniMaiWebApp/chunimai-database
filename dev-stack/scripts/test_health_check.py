#!/usr/bin/env python3
"""
Unit tests for health_check.py
"""

import sys
import os

# Add the scripts directory to the path
sys.path.insert(0, os.path.dirname(__file__))

import health_check


def test_health_check_configs_defined():
    """Test that all health check configurations are defined."""
    assert len(health_check.HEALTH_CHECKS) == 7, "Expected 7 health check configurations"
    
    service_names = [config.name for config in health_check.HEALTH_CHECKS]
    expected_services = [
        "PostgreSQL",
        "PostgREST",
        "GoTrue Auth",
        "Realtime",
        "Storage",
        "Kong Gateway",
        "Studio"
    ]
    
    for service in expected_services:
        assert service in service_names, f"Missing health check for {service}"
    
    print("✓ All health check configurations are defined")


def test_health_check_types():
    """Test that health check types are valid."""
    valid_types = ['postgres', 'http', 'tcp']
    
    for config in health_check.HEALTH_CHECKS:
        assert config.check_type in valid_types, f"Invalid check type for {config.name}: {config.check_type}"
    
    print("✓ All health check types are valid")


def test_http_checks_have_endpoints():
    """Test that HTTP health checks have endpoints defined."""
    for config in health_check.HEALTH_CHECKS:
        if config.check_type == 'http':
            assert config.endpoint is not None, f"HTTP check for {config.name} missing endpoint"
            assert config.endpoint.startswith('http://'), f"Invalid endpoint for {config.name}"
    
    print("✓ All HTTP health checks have valid endpoints")


def test_tcp_checks_have_ports():
    """Test that TCP health checks have ports defined."""
    for config in health_check.HEALTH_CHECKS:
        if config.check_type == 'tcp':
            assert config.port is not None, f"TCP check for {config.name} missing port"
            assert isinstance(config.port, int), f"Invalid port type for {config.name}"
            assert 1 <= config.port <= 65535, f"Invalid port number for {config.name}"
    
    print("✓ All TCP health checks have valid ports")


def test_retry_configuration():
    """Test that retry configurations are reasonable."""
    for config in health_check.HEALTH_CHECKS:
        assert config.max_retries > 0, f"Invalid max_retries for {config.name}"
        assert config.max_retries <= 10, f"Too many retries for {config.name}"
        assert config.initial_backoff > 0, f"Invalid initial_backoff for {config.name}"
        assert config.timeout > 0, f"Invalid timeout for {config.name}"
    
    print("✓ All retry configurations are valid")


def test_container_names():
    """Test that container names follow the expected pattern."""
    for config in health_check.HEALTH_CHECKS:
        assert config.container_name.startswith('supabase-'), f"Invalid container name for {config.name}"
    
    print("✓ All container names follow the expected pattern")


def test_check_tcp_health_invalid_port():
    """Test TCP health check with invalid port."""
    # Port 1 is typically not in use
    is_healthy, error = health_check.check_tcp_health(1, timeout=1)
    assert not is_healthy, "Expected TCP check to fail for unused port"
    assert error is not None, "Expected error message for failed TCP check"
    
    print("✓ TCP health check correctly handles connection failures")


def main():
    """Run all tests."""
    print("Running health_check.py unit tests...")
    print()
    
    tests = [
        test_health_check_configs_defined,
        test_health_check_types,
        test_http_checks_have_endpoints,
        test_tcp_checks_have_ports,
        test_retry_configuration,
        test_container_names,
        test_check_tcp_health_invalid_port,
    ]
    
    failed = 0
    
    for test in tests:
        try:
            test()
        except AssertionError as e:
            print(f"✗ {test.__name__} failed: {e}")
            failed += 1
        except Exception as e:
            print(f"✗ {test.__name__} error: {e}")
            failed += 1
    
    print()
    
    if failed == 0:
        print(f"✓ All {len(tests)} tests passed!")
        return 0
    else:
        print(f"✗ {failed} test(s) failed")
        return 1


if __name__ == '__main__':
    sys.exit(main())
