FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y apache2-utils && rm -rf /var/lib/apt/lists/*

COPY . .

RUN python make-data.py

CMD ["bash", "generate-votes.sh"]
