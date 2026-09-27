from flask import Flask, jsonify
import random

app = Flask(__name__)

VALUES = [
    "Investments",
    "Smallcase",
    "Stocks",
    "buy-the-dip",
    "TickerTape",
]

@app.get("/api/v1")
def random_string():
    return jsonify({"value": random.choice(VALUES)})

@app.get("/health")
def health():
    return jsonify({"status": "ok"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081)