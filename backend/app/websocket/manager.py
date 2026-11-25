import asyncio
import json

from fastapi import WebSocket, WebSocketDisconnect


class ConnectionManager:
    def __init__(self) -> None:
        self._connections: set[WebSocket] = set()
        self._lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            self._connections.add(websocket)

    async def disconnect(self, websocket: WebSocket) -> None:
        async with self._lock:
            self._connections.discard(websocket)

    async def broadcast(self, message: dict[str, object]) -> None:
        payload = json.dumps(message, separators=(",", ":"))
        async with self._lock:
            clients = list(self._connections)
        disconnected: list[WebSocket] = []
        for client in clients:
            try:
                await client.send_text(payload)
            except (WebSocketDisconnect, OSError, RuntimeError):
                disconnected.append(client)
        for client in disconnected:
            await self.disconnect(client)
