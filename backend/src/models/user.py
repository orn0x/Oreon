from sqlalchemy import Column, String, Boolean, DateTime
from sqlalchemy.orm import relationship
from src.database import Base
from pydantic import BaseModel, EmailStr, Field
from datetime import datetime
from typing import Optional, List

# --- SQLAlchemy Model ---

class User(Base):
    __tablename__ = "users"
    
    id = Column(String, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    username = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, nullable=True)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    is_superuser = Column(Boolean, default=False)
    
    # NEW FIELD: This solves your AttributeError
    role = Column(String, default="user", nullable=False) # e.g., 'worker', 'farmer', 'admin'
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    farm_name = Column(String, nullable=True)
    phone = Column(String, nullable=True)
    avatar = Column(String, nullable=True) # Useful for the Chat UI
    
    # Relationships
    conversations = relationship("Conversation", back_populates="user", cascade="all, delete-orphan")

# --- Pydantic Schemas (Data Transfer Objects) ---

class UserBase(BaseModel):
    email: EmailStr
    username: str
    full_name: Optional[str] = None
    farm_name: Optional[str] = None
    phone: Optional[str] = None
    role: Optional[str] = "user" # Included in base for visibility

class UserCreate(UserBase):
    password: str = Field(..., min_length=8)

class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    farm_name: Optional[str] = None
    phone: Optional[str] = None
    password: Optional[str] = None
    role: Optional[str] = None
    avatar: Optional[str] = None

class UserResponse(UserBase):
    id: str
    is_active: bool
    is_superuser: bool
    avatar: Optional[str] = None  # Add this line
    created_at: datetime
    
    class Config:
        from_attributes = True # Allows Pydantic to read SQLAlchemy objects

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None

class UserLogin(BaseModel):
    username: str
    password: str