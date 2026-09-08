"""
FastAPI service that loads the fine-tuned bert-tiny scam-classifier and exposes
a single POST endpoint that takes an SMS message in JSON and returns whether it's
a scam, in JSON.

Run locally:
    uvicorn main:app --host 0.0.0.0 --port 8000

Then:
    curl -X POST http://localhost:8000/predict \
      -H "Content-Type: application/json" \
      -d '{"message": "Naomba unitumie hela kwenye namba hii ya Airtel 0689933027"}'
"""

import os
from contextlib import asynccontextmanager

import torch
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from transformers import BertForSequenceClassification, BertTokenizer

# Path to the folder produced by trainer.save_model() / tokenizer.save_pretrained()
# in the training notebook. Update this if you deploy the model somewhere else,
# or point it at an env var so it's configurable without a code change.
MODEL_DIR = os.environ.get("MODEL_DIR", "./final_model")

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# Model + tokenizer are loaded once at startup and kept in memory, not reloaded
# per-request.
model_state = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    model_state["tokenizer"] = BertTokenizer.from_pretrained(MODEL_DIR)
    model_state["model"] = BertForSequenceClassification.from_pretrained(MODEL_DIR)
    model_state["model"].to(DEVICE)
    model_state["model"].eval()
    yield
    model_state.clear()


app = FastAPI(
    title="Bongo Scam Detector",
    description="Classifies Swahili SMS messages as scam or trust using a fine-tuned bert-tiny model.",
    version="1.0.0",
    lifespan=lifespan,
)


class PredictRequest(BaseModel):
    message: str = Field(..., min_length=1, description="The SMS message text to classify")


class PredictResponse(BaseModel):
    message: str
    label: str          # "scam" or "trust"
    is_scam: bool
    confidence: float   # probability of the predicted label, 0-1


@app.get("/health")
def health():
    return {"status": "ok", "device": DEVICE}


@app.post("/predict", response_model=PredictResponse)
def predict(payload: PredictRequest):
    text = payload.message.strip()
    if not text:
        raise HTTPException(status_code=422, detail="message must not be empty")

    tokenizer = model_state["tokenizer"]
    model = model_state["model"]

    inputs = tokenizer(
        text,
        truncation=True,
        padding=True,
        max_length=128,
        return_tensors="pt",
    ).to(DEVICE)

    with torch.no_grad():
        logits = model(**inputs).logits
        probs = torch.softmax(logits, dim=-1).squeeze(0)

    pred_id = int(torch.argmax(probs).item())
    label = model.config.id2label[pred_id]
    confidence = float(probs[pred_id].item())

    return PredictResponse(
        message=payload.message,
        label=label,
        is_scam=(label == "scam"),
        confidence=round(confidence, 4),
    )
