# Supabase Local Setup - Test Suite

This directory contains the test suite for the Supabase Local Setup project.

## Test Structure

```
tests/
├── __init__.py              # Package initialization
├── conftest.py              # Pytest configuration and shared fixtures
├── test_config_validation.py # Unit tests for configuration validation
└── test_properties.py       # Property-based tests using Hypothesis
```

## Running Tests

### Install Dependencies

```bash
pip install -r requirements.txt
```

### Run All Tests

```bash
pytest
```

### Run Specific Test File

```bash
pytest tests/test_config_validation.py
```

### Run with Verbose Output

```bash
pytest -v
```

### Run Property-Based Tests Only

```bash
pytest tests/test_properties.py
```

## Test Types

### Unit Tests (`test_config_validation.py`)

Unit tests verify specific examples and edge cases:
- Configuration file existence
- File parsing and syntax validation
- Required fields presence
- Edge cases and error conditions

### Property-Based Tests (`test_properties.py`)

Property-based tests verify universal properties across many inputs:
- Docker Compose configuration completeness
- Service dependency order
- Environment variables completeness
- JWT secret minimum length
- And more...

## Configuration

Test configuration is defined in `pytest.ini` at the project root:
- Test discovery patterns
- Hypothesis settings (100 examples per test)
- Output formatting options

## Fixtures

Shared fixtures are defined in `conftest.py`:
- `project_root`: Project root directory path
- `docker_compose_path`: Path to docker-compose.yml
- `env_file_path`: Path to .env file
- `kong_config_path`: Path to kong.yml
- `readme_path`: Path to README.md
