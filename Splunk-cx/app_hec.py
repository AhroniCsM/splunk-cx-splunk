#!/usr/bin/env python3
"""
Python application that sends logs directly to Splunk HEC (HTTP Event Collector).
Works on any platform including ARM Mac.
"""

import logging
import time
import random
import os
import requests
import json
from datetime import datetime
import socket
import uuid

# Configuration from environment variables
LOG_INTERVAL_SECONDS = int(os.getenv('LOG_INTERVAL_SECONDS', '30'))
SPLUNK_HEC_URL = os.getenv('SPLUNK_HEC_URL', 'https://inputs.prd-p-vl1fl.splunkcloud.com:8088/services/collector')
SPLUNK_HEC_TOKEN = os.getenv('SPLUNK_HEC_TOKEN', 'YOUR_HEC_TOKEN_HERE')
SPLUNK_INDEX = os.getenv('SPLUNK_INDEX', 'main')
SPLUNK_SOURCETYPE = os.getenv('SPLUNK_SOURCETYPE', 'python:app')

# Configure local logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/myapp/application.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger('MyApp')

class SplunkHECHandler:
    """Handler to send logs to Splunk via HEC"""

    def __init__(self, hec_url, hec_token, index, sourcetype):
        self.hec_url = hec_url
        # Generate a unique channel UUID for Splunk Cloud indexer acknowledgment
        self.channel_id = str(uuid.uuid4())
        self.headers = {
            'Authorization': f'Splunk {hec_token}',
            'Content-Type': 'application/json',
            'X-Splunk-Request-Channel': self.channel_id  # Required for Splunk Cloud
        }
        self.index = index
        self.sourcetype = sourcetype
        self.hostname = socket.gethostname()
        self.session = requests.Session()
        self.session.headers.update(self.headers)
        # Disable SSL warnings for self-signed certs (optional)
        import urllib3
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    def send_event(self, message, severity='INFO'):
        """Send a single event to Splunk HEC"""
        event = {
            'time': time.time(),
            'host': self.hostname,
            'source': 'myapp',
            'sourcetype': self.sourcetype,
            'index': self.index,
            'event': {
                'message': message,
                'severity': severity,
                'application': 'MyApp'
            }
        }

        try:
            response = self.session.post(
                self.hec_url,
                json=event,
                verify=False,  # Splunk Cloud uses self-signed certs
                timeout=10
            )

            if response.status_code != 200:
                logger.warning(f"HEC returned status {response.status_code}: {response.text}")
                return False
            return True
        except Exception as e:
            logger.error(f"Failed to send to Splunk HEC: {str(e)}")
            return False

def generate_sample_logs(splunk_handler):
    """Generate various types of log messages and send to Splunk"""
    log_messages = [
        "User authentication successful",
        "Processing transaction",
        "Database query executed",
        "API request received",
        "Cache hit for user data",
        "Background job started",
        "Email notification sent",
        "File upload completed",
        "Session created",
        "Configuration reloaded"
    ]

    error_messages = [
        "Connection timeout",
        "Invalid input parameter",
        "Resource not found",
        "Permission denied"
    ]

    logger.info(f"Log generation interval: {LOG_INTERVAL_SECONDS} seconds")
    estimated_daily_logs = int((24 * 60 * 60) / LOG_INTERVAL_SECONDS)
    logger.info(f"Estimated daily logs: ~{estimated_daily_logs:,}")
    logger.info(f"Estimated daily volume: ~{(estimated_daily_logs * 150 / 1024 / 1024):.2f} MB")
    logger.info(f"Sending to Splunk HEC: {SPLUNK_HEC_URL}")
    logger.info(f"Index: {SPLUNK_INDEX}, Sourcetype: {SPLUNK_SOURCETYPE}")

    # Test HEC connection
    logger.info("Testing Splunk HEC connection...")
    test_message = "Application started - HEC test"
    if splunk_handler.send_event(test_message, 'INFO'):
        logger.info("✅ Successfully connected to Splunk HEC!")
    else:
        logger.error("❌ Failed to connect to Splunk HEC. Check token and URL.")

    while True:
        try:
            # Generate random log entry
            if random.random() < 0.1:  # 10% chance of error
                message = f"ERROR: {random.choice(error_messages)} - User: user{random.randint(1, 100)}"
                severity = 'ERROR'
                logger.error(message)
            elif random.random() < 0.2:  # 20% chance of warning
                message = f"WARNING: High memory usage detected - {random.randint(70, 95)}%"
                severity = 'WARNING'
                logger.warning(message)
            else:
                message = f"INFO: {random.choice(log_messages)} - RequestID: {random.randint(1000, 9999)}"
                severity = 'INFO'
                logger.info(message)

            # Send to Splunk HEC
            splunk_handler.send_event(message, severity)

            # Sleep for configured interval
            time.sleep(LOG_INTERVAL_SECONDS)

        except KeyboardInterrupt:
            logger.info("Application shutting down...")
            break
        except Exception as e:
            logger.error(f"Unexpected error: {str(e)}")
            time.sleep(LOG_INTERVAL_SECONDS)

if __name__ == "__main__":
    logger.info("=" * 50)
    logger.info("Application started - Splunk HEC Mode")
    logger.info(f"Timestamp: {datetime.now().isoformat()}")
    logger.info("=" * 50)

    # Create log directory if it doesn't exist
    os.makedirs('/var/log/myapp', exist_ok=True)

    # Validate configuration
    if SPLUNK_HEC_TOKEN == 'YOUR_HEC_TOKEN_HERE':
        logger.error("⚠️  ERROR: SPLUNK_HEC_TOKEN not set!")
        logger.error("Please set environment variable: -e SPLUNK_HEC_TOKEN=<your-token>")
        logger.info("Continuing without Splunk HEC (local logs only)...")
        time.sleep(5)

    # Initialize Splunk HEC handler
    splunk_handler = SplunkHECHandler(
        SPLUNK_HEC_URL,
        SPLUNK_HEC_TOKEN,
        SPLUNK_INDEX,
        SPLUNK_SOURCETYPE
    )

    logger.info(f"Channel ID: {splunk_handler.channel_id}")
    logger.info("Using channel-based delivery for Splunk Cloud")

    generate_sample_logs(splunk_handler)

