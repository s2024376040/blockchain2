import os
import shutil
import subprocess
import sys
import threading
import webbrowser
from contextlib import asynccontextmanager
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

if __package__ in (None, ""):
    backend_directory = Path(__file__).resolve().parent.parent
    sys.path.insert(0, str(backend_directory))
    os.chdir(backend_directory)

from app.api import admin, audit, auth, blockchain, trading
from app.core.config import settings
from app.core.security import decode_access_token
from app.database.session import Base, SessionLocal, engine
from app.models import Block, User
from app.services.ledger import load_chain, persist_block
from app.websocket.manager import ConnectionManager

def initialize_database() -> None:
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        if db.get(Block, 0) is None:
            genesis = load_chain(db).blocks[0]
            persist_block(db, genesis)
            db.commit()


@asynccontextmanager
async def lifespan(_: FastAPI):
    initialize_database()
    yield


app = FastAPI(
    title="BTC Trading Simulator & Blockchain Audit API",
    description="A virtual trading and educational blockchain audit system; it is not the Bitcoin network.",
    version="1.0.0",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.state.connection_manager = ConnectionManager()
app.state.rate_limit_attempts = {}
app.include_router(auth.router)
app.include_router(trading.router)
app.include_router(blockchain.router)
app.include_router(audit.router)
app.include_router(admin.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "mode": "simulated"}


@app.get("/", include_in_schema=False)
def root() -> RedirectResponse:
    return RedirectResponse(url="/docs")


@app.websocket("/ws/blockchain")
async def blockchain_socket(websocket: WebSocket, token: str = "") -> None:
    subject = decode_access_token(token)
    if subject is None:
        await websocket.close(code=1008, reason="Authentication required.")
        return
    with SessionLocal() as db:
        if db.get(User, subject) is None:
            await websocket.close(code=1008, reason="Invalid user.")
            return
    manager: ConnectionManager = app.state.connection_manager
    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        await manager.disconnect(websocket)


def _open_frontend_in_browser() -> None:
    url = "http://localhost:5173"
    chrome_candidates = [
        shutil.which("chrome"),
        shutil.which("chrome.exe"),
        *(
            str(Path(os.environ[variable]) / "Google" / "Chrome" / "Application" / "chrome.exe")
            for variable in ("PROGRAMFILES", "PROGRAMFILES(X86)", "LOCALAPPDATA")
            if os.environ.get(variable)
        ),
    ]
    chrome_path = next(
        (candidate for candidate in chrome_candidates if candidate and Path(candidate).is_file()),
        None,
    )
    if chrome_path:
        subprocess.Popen([chrome_path, url])
    elif not webbrowser.open(url):
        print(f"Could not open a browser automatically. Open {url}")


def _start_frontend() -> subprocess.Popen[bytes] | None:
    project_directory = Path(__file__).resolve().parents[2]
    web_directory = project_directory / "web"
    try:
        with urlopen("http://127.0.0.1:5173", timeout=1) as response:
            if b'<div id="root">' in response.read():
                print("Web frontend is already running at http://localhost:5173")
                return None
            raise RuntimeError(
                "Port 5173 is already serving another application; stop it and try again."
            )
    except URLError:
        pass

    npm_command = shutil.which("npm.cmd")
    if npm_command is None:
        raise RuntimeError("Node.js and npm are required to start the web frontend.")
    if not (web_directory / "node_modules" / ".bin" / "vite.cmd").is_file():
        raise RuntimeError(
            f"Web dependencies are missing. Run 'npm install' in {web_directory} first."
        )

    command = f'"{npm_command}" run dev -- --host 127.0.0.1 --port 5173 --strictPort'
    return subprocess.Popen(
        [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/s", "/c", command],
        cwd=web_directory,
    )


if __name__ == "__main__":
    import uvicorn

    _start_frontend()
    threading.Timer(3, _open_frontend_in_browser).start()
    uvicorn.run(app, host="127.0.0.1", port=8000)
