FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Dépendances minimales
RUN pip install --no-cache-dir flask redis gunicorn

# Créer un utilisateur non-root
RUN useradd -m -u 10001 appuser

COPY app.py /app/app.py
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 5000

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5000", "app:app"]
