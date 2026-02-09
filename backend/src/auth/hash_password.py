from passlib.context import CryptContext

# Use argon2 instead of bcrypt (better for Python 3.13+)
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

class HashPassword:
    @staticmethod
    def verify_password(plain_password: str, hashed_password: str) -> bool:
        """Verify a plain password against a hashed password"""
        return pwd_context.verify(plain_password, hashed_password)
    
    @staticmethod
    def get_password_hash(password: str) -> str:
        """Hash a password"""
        return pwd_context.hash(password)