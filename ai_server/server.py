"""Optional Laya decision bridge for Emergent.

The Godot game remains playable while the checkpoint downloads or the server is off.
"""

from __future__ import annotations

from contextlib import asynccontextmanager
from threading import Lock
from typing import Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel


ARI_QUESTIONS = {
    "next_action": {
        "type": "choice",
        "instructions": "Choose Ari's next helpful action in a survival exploration game. Avoid needless danger, gather supplies when useful, help the player, and seek signal shards when safe.",
        "criteria": {
            "hide": "Retreat from a nearby wolf when weak or outnumbered",
            "gather": "Collect a nearby food bush to add a healing supply",
            "explore": "Move toward an unfound signal shard and guide the player",
            "defend": "Fight a nearby wolf when healthy and the player needs help",
            "return": "Go to the campfire to recover or regroup",
        },
    }
}

WOLF_QUESTIONS = {
    "next_action": {
        "type": "choice",
        "instructions": "Choose the wolf pack's next stance in a survival game. Hunger favors hunting, fear, wounds, or an active camp ward favor retreat, a nearby unknown threat can be watched, and distant prey can be ignored.",
        "criteria": {
            "hunt": "Chase nearby prey and attack when hungry, confident, or favored by darkness",
            "observe": "Stalk prey at a distance without attacking while assessing danger",
            "retreat": "Withdraw to the den when frightened, wounded, or outmatched",
            "roam": "Wander near the den when no prey is nearby and there is no immediate threat",
        },
    }
}

router: Any = None
inference_lock = Lock()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    global router
    from laya import Router

    # Only one checkpoint is loaded on demand. First download may take time.
    router = Router(max_loaded=1)
    yield


app = FastAPI(title="Emergent Laya bridge", lifespan=lifespan)


class DecisionRequest(BaseModel):
    state: dict[str, Any]
    agent: str = "ari"


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ready"}


@app.post("/decide")
def decide(request: DecisionRequest) -> dict[str, Any]:
    if router is None:
        raise HTTPException(503, "Model is not ready")
    if request.agent not in ("ari", "wolf"):
        raise HTTPException(400, "Unknown agent")
    try:
        questions = WOLF_QUESTIONS if request.agent == "wolf" else ARI_QUESTIONS
        with inference_lock:
            result = router.predict(request.state, questions, model="typed-decisions")
        answer = result["answers"]["next_action"]
        return {
            "action": answer["choice"],
            "probabilities": answer.get("probabilities", {}),
            "model": "typed-decisions",
        }
    except Exception as exc:
        raise HTTPException(503, f"Laya inference unavailable: {exc}") from exc
