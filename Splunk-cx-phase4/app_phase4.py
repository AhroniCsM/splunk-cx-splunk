#!/usr/bin/env python3
"""
Phase 4 Application - Writes logs to file ONLY
No direct sending to Splunk HEC
Splunk Universal Forwarder and OTEL will read from the file
"""

import logging
import time
import os
import random
from datetime import datetime

# Configuration from environment variables
LOG_FILE = os.getenv('LOG_FILE', '/var/log/myapp/application.log')
LOG_INTERVAL_SECONDS = int(os.getenv('LOG_INTERVAL_SECONDS', '30'))

# Ensure log directory exists
os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)

# Configure logging to write to file
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()  # Also print to console for debugging
    ]
)

logger = logging.getLogger('MyApp-Phase4')

# Request ID counter
request_id_counter = 0

def generate_log_entry():
    """Generate a sample log entry"""
    global request_id_counter
    request_id_counter += 1

    endpoints = ['/api/users', '/api/products', '/api/orders', '/api/health']
    methods = ['GET', 'POST', 'PUT', 'DELETE']
    status_codes = [200, 201, 400, 404, 500]

    endpoint = random.choice(endpoints)
    method = random.choice(methods)
    status_code = random.choice(status_codes)
    response_time = random.randint(10, 500)

    log_message = (
        f"RequestID: {request_id_counter} | "
        f"Method: {method} | "
        f"Endpoint: {endpoint} | "
        f"Status: {status_code} | "
        f"ResponseTime: {response_time}ms"
    )

    if status_code >= 400:
        logger.error(log_message)
    else:
        logger.info(log_message)

    return request_id_counter

def main():
    """Main application loop"""
    logger.info("=" * 80)
    logger.info("PHASE 4 APPLICATION STARTED")
    logger.info(f"Writing logs to: {LOG_FILE}")
    logger.info(f"Log interval: {LOG_INTERVAL_SECONDS} seconds")
    logger.info(f"Splunk Universal Forwarder will read this file")
    logger.info(f"OTEL Collector will also read this file")
    logger.info("=" * 80)

    while True:
        try:
            request_id = generate_log_entry()
            logger.debug(f"Generated log entry {request_id}")
            time.sleep(LOG_INTERVAL_SECONDS)
        except KeyboardInterrupt:
            logger.info("Application stopped by user")
            break
        except Exception as e:
            logger.error(f"Error in main loop: {e}")
            time.sleep(5)

if __name__ == "__main__":
    main()

