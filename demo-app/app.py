
"""
demo-app/app.py — Flask app with Prometheus metrics + structured JSON logging
Endpoints: / /health /metrics /api/fast /api/slow /api/error /api/orders
"""
import time, random, threading, logging, json
from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST, REGISTRY

app = Flask(__name__)

class JSONFormatter(logging.Formatter):
    def format(self, record):
        entry = {"time": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
                 "level": record.levelname, "msg": record.getMessage(), "service": "demo-app"}
        for k in ["trace_id", "method", "path", "status", "duration_ms"]:
            if hasattr(record, k): entry[k] = getattr(record, k)
        return json.dumps(entry)

handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logger = logging.getLogger("demo-app")
logger.setLevel(logging.INFO)
logger.addHandler(handler)
logger.propagate = False

# ── Prometheus metrics ────────────────────────────────────────
http_requests_total = Counter('http_requests_total', 'Total HTTP requests',
    ['method', 'endpoint', 'status'])
http_request_duration_seconds = Histogram('http_request_duration_seconds',
    'HTTP request duration', ['method', 'endpoint'],
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0])
http_requests_in_flight = Gauge('http_requests_in_flight', 'In-flight requests')
orders_total = Counter('orders_total', 'Orders placed', ['product', 'region', 'status'])
app_info = Gauge('app_info', 'App info', ['version', 'env'])
app_info.labels(version='1.0.0', env='lab').set(1)
queue_depth = Gauge('orders_queue_depth', 'Order queue depth')

@app.before_request
def before_request():
    request.start_time = time.time()
    request.trace_id   = request.headers.get('X-Trace-ID', '%016x' % random.getrandbits(64))
    http_requests_in_flight.inc()

@app.after_request
def after_request(response):
    dur = (time.time() - request.start_time) * 1000
    ep  = request.endpoint or 'unknown'
    http_requests_total.labels(method=request.method, endpoint=ep, status=response.status_code).inc()
    http_request_duration_seconds.labels(method=request.method, endpoint=ep).observe(dur/1000)
    http_requests_in_flight.dec()
    lvl = logging.WARNING if response.status_code >= 500 else logging.INFO
    logger.log(lvl, f"{request.method} {request.path} {response.status_code}",
        extra={"trace_id": request.trace_id, "method": request.method,
               "path": request.path, "status": response.status_code, "duration_ms": round(dur,2)})
    response.headers['X-Trace-ID'] = request.trace_id
    return response

@app.route('/')
def home():
    return jsonify({'service': 'demo-app', 'version': '1.0.0',
        'endpoints': ['/health','/metrics','/api/fast','/api/slow','/api/error','/api/orders']})

@app.route('/health')
def health():
    return jsonify({'status': 'ok', 'uptime': time.time()})

@app.route('/metrics')
def metrics():
    return generate_latest(REGISTRY), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/api/fast')
def api_fast():
    time.sleep(random.uniform(0.005, 0.015))
    return jsonify({'result': 'fast', 'trace_id': request.trace_id})

@app.route('/api/slow')
def api_slow():
    d = random.uniform(0.2, 0.8)
    time.sleep(d)
    return jsonify({'result': 'slow', 'delay_s': round(d,3), 'trace_id': request.trace_id})

@app.route('/api/error')
def api_error():
    if random.random() < 0.20:
        logger.error("DB timeout", extra={"trace_id": request.trace_id})
        return jsonify({'error': 'Internal server error', 'trace_id': request.trace_id}), 500
    return jsonify({'result': 'ok', 'trace_id': request.trace_id})

@app.route('/api/orders', methods=['POST'])
def create_order():
    products = ['shirt','shoes','hat','bag','watch']
    regions  = ['mumbai','delhi','bangalore','pune','hyderabad']
    product  = random.choice(products)
    region   = random.choice(regions)
    status   = random.choices(['success','failed'], weights=[80,20])[0]
    orders_total.labels(product=product, region=region, status=status).inc()
    time.sleep(random.uniform(0.05, 0.15))
    if status == 'failed':
        return jsonify({'error': 'Payment failed', 'trace_id': request.trace_id}), 400
    return jsonify({'order_id': random.randint(10000,99999), 'product': product,
                    'region': region, 'trace_id': request.trace_id}), 201

def simulate_traffic():
    import urllib.request
    eps = ['/api/fast']*6 + ['/api/slow']*2 + ['/api/error']*2
    while True:
        try: urllib.request.urlopen(f'http://localhost:5000{random.choice(eps)}', timeout=5)
        except: pass
        time.sleep(random.uniform(0.5, 2.0))

def simulate_queue():
    d = 10
    while True:
        d = max(0, min(100, d + random.randint(-5, 8)))
        queue_depth.set(d)
        time.sleep(5)

if __name__ == '__main__':
    threading.Thread(target=simulate_traffic, daemon=True).start()
    threading.Thread(target=simulate_queue, daemon=True).start()
    logger.info("Demo app starting", extra={"trace_id": "startup"})
    app.run(host='0.0.0.0', port=5000, threaded=True)
