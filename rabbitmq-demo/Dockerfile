FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN pip install pika requests

# Copy code
COPY producer.py consumer.py ./

# Default: run consumer (worker)
CMD ["python", "consumer.py"]
