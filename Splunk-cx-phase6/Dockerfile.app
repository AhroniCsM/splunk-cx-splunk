FROM python:3.9-slim

WORKDIR /app

COPY app_phase6.py /app/app.py

RUN chmod +x /app/app.py

CMD ["python", "-u", "/app/app.py"]

