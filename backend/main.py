from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uuid

app = FastAPI()

# Разрешаем запросы со всех доменов (включая фронтенд), т.к. Nginx не используем
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Временное хранилище в памяти
TASKS_DB = {}

class Task(BaseModel):
    id: str
    title: str
    urgent: bool
    important: bool

@app.get("/tasks")
def get_tasks():
    return list(TASKS_DB.values())

@app.post("/tasks")
def add_task(title: str, urgent: bool, important: bool):
    task_id = str(uuid.uuid4())
    new_task = Task(
        id=task_id,
        title=title,
        urgent=urgent,
        important=important
    )
    TASKS_DB[task_id] = new_task.dict()
    return {"status": "success", "task": new_task}

@app.delete("/tasks/{task_id}")
def delete_task(task_id: str):
    if task_id not in TASKS_DB:
        raise HTTPException(status_code=404, detail="Task not found")
    TASKS_DB.pop(task_id)
    return {"status": "deleted"}
