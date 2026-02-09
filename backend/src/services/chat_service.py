from sqlalchemy.orm import Session
from src.models.chat import ChatMessage, ChatRoom, ChatRoomMember, MessageCreate, ChatRoomCreate
from src.models.user import User
from typing import List, Optional
import uuid
from datetime import datetime

class ChatService:
    @staticmethod
    def send_message(db: Session, sender_id: str, sender_username: str, sender_name: str, message: MessageCreate) -> ChatMessage:
        """Send a new message"""
        db_message = ChatMessage(
            id=str(uuid.uuid4()),
            sender_id=sender_id,
            sender_username=sender_username,
            sender_name=sender_name,
            receiver_id=message.receiver_id,
            message=message.message,
            message_type=message.message_type,
        )
        db.add(db_message)
        db.commit()
        db.refresh(db_message)
        return db_message
    
    @staticmethod
    def get_messages(db: Session, user_id: str, other_user_id: Optional[str] = None, limit: int = 100) -> List[ChatMessage]:
        """Get messages for a user"""
        query = db.query(ChatMessage)
        
        if other_user_id:
            # Direct messages between two users
            query = query.filter(
                ((ChatMessage.sender_id == user_id) & (ChatMessage.receiver_id == other_user_id)) |
                ((ChatMessage.sender_id == other_user_id) & (ChatMessage.receiver_id == user_id))
            )
        else:
            # All messages for user
            query = query.filter(
                (ChatMessage.sender_id == user_id) | (ChatMessage.receiver_id == user_id)
            )
        
        return query.order_by(ChatMessage.created_at.desc()).limit(limit).all()
    
    @staticmethod
    def get_conversations(db: Session, user_id: str):
        """Get list of conversations for a user"""
        # Get unique users this user has messaged with
        sent = db.query(ChatMessage.receiver_id).filter(
            ChatMessage.sender_id == user_id,
            ChatMessage.receiver_id.isnot(None)
        ).distinct().all()
        
        received = db.query(ChatMessage.sender_id).filter(
            ChatMessage.receiver_id == user_id
        ).distinct().all()
        
        user_ids = set([s[0] for s in sent] + [r[0] for r in received])
        
        conversations = []
        for other_user_id in user_ids:
            if other_user_id:
                # Get last message
                last_msg = db.query(ChatMessage).filter(
                    ((ChatMessage.sender_id == user_id) & (ChatMessage.receiver_id == other_user_id)) |
                    ((ChatMessage.sender_id == other_user_id) & (ChatMessage.receiver_id == user_id))
                ).order_by(ChatMessage.created_at.desc()).first()
                
                # Get unread count
                unread = db.query(ChatMessage).filter(
                    ChatMessage.sender_id == other_user_id,
                    ChatMessage.receiver_id == user_id,
                    ChatMessage.is_read == False
                ).count()
                
                # Get the other user's info
                other_user = db.query(User).filter(User.id == other_user_id).first()
                
                if last_msg and other_user:
                    conversations.append({
                        "user_id": other_user_id,
                        "username": other_user.username,
                        "full_name": other_user.full_name,
                        "last_message": last_msg.message,
                        "last_message_time": last_msg.created_at,
                        "unread_count": unread,
                        "is_online": False  # Can be enhanced with real-time status
                    })
        
        return sorted(conversations, key=lambda x: x['last_message_time'], reverse=True)
    
    @staticmethod
    def mark_as_read(db: Session, user_id: str, sender_id: str):
        """Mark messages as read"""
        db.query(ChatMessage).filter(
            ChatMessage.sender_id == sender_id,
            ChatMessage.receiver_id == user_id,
            ChatMessage.is_read == False
        ).update({"is_read": True})
        db.commit()
    
    @staticmethod
    def create_room(db: Session, user_id: str, room: ChatRoomCreate) -> ChatRoom:
        """Create a chat room"""
        db_room = ChatRoom(
            id=str(uuid.uuid4()),
            name=room.name,
            description=room.description,
            room_type=room.room_type,
            created_by=user_id,
        )
        db.add(db_room)
        db.commit()
        db.refresh(db_room)
        return db_room
    
    @staticmethod
    def get_rooms(db: Session, user_id: str) -> List[ChatRoom]:
        """Get all chat rooms for a user"""
        # Get rooms where user is a member
        member_rooms = db.query(ChatRoomMember.room_id).filter(
            ChatRoomMember.user_id == user_id
        ).all()
        
        room_ids = [r[0] for r in member_rooms]
        return db.query(ChatRoom).filter(ChatRoom.id.in_(room_ids)).all()
    
    @staticmethod
    def join_room(db: Session, room_id: str, user_id: str, username: str):
        """Join a chat room"""
        member = ChatRoomMember(
            id=str(uuid.uuid4()),
            room_id=room_id,
            user_id=user_id,
            username=username,
        )
        db.add(member)
        db.commit()
        return member
    
