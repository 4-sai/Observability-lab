
FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir flask==3.0.3 prometheus-client==0.20.0
COPY app.py .
EXPOSE 5000
CMD ["python", "app.py"]
