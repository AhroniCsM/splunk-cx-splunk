FROM --platform=linux/amd64 python:3.9-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Download and install Splunk Universal Forwarder
# Using version 9.3.1 (works with x86_64)
WORKDIR /tmp
RUN wget -O splunkforwarder.tgz 'https://download.splunk.com/products/universalforwarder/releases/9.3.1/linux/splunkforwarder-9.3.1-0b8d769cb912-Linux-x86_64.tgz' \
    && tar xzf splunkforwarder.tgz -C /opt \
    && rm splunkforwarder.tgz

# Set Splunk environment variables
ENV SPLUNK_HOME=/opt/splunkforwarder
ENV PATH=$SPLUNK_HOME/bin:$PATH

# Create necessary directories
RUN mkdir -p /var/log/myapp \
    && mkdir -p $SPLUNK_HOME/etc/system/local

# Copy Splunk configuration files
COPY inputs.conf $SPLUNK_HOME/etc/system/local/inputs.conf
COPY outputs.conf.template $SPLUNK_HOME/etc/system/local/outputs.conf.template

# Copy Python application
COPY app.py /app/app.py
RUN chmod +x /app/app.py

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Accept Splunk license and start
RUN $SPLUNK_HOME/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd changeme \
    && $SPLUNK_HOME/bin/splunk stop

# Expose ports (optional, for management)
EXPOSE 8089 9997

# Set working directory
WORKDIR /app

# Use entrypoint script to start both Splunk and the app
ENTRYPOINT ["/entrypoint.sh"]

