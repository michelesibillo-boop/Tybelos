# Tybelos Circle - Guida Installazione e Verifica

## Requisiti di Sistema

### Sviluppo Locale
```bash
- Node.js >= 18.x
- Python >= 3.10
- PostgreSQL >= 14
- Redis >= 7.0
- Docker & Docker Compose
- Git
```

### Hardware Minimo (Sviluppo)
- CPU: 4 core
- RAM: 16GB
- Storage: 50GB SSD
- GPU: Opzionale (per testing ASR/TTS locale)

### Hardware Produzione (da PERFORMANCE_METRICS.md)
- CPU: 8+ core per pod
- RAM: 16GB+ per pod  
- GPU: A100/H100 per voice processing (10,000+ sessioni concurrent)
- Network: 1Gbps+

---

## Installazione Rapida (Docker)

### 1. Clone del Repository

```bash
# Clone del progetto
git clone https://github.com/tybelos/circle.git
cd circle

# Verifica file di documentazione
ls docs/
# Dovresti vedere: ARCHITECTURE.md, PRD.md, API.md, PERFORMANCE_METRICS.md
```

### 2. Setup con Docker Compose

```bash
# Copia file di configurazione esempio
cp .env.example .env

# Modifica le variabili d'ambiente
nano .env
```

**File `.env` di esempio:**
```bash
# Database
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=tybelos_circle
POSTGRES_USER=tybelos
POSTGRES_PASSWORD=your_secure_password_here

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# JWT
JWT_SECRET=your_jwt_secret_here_min_32_chars
JWT_EXPIRY=900

# API Keys
OPENAI_API_KEY=sk-your-openai-key
ANTHROPIC_API_KEY=your-anthropic-key
ELEVENLABS_API_KEY=your-elevenlabs-key

# Vector Database
PINECONE_API_KEY=your-pinecone-key
PINECONE_ENVIRONMENT=us-east-1-aws

# App Config
ENVIRONMENT=development
API_VERSION=v1
LOG_LEVEL=debug

# Performance Targets (da PERFORMANCE_METRICS.md)
TARGET_RESPONSE_LATENCY_MS=2000
TARGET_ASR_ACCURACY_WER=0.05
TARGET_TTS_QUALITY_MOS=4.2
TARGET_UPTIME_PERCENT=99.9
```

### 3. Avvio Stack Completo

```bash
# Build e avvio di tutti i servizi
docker-compose up -d

# Verifica che tutti i container siano in running
docker-compose ps

# Output atteso:
# NAME                    STATUS              PORTS
# tybelos-api            Up 30 seconds       0.0.0.0:8080->8080/tcp
# tybelos-voice          Up 30 seconds       0.0.0.0:8081->8081/tcp
# tybelos-postgres       Up 30 seconds       5432/tcp
# tybelos-redis          Up 30 seconds       6379/tcp
# tybelos-vector-db      Up 30 seconds       8000/tcp
```

### 4. Inizializzazione Database

```bash
# Esegui migrazioni database
docker-compose exec api python manage.py migrate

# Crea utente admin
docker-compose exec api python manage.py createsuperuser

# Carica dati di esempio
docker-compose exec api python manage.py loaddata fixtures/dev_data.json
```

### 5. Verifica Installazione

```bash
# Test health check
curl http://localhost:8080/health

# Output atteso:
# {
#   "status": "healthy",
#   "version": "1.0.0",
#   "services": {
#     "api": "up",
#     "database": "up",
#     "redis": "up",
#     "vector_db": "up"
#   },
#   "timestamp": "2026-01-30T18:00:00Z"
# }
```

---

## Verifica Funzionale Completa

### Test 1: API REST

```bash
# 1. Registrazione utente
curl -X POST http://localhost:8080/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "SecurePass123!",
    "name": "Test User"
  }'

# 2. Login
curl -X POST http://localhost:8080/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "SecurePass123!"
  }'

# Salva il token dalla risposta
export TOKEN="eyJhbGc..."

# 3. Ottieni profilo utente
curl -X GET http://localhost:8080/v1/users/me \
  -H "Authorization: Bearer $TOKEN"

# 4. Lista sessioni
curl -X GET http://localhost:8080/v1/sessions?limit=10 \
  -H "Authorization: Bearer $TOKEN"

# 5. Lista memories
curl -X GET http://localhost:8080/v1/memories \
  -H "Authorization: Bearer $TOKEN"
```

