import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    # Database
    DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./db/polygonedb.db")
    
    # API Settings
    API_TITLE = "Polygone App API"
    API_VERSION = "1.0.0"
    API_DESCRIPTION = "Complete API for Polygone App with Authentication"
    
    # Security & JWT
    SECRET_KEY = os.getenv("SECRET_KEY", "*THt![\^WBHzd'X2xCq2+x{Qh%T474`P;T[hnqf?:X2=2s?%D8")
    ALGORITHM = os.getenv("ALGORITHM", "HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 30))
    
    # App Settings
    DEBUG = os.getenv("DEBUG", "True") == "True"
    HOST = os.getenv("HOST", "0.0.0.0")
    PORT = int(os.getenv("PORT", 8000))