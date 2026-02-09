from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from config import Config
from .database import *

def polygone():
    app = FastAPI(
        title=Config.API_TITLE,
        version=Config.API_VERSION,
        description=Config.API_DESCRIPTION
    )
    
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    init_db()
    
    # IMPORTANT: Register both routers
    
    @app.get("/")
    async def root():
        return {
            "message": "Welcome to Polygone API",
            "version": Config.API_VERSION,
            "docs": "/docs"
        }
    
    return app