"""
Pytest configuration and shared fixtures for Supabase Local Setup tests
"""
import os
import pytest
from pathlib import Path


@pytest.fixture
def project_root():
    """Return the project root directory"""
    return Path(__file__).parent.parent


@pytest.fixture
def docker_compose_path(project_root):
    """Return path to docker-compose.yml"""
    return project_root / "docker-compose.yml"


@pytest.fixture
def env_file_path(project_root):
    """Return path to .env file"""
    return project_root / ".env"


@pytest.fixture
def kong_config_path(project_root):
    """Return path to kong.yml"""
    return project_root / "kong.yml"


@pytest.fixture
def readme_path(project_root):
    """Return path to README.md"""
    return project_root / "README.md"
