#!/bin/bash
cd "$(dirname "$0")"
bin/jobs start >> log/jobs.log 2>&1 &
echo $! > tmp/pids/jobs.pid
echo "Solid Queue worker started with PID $(cat tmp/pids/jobs.pid)"
echo "Logs: tail -f log/jobs.log"
