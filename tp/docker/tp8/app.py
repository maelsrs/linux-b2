from flask import Flask, Response
import os
import redis

REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))
REDIS_KEY = os.environ.get("REDIS_KEY", "visits")

r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)

app = Flask(__name__)

@app.get("/health")
def health():
    try:
        r.ping()
        return {"status": "ok"}, 200
    except Exception as e:
        return {"status": "error", "detail": str(e)}, 500

@app.get("/")
def index():
    hostname = os.environ.get("HOSTNAME", "unknown")
    count = r.incr(REDIS_KEY)
    return Response(f"visits={count} | hostname={hostname}\n", mimetype="text/plain")
