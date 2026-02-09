from sqlalchemy import Column, String, DateTime, Boolean, Integer
from src.database import Base
from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List

class ChatMessage(Base):
    __tablename__ = "chat_messages"
    
    id = Column(String, primary_key=True, index=True)
    sender_id = Column(String, nullable=False, index=True)
    sender_username = Column(String, nullable=False)
    sender_name = Column(String, nullable=True)
    receiver_id = Column(String, nullable=True, index=True)  # null for group messages
    message = Column(String, nullable=False)
    message_type = Column(String, default="text")  # text, image, file
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class ChatRoom(Base):
    __tablename__ = "chat_rooms"
    
    id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    room_type = Column(String, default="group")  # group, direct
    created_by = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    is_active = Column(Boolean, default=True)

class ChatRoomMember(Base):
    __tablename__ = "chat_room_members"
    
    id = Column(String, primary_key=True, index=True)
    room_id = Column(String, nullable=False, index=True)
    user_id = Column(String, nullable=False, index=True)
    username = Column(String, nullable=False)
    joined_at = Column(DateTime, default=datetime.utcnow)
    unread_count = Column(Integer, default=0)

# Pydantic Schemas
class MessageCreate(BaseModel):
    receiver_id: Optional[str] = None
    message: str
    message_type: str = "text"

class MessageResponse(BaseModel):
    id: str
    sender_id: str
    sender_username: str
    sender_name: Optional[str]
    receiver_id: Optional[str]
    message: str
    message_type: str
    is_read: bool
    created_at: datetime
    
    class Config:
        from_attributes = True

class ChatRoomCreate(BaseModel):
    name: str
    description: Optional[str] = None
    room_type: str = "group"

class ChatRoomResponse(BaseModel):
    id: str
    name: str
    description: Optional[str]
    room_type: str
    created_by: str
    created_at: datetime
    is_active: bool
    
    class Config:
        from_attributes = True

class RoomMemberResponse(BaseModel):
    id: str
    room_id: str
    user_id: str
    username: str
    joined_at: datetime
    unread_count: int
    
    class Config:
        from_attributes = True
