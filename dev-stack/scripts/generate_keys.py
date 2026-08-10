#!/usr/bin/env python3
"""
Generate secure cryptographic keys for Supabase local setup.

This script generates:
- JWT_SECRET: A secure random secret (64 characters)
- ANON_KEY: JWT token for anonymous access
- SERVICE_ROLE_KEY: JWT token for service role access

The generated keys are written to the .env file.
"""

import secrets
import string
import jwt
import os
import sys
from pathlib import Path
from datetime import datetime, timedelta


def generate_jwt_secret(length=64):
    """
    Generate a secure random JWT secret.
    
    Args:
        length: Length of the secret (minimum 32, default 64)
    
    Returns:
        A secure random string
    """
    if length < 32:
        raise ValueError("JWT_SECRET must be at least 32 characters long")
    
    # Use alphanumeric characters and some special characters
    alphabet = string.ascii_letters + string.digits + "-_"
    return ''.join(secrets.choice(alphabet) for _ in range(length))


def generate_jwt_token(secret, role, issuer="supabase-local"):
    """
    Generate a JWT token for Supabase.
    
    Args:
        secret: The JWT secret to sign the token
        role: The role for the token (anon or service_role)
        issuer: The issuer of the token
    
    Returns:
        A signed JWT token
    """
    # Set expiration to 10 years from now
    exp = datetime.utcnow() + timedelta(days=3650)
    
    payload = {
        "iss": issuer,
        "role": role,
        "exp": int(exp.timestamp())
    }
    
    token = jwt.encode(payload, secret, algorithm="HS256")
    return token


def update_env_file(env_path, jwt_secret, anon_key, service_role_key):
    """
    Update the .env file with generated keys.
    
    Args:
        env_path: Path to the .env file
        jwt_secret: The generated JWT secret
        anon_key: The generated anon key
        service_role_key: The generated service role key
    """
    if not os.path.exists(env_path):
        print(f"Error: .env file not found at {env_path}")
        sys.exit(1)
    
    # Read the current .env file
    with open(env_path, 'r') as f:
        lines = f.readlines()
    
    # Update the keys
    updated_lines = []
    for line in lines:
        if line.startswith('JWT_SECRET='):
            updated_lines.append(f'JWT_SECRET={jwt_secret}\n')
        elif line.startswith('ANON_KEY='):
            updated_lines.append(f'ANON_KEY={anon_key}\n')
        elif line.startswith('SERVICE_ROLE_KEY='):
            updated_lines.append(f'SERVICE_ROLE_KEY={service_role_key}\n')
        else:
            updated_lines.append(line)
    
    # Write back to the .env file
    with open(env_path, 'w') as f:
        f.writelines(updated_lines)
    
    print(f"✓ Updated {env_path} with generated keys")


def main():
    """Main function to generate and update keys."""
    # Determine the .env file path
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    env_path = project_root / '.env'
    
    print("Generating secure cryptographic keys...")
    print()
    
    # Generate JWT secret
    jwt_secret = generate_jwt_secret(64)
    print(f"✓ Generated JWT_SECRET ({len(jwt_secret)} characters)")
    
    # Generate ANON_KEY
    anon_key = generate_jwt_token(jwt_secret, "anon")
    print(f"✓ Generated ANON_KEY")
    
    # Generate SERVICE_ROLE_KEY
    service_role_key = generate_jwt_token(jwt_secret, "service_role")
    print(f"✓ Generated SERVICE_ROLE_KEY")
    
    print()
    
    # Update .env file
    update_env_file(env_path, jwt_secret, anon_key, service_role_key)
    
    print()
    print("Keys generated successfully!")
    print()
    print("IMPORTANT: Keep these keys secure and do not commit them to version control.")


if __name__ == "__main__":
    main()
