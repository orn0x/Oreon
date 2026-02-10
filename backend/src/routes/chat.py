from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from src.database import get_db
from src.auth.dependecies import get_current_active_user
from src.models.user import User
from src.models.chat import MessageCreate, MessageResponse, ChatRoomCreate, ChatRoomResponse
from src.services.chat_service import ChatService
from typing import List, Optional
import json

router = APIRouter(prefix="/chat", tags=["Chat"])

# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: dict = {}
    
    async def connect(self, user_id: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[user_id] = websocket
    
    def disconnect(self, user_id: str):
        if user_id in self.active_connections:
            del self.active_connections[user_id]
    
    async def send_personal_message(self, message: str, user_id: str):
        if user_id in self.active_connections:
            await self.active_connections[user_id].send_text(message)

manager = ConnectionManager()

@router.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    await manager.connect(user_id, websocket)
    try:
        while True:
            data = await websocket.receive_text()
            # Broadcast message to recipient
            message_data = json.loads(data)
            if 'receiver_id' in message_data:
                await manager.send_personal_message(data, message_data['receiver_id'])
    except WebSocketDisconnect:
        manager.disconnect(user_id)

@router.post("/messages", response_model=MessageResponse)
async def send_message(
    message: MessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Send a message"""
    msg = ChatService.send_message(
        db,
        current_user.id,
        current_user.username,
        current_user.full_name or current_user.username,
        message
    )
    
    # Notify via WebSocket
    if message.receiver_id:
        await manager.send_personal_message(
            json.dumps({
                "id": msg.id,
                "sender_id": msg.sender_id,
                "sender_username": msg.sender_username,
                "message": msg.message,
                "created_at": msg.created_at.isoformat()
            }),
            message.receiver_id
        )
    
    return msg

@router.get("/messages", response_model=List[MessageResponse])
async def get_messages(
    other_user_id: Optional[str] = None,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get messages"""
    return ChatService.get_messages(db, current_user.id, other_user_id, limit)

@router.get("/conversations")
async def get_conversations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get all conversations"""
    return ChatService.get_conversations(db, current_user.id)

@router.put("/messages/read/{sender_id}")
async def mark_messages_as_read(
    sender_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Mark messages as read"""
    ChatService.mark_as_read(db, current_user.id, sender_id)
    return {"message": "Messages marked as read"}

@router.post("/rooms", response_model=ChatRoomResponse)
async def create_room(
    room: ChatRoomCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Create a chat room"""
    return ChatService.create_room(db, current_user.id, room)

@router.get("/rooms", response_model=List[ChatRoomResponse])
async def get_rooms(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get all chat rooms"""
    return ChatService.get_rooms(db, current_user.id)

@router.post("/rooms/{room_id}/join")
async def join_room(
    room_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Join a chat room"""
    ChatService.join_room(db, room_id, current_user.id, current_user.username)
    return {"message": "Joined room successfully"}
