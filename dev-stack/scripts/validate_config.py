#!/usr/bin/env python3
"""
Configuration validation script for Supabase Local Setup.

Validates:
- docker-compose.yml syntax and completeness
- .env file has all required variables
- JWT_SECRET length >= 32 characters
- Port numbers are valid
"""

import os
import sys
import yaml
from pathlib import Path
from typing import Dict, List, Tuple


class ConfigValidator:
    """Validates Supabase local configuration files."""
    
    REQUIRED_SERVICES = [
        'postgres', 'rest', 'auth', 'realtime', 'storage', 'kong', 'studio'
    ]
    
    REQUIRED_ENV_VARS = [
        'POSTGRES_PASSWORD',
        'POSTGRES_DB',
        'POSTGRES_USER',
        'JWT_SECRET',
        'ANON_KEY',
        'SERVICE_ROLE_KEY',
        'API_EXTERNAL_URL',
        'STUDIO_PORT'
    ]
    
    REQUIRED_PORTS = {
        'postgres': 5432,
        'rest': 3001,
        'auth': 9999,
        'realtime': 4000,
        'storage': 5000,
        'kong': 8095,
        'studio': 3000
    }
    
    def __init__(self, base_path: str = '.'):
        """Initialize validator with base path."""
        self.base_path = Path(base_path)
        self.errors: List[str] = []
        self.warnings: List[str] = []
    
    def validate_all(self) -> bool:
        """Run all validations. Returns True if all pass."""
        print("🔍 Validating Supabase local configuration...\n")
        
        # Validate docker-compose.yml
        docker_compose_valid = self.validate_docker_compose()
        
        # Validate .env file
        env_valid = self.validate_env_file()
        
        # Print results
        self._print_results()
        
        return docker_compose_valid and env_valid and len(self.errors) == 0
    
    def validate_docker_compose(self) -> bool:
        """Validate docker-compose.yml file."""
        print("📋 Validating docker-compose.yml...")
        
        compose_file = self.base_path / 'docker-compose.yml'
        
        # Check file exists
        if not compose_file.exists():
            self.errors.append(f"docker-compose.yml not found at {compose_file}")
            return False
        
        # Parse YAML
        try:
            with open(compose_file, 'r') as f:
                config = yaml.safe_load(f)
        except yaml.YAMLError as e:
            self.errors.append(f"Invalid YAML syntax in docker-compose.yml: {e}")
            return False
        except Exception as e:
            self.errors.append(f"Error reading docker-compose.yml: {e}")
            return False
        
        # Validate structure
        if not isinstance(config, dict):
            self.errors.append("docker-compose.yml must be a YAML dictionary")
            return False
        
        # Check services section exists
        if 'services' not in config:
            self.errors.append("docker-compose.yml missing 'services' section")
            return False
        
        services = config['services']
        
        # Check all required services are defined
        missing_services = []
        for service in self.REQUIRED_SERVICES:
            if service not in services:
                missing_services.append(service)
        
        if missing_services:
            self.errors.append(
                f"Missing required services: {', '.join(missing_services)}"
            )
            return False
        
        # Validate port mappings
        self._validate_ports(services)
        
        # Validate volumes
        self._validate_volumes(config)
        
        # Validate networks
        self._validate_networks(config)
        
        print("✅ docker-compose.yml validation passed\n")
        return True
    
    def _validate_ports(self, services: Dict) -> None:
        """Validate port configurations in services."""
        for service_name, expected_port in self.REQUIRED_PORTS.items():
            if service_name not in services:
                continue
            
            service = services[service_name]
            
            # Check if ports are defined
            if 'ports' not in service:
                self.warnings.append(
                    f"Service '{service_name}' has no port mappings defined"
                )
                continue
            
            ports = service['ports']
            if not isinstance(ports, list) or len(ports) == 0:
                self.warnings.append(
                    f"Service '{service_name}' has empty ports configuration"
                )
                continue
            
            # Validate port numbers
            for port_mapping in ports:
                if isinstance(port_mapping, str):
                    parts = port_mapping.split(':')
                    if len(parts) >= 2:
                        host_port = parts[0]
                        try:
                            port_num = int(host_port)
                            if port_num < 1 or port_num > 65535:
                                self.errors.append(
                                    f"Invalid port number {port_num} in service '{service_name}'"
                                )
                        except ValueError:
                            self.errors.append(
                                f"Invalid port format '{host_port}' in service '{service_name}'"
                            )
    
    def _validate_volumes(self, config: Dict) -> None:
        """Validate volumes configuration."""
        if 'volumes' not in config:
            self.errors.append("docker-compose.yml missing 'volumes' section")
            return
        
        volumes = config['volumes']
        required_volumes = ['supabase_db_data']
        
        for vol in required_volumes:
            if vol not in volumes:
                self.errors.append(f"Missing required volume: {vol}")
    
    def _validate_networks(self, config: Dict) -> None:
        """Validate networks configuration."""
        if 'networks' not in config:
            self.errors.append("docker-compose.yml missing 'networks' section")
            return
        
        networks = config['networks']
        if 'supabase_network' not in networks:
            self.errors.append("Missing required network: supabase_network")
    
    def validate_env_file(self) -> bool:
        """Validate .env file."""
        print("🔐 Validating .env file...")
        
        env_file = self.base_path / '.env'
        
        # Check file exists
        if not env_file.exists():
            self.errors.append(f".env file not found at {env_file}")
            return False
        
        # Parse .env file
        env_vars = self._parse_env_file(env_file)
        
        # Check all required variables exist
        missing_vars = []
        for var in self.REQUIRED_ENV_VARS:
            if var not in env_vars or not env_vars[var]:
                missing_vars.append(var)
        
        if missing_vars:
            self.errors.append(
                f"Missing or empty required environment variables: {', '.join(missing_vars)}"
            )
            return False
        
        # Validate JWT_SECRET length
        jwt_secret = env_vars.get('JWT_SECRET', '')
        if len(jwt_secret) < 32:
            self.errors.append(
                f"JWT_SECRET must be at least 32 characters long (current: {len(jwt_secret)})"
            )
            return False
        
        # Validate STUDIO_PORT is a valid number
        studio_port = env_vars.get('STUDIO_PORT', '')
        if studio_port:
            try:
                port_num = int(studio_port)
                if port_num < 1 or port_num > 65535:
                    self.errors.append(
                        f"STUDIO_PORT must be between 1 and 65535 (current: {port_num})"
                    )
            except ValueError:
                self.errors.append(
                    f"STUDIO_PORT must be a valid number (current: '{studio_port}')"
                )
        
        print("✅ .env file validation passed\n")
        return True
    
    def _parse_env_file(self, env_file: Path) -> Dict[str, str]:
        """Parse .env file and return dictionary of variables."""
        env_vars = {}
        
        try:
            with open(env_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    
                    # Skip empty lines and comments
                    if not line or line.startswith('#'):
                        continue
                    
                    # Parse KEY=VALUE
                    if '=' in line:
                        key, value = line.split('=', 1)
                        key = key.strip()
                        value = value.strip()
                        env_vars[key] = value
        except Exception as e:
            self.errors.append(f"Error reading .env file: {e}")
        
        return env_vars
    
    def _print_results(self) -> None:
        """Print validation results."""
        print("=" * 60)
        print("📊 Validation Summary:")
        print(f"  - docker-compose.yml: Checked syntax, services, ports, volumes, networks")
        print(f"  - .env file: Checked required variables, JWT_SECRET length, port numbers")
        
        if self.warnings:
            print("\n⚠️  Warnings:")
            for warning in self.warnings:
                print(f"  - {warning}")
        
        if self.errors:
            print("\n❌ Errors:")
            for error in self.errors:
                print(f"  - {error}")
            print("\n❌ Validation FAILED")
        else:
            print("\n✅ All validations PASSED")
        
        print("=" * 60)


def main():
    """Main entry point."""
    # Determine base path (parent directory of scripts/)
    script_dir = Path(__file__).parent
    base_path = script_dir.parent
    
    validator = ConfigValidator(base_path)
    success = validator.validate_all()
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
