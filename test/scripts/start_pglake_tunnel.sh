#!/bin/bash
# Start SSH tunnel for PGLake testing
#
# This creates local ports 15432 (PostgreSQL) and 19000 (MinIO)
# that forward to the remote PGLake server at 174.138.58.253
#
# Usage: ./start_pglake_tunnel.sh

# Kill any existing tunnels
pkill -f "ssh.*174.138.58.253.*15432"

# Start new tunnel in background
ssh -f -N \
  -o ServerAliveInterval=60 \
  -o ExitOnForwardFailure=yes \
  -L 15432:127.0.0.1:5432 \
  -L 19000:127.0.0.1:9000 \
  root@174.138.58.253

echo "SSH tunnel started:"
echo "  localhost:15432 -> PGLake PostgreSQL"
echo "  localhost:19000 -> MinIO S3"
echo ""
echo "Test connection with:"
echo "  PGPASSWORD=postgres psql -h 127.0.0.1 -p 15432 -U postgres -d postgres"
