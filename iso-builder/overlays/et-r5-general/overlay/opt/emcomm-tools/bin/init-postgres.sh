#!/bin/bash
# First-boot PostgreSQL initialization

# Wait for PostgreSQL (max 30 seconds)
TRIES=0
until sudo -u postgres pg_isready || [ $TRIES -eq 30 ]; do
    sleep 1
    TRIES=$((TRIES + 1))
done

if [ $TRIES -eq 30 ]; then
    echo "PostgreSQL not responding, skipping initialization"
    exit 0
fi

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = 'emcomm'" | grep -q 1 || \
    sudo -u postgres createdb emcomm
echo "PostgreSQL initialized for EmComm-Tools"