### Test 2: WebSocket Voice Session

```bash
# Usa wscat per testare WebSocket
npm install -g wscat

# Connetti al voice endpoint
wscat -c "ws://localhost:8081/v1/voice?token=$TOKEN"

# Una volta connesso, invia:
{
  "type": "session.start",
  "session_config": {
    "audio_quality": "high",
    "emotion_detection": true,
    "memory_enabled": true
  }
}

# Dovresti ricevere:
{
  "type": "session.started",
  "session_id": "uuid-here",
  "started_at": "2026-01-30T18:00:00Z"
}
```

### Test 3: Performance Metrics (da PERFORMANCE_METRICS.md)

```bash
# Script di test performance
cat > test_performance.sh << 'EOF'
#!/bin/bash

echo "=== Tybelos Circle - Performance Test ==="
echo ""

# 1. Response Latency (Target: <2s)
echo "Test 1: API Response Latency"
time curl -s http://localhost:8080/v1/users/me \
  -H "Authorization: Bearer $TOKEN" > /dev/null
echo ""

# 2. Concurrent Requests
echo "Test 2: Concurrent Requests (100)"
seq 1 100 | xargs -n1 -P100 curl -s http://localhost:8080/health > /dev/null
echo "✓ 100 richieste completate"
echo ""

# 3. Database Query Time
echo "Test 3: Database Query Performance"
docker-compose exec -T postgres psql -U tybelos -d tybelos_circle -c "
  EXPLAIN ANALYZE 
  SELECT * FROM conversation_sessions 
  ORDER BY started_at DESC 
  LIMIT 10;
"
echo ""

# 4. Redis Performance
echo "Test 4: Redis Cache Performance"
docker-compose exec -T redis redis-cli --latency-history
echo ""

# 5. Memory Retrieval
echo "Test 5: Memory Retrieval (Target: 85%+ relevance)"
curl -s http://localhost:8080/v1/memories?search="presentation anxiety" \
  -H "Authorization: Bearer $TOKEN" | jq '.memories[].importance'
echo ""

echo "=== Test Completati ==="
EOF

chmod +x test_performance.sh
./test_performance.sh
```

### Test 4: Verifica Metriche Target

```bash
# Script per verificare rispetto dei target da PERFORMANCE_METRICS.md
cat > verify_metrics.py << 'EOF'
#!/usr/bin/env python3
import requests
import time
import statistics

TOKEN = "your_token_here"
BASE_URL = "http://localhost:8080"

def test_response_latency():
    """Target: <2s response latency (Critical: >3s)"""
    print("Test: API Response Latency")
    latencies = []
    
    for i in range(10):
        start = time.time()
        r = requests.get(f"{BASE_URL}/v1/users/me", 
                        headers={"Authorization": f"Bearer {TOKEN}"})
        latency = (time.time() - start) * 1000  # ms
        latencies.append(latency)
    
    avg_latency = statistics.mean(latencies)
    p95_latency = statistics.quantiles(latencies, n=20)[18]  # 95th percentile
    
    print(f"  Avg: {avg_latency:.0f}ms")
    print(f"  P95: {p95_latency:.0f}ms")
    print(f"  Target: <200ms (P95)")
    print(f"  Status: {'✓ PASS' if p95_latency < 200 else '✗ FAIL'}")
    print()

def test_concurrent_sessions():
    """Target: 10,000+ concurrent sessions"""
    print("Test: Concurrent Session Support")
    # Questo test richiede load testing tool come Locust
    print("  Use: locust -f locustfile.py --host http://localhost:8080")
    print("  Target: 10,000+ concurrent WebSocket connections")
    print()

def test_uptime():
    """Target: 99.9% uptime"""
    print("Test: Service Uptime")
    r = requests.get(f"{BASE_URL}/health")
    health = r.json()
    
    print(f"  Status: {health['status']}")
    print(f"  Services: {health['services']}")
    print(f"  Target: 99.9% uptime")
    print()

def test_memory_consent():
    """Target: 80%+ memory consent enabled"""
    print("Test: Memory Consent Rate")
    r = requests.get(f"{BASE_URL}/v1/admin/metrics/consent",
                    headers={"Authorization": f"Bearer {TOKEN}"})
    
    if r.status_code == 200:
        data = r.json()
        consent_rate = data.get('consent_enabled_percentage', 0)
        print(f"  Consent Rate: {consent_rate}%")
        print(f"  Target: 80%+")
        print(f"  Status: {'✓ PASS' if consent_rate >= 80 else '✗ FAIL'}")
    else:
        print("  Requires admin access")
    print()

if __name__ == "__main__":
    print("=== Tybelos Circle - Metrics Verification ===\n")
    test_response_latency()
    test_concurrent_sessions()
    test_uptime()
    test_memory_consent()
    print("=== Verification Complete ===")
EOF

chmod +x verify_metrics.py
python3 verify_metrics.py
```

