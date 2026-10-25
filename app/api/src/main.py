"""Notes API: the middle tier of the landing zone demo app."""
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI
from pydantic import BaseModel, Field

app = FastAPI(title="notes-api", docs_url=None, redoc_url=None)  # no public API docs in production

# In AKS, the Secrets Store CSI driver mounts this file from Key Vault; locally it does not exist
GREETING_FILE = Path(os.getenv("APP_GREETING_FILE", "/mnt/secrets/app-greeting"))

# In AKS, notes live in Azure Table Storage, reached with workload identity; locally they stay in memory
TABLE_ENDPOINT = os.getenv("AZURE_TABLE_ENDPOINT")
PARTITION = "notes"
MAX_NOTES = 100

_notes: list[dict] = []
_table = None
if TABLE_ENDPOINT:
    from azure.data.tables import TableClient
    from azure.identity import WorkloadIdentityCredential

    # Only the federated token AKS projects into the pod is accepted: no fallback to keys, secrets or the CLI
    _table = TableClient(
        endpoint=TABLE_ENDPOINT,
        table_name=os.getenv("AZURE_TABLE_NAME", "notes"),
        credential=WorkloadIdentityCredential(),
    )


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
    if _table is None:
        return _notes[-MAX_NOTES:]
    # Parameterized filter: user input is never concatenated into the query
    rows = _table.query_entities("PartitionKey eq @pk", parameters={"pk": PARTITION}, select=["RowKey", "text", "created"])
    notes = sorted(rows, key=lambda r: r["created"])[-MAX_NOTES:]
    return [{"id": r["RowKey"], "text": r["text"]} for r in notes]


@app.post("/api/notes", status_code=201)
def add_note(note: Note) -> dict:
    item = {"id": uuid.uuid4().hex, "text": note.text}
    if _table is None:
        _notes.append(item)
    else:
        _table.create_entity({
            "PartitionKey": PARTITION,
            "RowKey": item["id"],
            "text": note.text,
            "created": datetime.now(timezone.utc).isoformat(),
        })
    return item