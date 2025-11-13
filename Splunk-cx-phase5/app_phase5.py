import logging
import time
import os

# Configuration from environment variables
LOG_FILE = os.getenv("LOG_FILE", "/var/log/myapp/application.log")
LOG_INTERVAL_SECONDS = int(os.getenv("LOG_INTERVAL_SECONDS", "30"))

# Ensure the log directory exists
log_dir = os.path.dirname(LOG_FILE)
if not os.path.exists(log_dir):
    os.makedirs(log_dir)

# Configure logging to file only
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()  # Also print to console
    ]
)
logger = logging.getLogger("MyApp-Phase5")

def generate_log_entry(request_id):
    """Generate a log entry with various scenarios"""
    methods = ["GET", "POST", "PUT", "DELETE"]
    endpoints = ["/api/users", "/api/products", "/api/orders", "/api/auth"]
    statuses = [200, 201, 400, 404, 500]

    method = methods[request_id % len(methods)]
    endpoint = endpoints[request_id % len(endpoints)]
    status = statuses[request_id % len(statuses)]
    response_time = (request_id * 10 % 500) + 50  # Simulate response time

    log_message = f"RequestID: {request_id} | Method: {method} | Endpoint: {endpoint} | Status: {status} | ResponseTime: {response_time}ms"

    if status >= 400:
        logger.error(log_message)
    else:
        logger.info(log_message)

if __name__ == "__main__":
    logger.info("=" * 80)
    logger.info("PHASE 5 APPLICATION STARTED - TCP + OTEL DUAL SHIPPING")
    logger.info("=" * 80)
    logger.info(f"Writing logs to: {LOG_FILE}")
    logger.info(f"Log interval: {LOG_INTERVAL_SECONDS} seconds")
    logger.info("Splunk Universal Forwarder will read this file (TCP to Splunk Cloud)")
    logger.info("OTEL Collector will read this file (OTLP to Coralogix)")
    logger.info("=" * 80)

    request_id_counter = 1
    while True:
        generate_log_entry(request_id_counter)
        request_id_counter += 1
        time.sleep(LOG_INTERVAL_SECONDS)