---

## Verifica Componenti Specifici

### Voice Processing Pipeline

```bash
# Test ASR (Automatic Speech Recognition)
# Target: <5% WER, 95%+ accuracy

# 1. Invia file audio di test
curl -X POST http://localhost:8081/v1/voice/transcribe \
  -H "Authorization: Bearer $TOKEN" \
  -F "audio=@test_audio.wav"

# Output atteso:
# {
#   "transcription": "I'm feeling stressed about work",
#   "confidence": 0.94,
#   "wer": 0.03,
#   "processing_time_ms": 450
# }
```

### TTS (Text-to-Speech)

```bash
# Target: 4.2+/5 MOS quality, <1.5s latency

curl -X POST http://localhost:8081/v1/voice/synthesize \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "I understand. Tell me more about what is worrying you.",
    "voice_id": "default",
    "emotion": "calm_supportive"
  }' \
  --output response.mp3

# Verifica file audio generato
file response.mp3
# Output: response.mp3: Audio file with ID3 version 2.4.0

# Misura latenza
time curl -s http://localhost:8081/v1/voice/synthesize \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello", "voice_id": "default"}' \
  > /dev/null
```

### Memory System

```bash
# Test memory retrieval relevance
# Target: 85%+ relevance

curl -X GET "http://localhost:8080/v1/memories?search=work%20stress&top_k=5" \
  -H "Authorization: Bearer $TOKEN" | jq '
  .memories[] | {
    content: .content,
    relevance: .relevance_score,
    category: .category
  }
'

# Verifica che relevance_score sia ≥ 0.85 per i primi risultati
```

### C2C (AI-to-AI Communication)

```bash
# Test C2C request
# Target: 30% adoption, 2x/week usage

# 1. Lista connessioni C2C
curl -X GET http://localhost:8080/v1/c2c/connections \
  -H "Authorization: Bearer $TOKEN"

# 2. Invia C2C request
curl -X POST http://localhost:8080/v1/c2c/send \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "target_circle_id": "circle-uuid-2",
    "request_type": "query",
    "payload": {
      "query": "How is the user doing with their goals?"
    }
  }'

# 3. Verifica rate limiting (60/hour)
for i in {1..65}; do
  curl -s http://localhost:8080/v1/c2c/connections \
    -H "Authorization: Bearer $TOKEN" > /dev/null
done
# La 61a richiesta dovrebbe ritornare 429 Too Many Requests
```

---

## Monitoraggio e Logging

### Visualizza Logs in Tempo Reale

```bash
# Tutti i servizi
docker-compose logs -f

# Solo API
docker-compose logs -f api

# Solo Voice Processing
docker-compose logs -f voice

# Filtra per errori
docker-compose logs | grep ERROR

# Ultimi 100 log entries
docker-compose logs --tail=100
```

### Metriche Prometheus

```bash
# Accedi a Prometheus UI
open http://localhost:9090

# Query esempi:
# - api_response_time_seconds
# - voice_session_duration_seconds  
# - memory_retrieval_relevance_score
# - concurrent_sessions_total
# - asr_word_error_rate
# - tts_quality_mos_score
```

### Grafana Dashboard

```bash
# Accedi a Grafana
open http://localhost:3000
# Default: admin / admin

# Dashboard disponibili:
# - System Overview
# - Voice Performance  
# - Memory Analytics
# - User Engagement
# - Error Tracking
```

---

## Troubleshooting

### Container non si avvia

```bash
# Verifica logs errori
docker-compose logs api | tail -50

# Verifica variabili ambiente
docker-compose exec api env | grep -E "POSTGRES|REDIS|JWT"

# Reset completo
docker-compose down -v
docker-compose up -d --build
```

