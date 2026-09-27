#!/bin/bash
set -euxo pipefail

# --- Install Docker (Amazon Linux 2) ---
yum update -y
amazon-linux-extras install docker -y
systemctl enable docker
systemctl start docker
usermod -a -G docker ec2-user

# --- Lay down the application ---
mkdir -p /opt/app
cat > /opt/app/app.py <<'PYEOF'
import random
from flask import Flask, jsonify

app = Flask(__name__)

STRINGS = ["Investments", "Smallcase", "Stocks", "buy-the-dip", "TickerTape"]


@app.route("/api/v1", methods=["GET"])
def get_random_string():
    return jsonify({"value": random.choice(STRINGS)})


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081)
PYEOF

cat > /opt/app/requirements.txt <<'REQEOF'
Flask==3.0.3
REQEOF

cat > /opt/app/Dockerfile <<'DOCKEREOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 8081
CMD ["python", "app.py"]
DOCKEREOF

# --- Build and run the container ---
cd /opt/app
docker build -t random-string-app:latest .
docker run -d \
  --name random-string-app \
  --restart unless-stopped \
  -p 8081:8081 \
  random-string-app:latest