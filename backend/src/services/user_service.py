from sqlalchemy.orm import Session
from src.models.user import User, UserCreate, UserUpdate
from src.auth.hash_password import HashPassword
from typing import List, Optional
import uuid

class UserService:
    @staticmethod
    def create_user(db: Session, user: UserCreate) -> User:
        """Create a new user"""
        hashed_password = HashPassword.get_password_hash(user.password)
        db_user = User(
            id=str(uuid.uuid4()),
            email=user.email,
            username=user.username,
            full_name=user.full_name,
            farm_name=user.farm_name,
            phone=user.phone,
            hashed_password=hashed_password
        )
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        return db_user
    
    @staticmethod
    def get_user_by_username(db: Session, username: str) -> Optional[User]:
        """Get user by username"""
        return db.query(User).filter(User.username == username).first()
    
    @staticmethod
    def get_user_by_email(db: Session, email: str) -> Optional[User]:
        """Get user by email"""
        return db.query(User).filter(User.email == email).first()
    
    @staticmethod
    def get_all_users(db: Session, skip: int = 0, limit: int = 100) -> List[User]:
        """Get all users"""
        return db.query(User).offset(skip).limit(limit).all()
    
    @staticmethod
    def authenticate_user(db: Session, username: str, password: str) -> Optional[User]:
        """Authenticate a user"""
        user = UserService.get_user_by_username(db, username)
        if not user:
            return None
        if not HashPassword.verify_password(password, user.hashed_password):
            return None
        return user
    
    @staticmethod
    def update_user(db: Session, username: str, user_update: UserUpdate) -> Optional[User]:
        """Update user information"""
        db_user = UserService.get_user_by_username(db, username)
        if db_user:
            update_data = user_update.dict(exclude_unset=True)
            if "password" in update_data:
                update_data["hashed_password"] = HashPassword.get_password_hash(update_data.pop("password"))
            
            for key, value in update_data.items():
                setattr(db_user, key, value)
            
            db.commit()
            db.refresh(db_user)
        return db_user
    
    @staticmethod
    def delete_user(db: Session, username: str) -> bool:
        """Delete a user"""
        db_user = UserService.get_user_by_username(db, username)
        if db_user:
            db.delete(db_user)
            db.commit()
            return True
        return False