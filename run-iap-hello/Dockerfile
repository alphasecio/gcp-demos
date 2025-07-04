# Use an official Python runtime as a parent image
FROM python:3.12-slim

# Set the working directory in the container
WORKDIR /app

# Copy requirements.txt before installing dependencies
COPY requirements.txt .

# Install any production dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY auth.py .
COPY main.py .

# Create templates directory and copy HTML template
RUN mkdir -p templates
COPY templates/index.html templates/

# Set Python path to include the current directory
ENV PYTHONPATH=/

# Run the web service on container startup
CMD ["gunicorn", "--bind", ":8080", "--workers", "1", "--threads", "8", "--timeout", "0", "main:app"]
