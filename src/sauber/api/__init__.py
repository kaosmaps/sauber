from fastapi import FastAPI

from .services import MainService

app = FastAPI()

@app.get("/")
def root():
    service = MainService()
    return {"message": service.main_function()}
