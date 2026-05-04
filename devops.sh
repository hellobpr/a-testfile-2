#!/usr/bin/env bash

set -Eeuo pipefail

LOG_PREFIX="[NODE-APP]"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') ${LOG_PREFIX} $1"
}

error_exit() {
  log "ERROR: $1"
  exit 1
}

trap 'error_exit "Script failed at line $LINENO."' ERR

log "Checking if Node.js is installed..."
if ! command -v node >/dev/null 2>&1; then
  error_exit "Node.js is not installed. Please install it before running this script."
fi
log "Node.js version: $(node -v)"

log "Checking if npm is available..."
if ! command -v npm >/dev/null 2>&1; then
  error_exit "npm is not installed. Please install it before running this script."
fi
log "npm version: $(npm -v)"

log "Installing dependencies..."
npm install
log "Dependencies installed successfully."


log "Stopping any running Node.js processes..."
pkill -f node || log "No running Node.js processes found."

log "Starting the application..."
node index.js

log "Application exited successfully."