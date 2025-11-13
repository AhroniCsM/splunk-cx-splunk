#!/usr/bin/env python3
"""
Simple Python application that generates logs for testing Splunk forwarding.
Configurable log rate to control Splunk ingestion volume.
"""

import logging
import time
import random
import os
from datetime import datetime

# Get log frequency from environment variable (in seconds)
# Default: 30 seconds between logs (about 2,880 logs/day = ~0.5 MB/day)
LOG_INTERVAL_SECONDS = int(os.getenv('LOG_INTERVAL_SECONDS', '30'))

# Configure logging to write to file
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/myapp/application.log'),
        logging.StreamHandler()  # Also output to console
    ]
)

logger = logging.getLogger('MyApp')

def generate_sample_logs():
    """Generate various types of log messages at configurable intervals"""
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
    
    while True:
        try:
            # Generate random log entries
            if random.random() < 0.1:  # 10% chance of error
                logger.error(f"ERROR: {random.choice(error_messages)} - User: user{random.randint(1, 100)}")
            elif random.random() < 0.2:  # 20% chance of warning
                logger.warning(f"WARNING: High memory usage detected - {random.randint(70, 95)}%")
            else:
                logger.info(f"INFO: {random.choice(log_messages)} - RequestID: {random.randint(1000, 9999)}")
            
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
    logger.info("Application started")
    logger.info(f"Timestamp: {datetime.now().isoformat()}")
    logger.info("=" * 50)

    # Create log directory if it doesn't exist
    import os
    os.makedirs('/var/log/myapp', exist_ok=True)

    generate_sample_logs()