### Database connection error

```bash
# Verifica PostgreSQL
docker-compose exec postgres pg_isready

# Connetti manualmente
docker-compose exec postgres psql -U tybelos -d tybelos_circle

# Reset database
docker-compose exec postgres psql -U tybelos -c "DROP DATABASE tybelos_circle;"
docker-compose exec postgres psql -U tybelos -c "CREATE DATABASE tybelos_circle;"
docker-compose exec api python manage.py migrate
```

### Redis connection error

```bash
# Test Redis
docker-compose exec redis redis-cli ping
# Output atteso: PONG

# Verifica chiavi
docker-compose exec redis redis-cli KEYS "*"

# Flush cache se necessario
docker-compose exec redis redis-cli FLUSHALL
```

### Performance degradata

```bash
# Verifica risorse
docker stats

# Se CPU/Memory alte, scala i servizi
docker-compose up -d --scale api=3 --scale voice=2

# Verifica latenza rete
docker-compose exec api ping postgres
docker-compose exec api ping redis
```

---

## Testing Automatizzato

### Unit Tests

```bash
# Esegui tutti i test
docker-compose exec api pytest

# Con coverage
docker-compose exec api pytest --cov=src --cov-report=html

# Test specifici
docker-compose exec api pytest tests/test_memory.py
docker-compose exec api pytest tests/test_voice.py -v
```

### Integration Tests

```bash
# Test end-to-end
docker-compose exec api pytest tests/integration/

# Test API endpoints
docker-compose exec api pytest tests/integration/test_api.py

# Test WebSocket
docker-compose exec api pytest tests/integration/test_websocket.py
```

### Load Testing

```bash
# Installa Locust
pip install locust

# Esegui load test
locust -f tests/load/locustfile.py --host http://localhost:8080

# Target da raggiungere:
# - 10,000+ concurrent users
# - <2s average response time
# - <1% error rate
# - 99.9% uptime
```

---

## Deployment Produzione

### Pre-deployment Checklist

```bash
# 1. Verifica metriche target (PERFORMANCE_METRICS.md)
./verify_metrics.py

# 2. Esegui tutti i test
docker-compose exec api pytest

# 3. Verifica security
docker-compose exec api python manage.py check --deploy

# 4. Backup database
docker-compose exec postgres pg_dump -U tybelos tybelos_circle > backup.sql

# 5. Build immagini produzione
docker build -t tybelos/api:latest -f Dockerfile.api .
docker build -t tybelos/voice:latest -f Dockerfile.voice .

# 6. Push a registry
docker push tybelos/api:latest
docker push tybelos/voice:latest
```

### Deploy su Kubernetes

```bash
# Applica manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/deployments/
kubectl apply -f k8s/services/
kubectl apply -f k8s/ingress.yaml

# Verifica deployment
kubectl get pods -n tybelos-production
kubectl get svc -n tybelos-production

# Scale up
kubectl scale deployment api --replicas=10 -n tybelos-production
kubectl scale deployment voice --replicas=5 -n tybelos-production
```

---

## Comandi Utili

```bash
# Stop tutti i servizi
docker-compose stop

# Restart singolo servizio
docker-compose restart api

# Rebuild dopo modifiche codice
docker-compose up -d --build api

# Accedi a container
docker-compose exec api bash
docker-compose exec postgres psql -U tybelos

# Cleanup completo
docker-compose down -v --remove-orphans
docker system prune -a

# Export logs
docker-compose logs > tybelos_logs_$(date +%Y%m%d).txt

# Database backup
docker-compose exec postgres pg_dump -U tybelos tybelos_circle | gzip > backup_$(date +%Y%m%d).sql.gz

# Database restore
gunzip -c backup_20260130.sql.gz | docker-compose exec -T postgres psql -U tybelos tybelos_circle
```

---

## Documentazione Aggiuntiva

- **ARCHITECTURE.md** - Architettura tecnica completa
- **API.md** - Documentazione API WebSocket e REST
- **PRD.md** - Product Requirements Document
- **PERFORMANCE_METRICS.md** - KPI e target di performance

---

## Supporto

Per problemi o domande:
- Email: engineering@tybelos.com
- Docs: https://docs.tybelos.com
- Status: https://status.tybelos.com

**Ultima revisione:** Gennaio 2026
