"""Notes API: the middle tier of the landing zone demo app."""
import os
from pathlib import Path

from fastapi import FastAPI
from pydantic import BaseModel, Field

app = FastAPI(title="notes-api", docs_url=None, redoc_url=None)  # no public API docs in production

# In AKS, the Secrets Store CSI driver mounts this file from Key Vault; locally it does not exist
GREETING_FILE = Path(os.getenv("APP_GREETING_FILE", "/mnt/secrets/app-greeting"))

_notes: list[dict] = []


class Note(BaseModel):
    text: str = Field(min_length=1, max_length=280)


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.get("/api/greeting")
def greeting() -> dict:
    source = "key-vault" if GREETING_FILE.is_file() else "local-default"
    text = GREETING_FILE.read_text(encoding="utf-8").strip() if GREETING_FILE.is_file() else "Hello from local development"
    return {"greeting": text, "source": source}


@app.get("/api/notes")
def list_notes() -> list[dict]:
    return _notes


@app.post("/api/notes", status_code=201)
def add_note(note: Note) -> dict:
    item = {"id": len(_notes) + 1, "text": note.text}
    _notes.append(item)
    return item