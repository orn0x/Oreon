from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os
from src.routes.chat import router as chat_router
from config import Config
from src.database import init_db

# IMPORT LOGIC:
# We import both the Authentication router and the User search router 
# from your auth.py file using explicit naming.
from src.routes.auth import router as auth_router, user_router
from src.routes.api import router as api_router

def create_app() -> FastAPI:
    """
    Initializes and configures the FastAPI application.
    """
    app = FastAPI(
        title=Config.API_TITLE,
        version=Config.API_VERSION,
        description=Config.API_DESCRIPTION
    )
    
    # --- Middleware Configuration ---
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"], # For production, replace with specific domains
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(chat_router, prefix="/api/v1")
    
    # --- Database Initialization ---
    init_db()
    
    # --- Static Files Management ---
    # Ensure the upload directory exists
    if not os.path.exists("uploads"):
        os.makedirs("uploads")
    app.mount("/api/uploads", StaticFiles(directory="uploads"), name="uploads")

    # --- Router Registration ---
    # The order of registration doesn't matter, but the prefixes do.
    
    # Resulting path: /api/v1/auth/login, /api/v1/auth/register
    app.include_router(auth_router, prefix="/api/v1")  
    
    # Resulting path: /api/v1/users/search
    app.include_router(user_router, prefix="/api/v1")  
    
    # Resulting path: /api/v1/ livestock or other business logic
    app.include_router(api_router, prefix="/api/v1")

    # --- Root Endpoint ---
    @app.get("/", tags=["Root"])
    async def root():
        return {
            "status": "online",
            "message": "Welcome to Livestock Management System API",
            "version": Config.API_VERSION,
            "docs": "/docs",
            "redoc": "/redoc"
        }
    
    return app

# Instantiate the app for Uvicorn
app = create_app()