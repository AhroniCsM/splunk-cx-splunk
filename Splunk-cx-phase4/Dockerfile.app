# Simple Python application - writes logs to file only
FROM python:3.9-slim

WORKDIR /app

# Copy application
COPY app_phase4.py /app/app.py

# Make executable
RUN chmod +x /app/app.py

# Run the application
CMD ["python", "-u", "/app/app.py"]

