FROM python:3.10-slim

# Install system dependencies needed to build prophet and related libs
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    g++ \
    gcc \
    git \
    libgomp1 \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# copy requirements and install
COPY requirements.txt /app/requirements.txt
RUN pip install --upgrade pip setuptools wheel
RUN pip install -r /app/requirements.txt

# copy app
COPY . /app

EXPOSE 8000

CMD ["uvicorn", "app_main:app", "--host", "0.0.0.0", "--port", "8000"]
