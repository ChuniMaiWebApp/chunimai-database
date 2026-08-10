"""
Unit tests for configuration validation

This module contains unit tests for validating docker-compose.yml,
.env files, and other configuration files.
"""
import pytest


class TestDockerComposeValidation:
    """Tests for docker-compose.yml validation"""
    
    def test_docker_compose_file_exists(self, docker_compose_path):
        """Verify docker-compose.yml file exists"""
        assert docker_compose_path.exists(), "docker-compose.yml not found"
    
    def test_env_file_exists(self, env_file_path):
        """Verify .env file exists"""
        assert env_file_path.exists(), ".env file not found"


class TestEnvironmentValidation:
    """Tests for .env file validation"""
    
    def test_env_file_readable(self, env_file_path):
        """Verify .env file is readable"""
        assert env_file_path.exists()
        with open(env_file_path, 'r') as f:
            content = f.read()
            assert content, ".env file is empty"
