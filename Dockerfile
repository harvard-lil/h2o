# Stage 1: Base build stage
FROM registry.lil.tools/library/python:3.11-bookworm AS builder

# Create the app directory
RUN mkdir /app

# Set the working directory
WORKDIR /app

# Set environment variables to optimize Python
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Upgrade pip and install dependencies
RUN pip install --upgrade pip

# Copy the requirements file first (better caching)
COPY web/requirements.txt /app/

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Production stage
FROM registry.lil.tools/library/python:3.11-bookworm

# Install dependencies to build uWSGI
RUN apt-get update && apt-get install -y \
    build-essential \
    libpcre3 \
    libpcre3-dev \
    && pip install uwsgi

# Create a non-root user and set up permissions
RUN useradd -m -r h2o && \
    mkdir /app && \
    chown -R h2o /app

# Copy the Python dependencies from the builder stage
COPY --from=builder /usr/local/lib/python3.11/site-packages/ /usr/local/lib/python3.11/site-packages/
COPY --from=builder /usr/local/bin/ /usr/local/bin/

# Set the working directory
WORKDIR /app

# Copy the application code
COPY --chown=h2o:h2o web/ .

# Add settings.pyAdd commentMore actions
RUN echo "from .settings_prod import *\n" > /app/config/settings/settings.py && \
   chown h2o:h2o /app/config/settings/settings.py

# Set environment variables to optimize Python
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Switch to non-root user
USER h2o

# Expose the application port
EXPOSE 8000

# Start the application with uwsgi
CMD ["uwsgi", "--http", "0.0.0.0:8000", "--master", "--processes", "20", "--threads", "1", "--plugins", "python311,logfile", "--buffer-size", "32768", "--module", "config.wsgi"]