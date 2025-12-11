import uvicorn
from config import Config
from src.services import polygone

app = polygone()

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=Config.HOST,
        port=Config.PORT,
        reload=Config.DEBUG
    )