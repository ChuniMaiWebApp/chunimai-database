"""
Unit tests for scripts/generate_keys.py
"""

import sys
import os
import tempfile
import shutil
from pathlib import Path
import jwt
import pytest

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'scripts'))

from generate_keys import generate_jwt_secret, generate_jwt_token, update_env_file


class TestGenerateJWTSecret:
    """Tests for generate_jwt_secret function."""
    
    def test_default_length(self):
        """Test that default JWT secret is 64 characters."""
        secret = generate_jwt_secret()
        assert len(secret) == 64
    
    def test_custom_length(self):
        """Test that custom length works."""
        secret = generate_jwt_secret(100)
        assert len(secret) == 100
    
    def test_minimum_length_32(self):
        """Test that minimum length is 32 characters."""
        secret = generate_jwt_secret(32)
        assert len(secret) == 32
    
    def test_length_below_32_raises_error(self):
        """Test that length below 32 raises ValueError."""
        with pytest.raises(ValueError, match="at least 32 characters"):
            generate_jwt_secret(31)
    
    def test_secret_is_random(self):
        """Test that generated secrets are different."""
        secret1 = generate_jwt_secret()
        secret2 = generate_jwt_secret()
        assert secret1 != secret2
    
    def test_secret_contains_valid_characters(self):
        """Test that secret only contains alphanumeric and -_ characters."""
        secret = generate_jwt_secret()
        valid_chars = set('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_')
        assert all(c in valid_chars for c in secret)


class TestGenerateJWTToken:
    """Tests for generate_jwt_token function."""
    
    def test_anon_token_generation(self):
        """Test that anon token is generated correctly."""
        secret = "test-secret-with-at-least-32-characters-long"
        token = generate_jwt_token(secret, "anon")
        
        # Decode and verify
        decoded = jwt.decode(token, secret, algorithms=["HS256"])
        assert decoded["role"] == "anon"
        assert decoded["iss"] == "supabase-local"
        assert "exp" in decoded
    
    def test_service_role_token_generation(self):
        """Test that service_role token is generated correctly."""
        secret = "test-secret-with-at-least-32-characters-long"
        token = generate_jwt_token(secret, "service_role")
        
        # Decode and verify
        decoded = jwt.decode(token, secret, algorithms=["HS256"])
        assert decoded["role"] == "service_role"
        assert decoded["iss"] == "supabase-local"
        assert "exp" in decoded
    
    def test_custom_issuer(self):
        """Test that custom issuer works."""
        secret = "test-secret-with-at-least-32-characters-long"
        token = generate_jwt_token(secret, "anon", issuer="custom-issuer")
        
        decoded = jwt.decode(token, secret, algorithms=["HS256"])
        assert decoded["iss"] == "custom-issuer"
    
    def test_token_has_long_expiration(self):
        """Test that token expiration is set far in the future."""
        import time
        secret = "test-secret-with-at-least-32-characters-long"
        token = generate_jwt_token(secret, "anon")
        
        decoded = jwt.decode(token, secret, algorithms=["HS256"])
        # Should expire more than 1 year from now
        assert decoded["exp"] > time.time() + 365 * 24 * 60 * 60


class TestUpdateEnvFile:
    """Tests for update_env_file function."""
    
    def test_update_env_file_success(self):
        """Test that .env file is updated correctly."""
        # Create a temporary .env file
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.env') as f:
            f.write("# Database Configuration\n")
            f.write("POSTGRES_PASSWORD=test\n")
            f.write("JWT_SECRET=old-secret\n")
            f.write("ANON_KEY=old-anon-key\n")
            f.write("SERVICE_ROLE_KEY=old-service-key\n")
            f.write("API_EXTERNAL_URL=http://localhost:8095\n")
            temp_path = f.name
        
        try:
            # Update the file
            update_env_file(
                temp_path,
                "new-jwt-secret-with-at-least-32-chars",
                "new-anon-key",
                "new-service-key"
            )
            
            # Read and verify
            with open(temp_path, 'r') as f:
                content = f.read()
            
            assert "JWT_SECRET=new-jwt-secret-with-at-least-32-chars" in content
            assert "ANON_KEY=new-anon-key" in content
            assert "SERVICE_ROLE_KEY=new-service-key" in content
            assert "POSTGRES_PASSWORD=test" in content
            assert "API_EXTERNAL_URL=http://localhost:8095" in content
        finally:
            os.unlink(temp_path)
    
    def test_update_env_file_preserves_other_lines(self):
        """Test that other lines in .env are preserved."""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.env') as f:
            f.write("# Comment line\n")
            f.write("CUSTOM_VAR=custom-value\n")
            f.write("JWT_SECRET=old-secret\n")
            f.write("\n")
            f.write("ANON_KEY=old-anon-key\n")
            temp_path = f.name
        
        try:
            update_env_file(temp_path, "new-secret", "new-anon", "new-service")
            
            with open(temp_path, 'r') as f:
                content = f.read()
            
            assert "# Comment line" in content
            assert "CUSTOM_VAR=custom-value" in content
        finally:
            os.unlink(temp_path)
    
    def test_update_env_file_nonexistent_raises_error(self):
        """Test that updating nonexistent file exits with error."""
        with pytest.raises(SystemExit):
            update_env_file("/nonexistent/path/.env", "secret", "anon", "service")


class TestIntegration:
    """Integration tests for the complete workflow."""
    
    def test_full_key_generation_workflow(self):
        """Test the complete workflow of generating and updating keys."""
        # Create a temporary .env file
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.env') as f:
            f.write("JWT_SECRET=placeholder\n")
            f.write("ANON_KEY=placeholder\n")
            f.write("SERVICE_ROLE_KEY=placeholder\n")
            temp_path = f.name
        
        try:
            # Generate keys
            jwt_secret = generate_jwt_secret(64)
            anon_key = generate_jwt_token(jwt_secret, "anon")
            service_role_key = generate_jwt_token(jwt_secret, "service_role")
            
            # Update file
            update_env_file(temp_path, jwt_secret, anon_key, service_role_key)
            
            # Read and verify
            with open(temp_path, 'r') as f:
                content = f.read()
            
            # Extract values
            import re
            jwt_match = re.search(r'JWT_SECRET=(.+)', content)
            anon_match = re.search(r'ANON_KEY=(.+)', content)
            service_match = re.search(r'SERVICE_ROLE_KEY=(.+)', content)
            
            assert jwt_match and len(jwt_match.group(1).strip()) >= 32
            
            # Verify tokens can be decoded with the secret
            extracted_secret = jwt_match.group(1).strip()
            extracted_anon = anon_match.group(1).strip()
            extracted_service = service_match.group(1).strip()
            
            anon_decoded = jwt.decode(extracted_anon, extracted_secret, algorithms=["HS256"])
            assert anon_decoded["role"] == "anon"
            
            service_decoded = jwt.decode(extracted_service, extracted_secret, algorithms=["HS256"])
            assert service_decoded["role"] == "service_role"
        finally:
            os.unlink(temp_path)
