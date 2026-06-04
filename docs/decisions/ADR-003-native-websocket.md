# ADR-003: Native WebSocket over Socket.IO

**Date:** 2026-06-03  
**Status:** Accepted

## Context

The MAANAS backend uses `python-socketio`, which wraps WebSocket with the Socket.IO protocol (Engine.IO handshake, event framing, namespace negotiation). The initial iOS implementation manually reproduced this framing over `URLSessionWebSocketTask`, which is fragile — it relies on undocumented wire-format behaviour that could break silently across Socket.IO version bumps.

Three options were considered:

| Option | iOS | Backend change |
|--------|-----|----------------|
| Keep hand-rolled Socket.IO | Fragile protocol impl | None |
| Add `SocketIO-Client-Swift` via SPM | Proper client, third-party dep | None |
| Native WebSocket (both sides) | `URLSessionWebSocketTask` — first-class iOS API | Add `/ws/telemetry` endpoint to FastAPI |

## Decision

Switch to **native WebSocket on both sides**:

- **iOS:** `URLSessionWebSocketTask` with plain JSON payloads. No third-party dependency.
- **Backend:** Add a `@app.websocket("/ws/telemetry")` FastAPI endpoint alongside the existing Socket.IO server. JWT passed as a query parameter (`?token=<jwt>`) to work within WebSocket's limited header support.

The existing Socket.IO server and React/MaanasWatch clients are **unchanged** — the new endpoint is additive.

## Backend implementation (for Kinshuk)

Add to `app.py`:

```python
from fastapi import WebSocket, WebSocketDisconnect, Query
from jose import jwt, JWTError  # or your existing JWT lib

@app.websocket("/ws/telemetry")
async def telemetry_ws(websocket: WebSocket, token: str = Query(...)):
    # Verify JWT
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("sub")
    except JWTError:
        await websocket.close(code=1008)
        return

    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_json()
            event = data.get("event")
            if event == "telemetry_update":
                # hand off to existing MAANAS engine
                pass
            elif event == "risk_event":
                pass
            await websocket.send_json({"status": "ok", "event": event})
    except WebSocketDisconnect:
        pass
```

## Rationale

1. **No third-party dependency** — `URLSessionWebSocketTask` is native iOS 13+.
2. **Protocol stability** — raw JSON over WebSocket has no hidden framing contract.
3. **Easier debugging** — frames are human-readable JSON; no Engine.IO decode step.
4. **TLS + cert pinning** — already implemented in `URLSessionDelegate`; works identically.
5. **Additive backend change** — existing Socket.IO clients unaffected.

## Tradeoffs

- Loses Socket.IO features (rooms, broadcast, auto-reconnect) — none of which MANAS currently uses.
- Requires Kinshuk to merge the new endpoint before live telemetry works in production.

## Consequence

`BackendService.swift` connects to `<base_url>/ws/telemetry?token=<jwt>` and exchanges plain JSON objects. All Socket.IO framing code removed.
