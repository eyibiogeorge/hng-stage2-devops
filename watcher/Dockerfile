# Use a lightweight Python base image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install jq and curl for Slack notifications
RUN apt-get update && \
    apt-get install -y --no-install-recommends jq curl && \
    rm -rf /var/lib/apt/lists/*

# Copy dependency file first (for better caching)
COPY requirements.txt .

# Install Python dependencies (none for now, but safe to include)
RUN pip install --no-cache-dir -r requirements.txt

# Copy the watcher script
COPY watcher.py .

# Set environment variables (optional defaults)
ENV PYTHONUNBUFFERED=1

# Run the watcher script
CMD ["python", "watcher.py"]