from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="multi-cloud-devsecops-sample")

class Item(BaseModel):
    id: int
    name: str

@app.get("/", tags=["root"])
async def read_root():
    return {"status": "ok", "message": "Hello from Multi-Cloud DevSecOps sample"}

@app.get("/health", tags=["health"])
async def health_check():
    return {"status": "healthy"}

@app.get("/metrics", tags=["metrics"])
async def metrics():
    # In production, use prometheus_client
    return {"requests_total": 0, "errors_total": 0}

@app.get("/items/{item_id}", response_model=Item)
async def read_item(item_id: int):
    return Item(id=item_id, name=f"item-{item_id}")

@app.post("/items", response_model=Item)
async def create_item(item: Item):
    # in real app you'd persist; this is a stub
    return item
