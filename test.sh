#!/bin/bash

set -e

cleanup() {
    docker-compose down -v
}
trap cleanup EXIT

echo "Starting services..."
docker-compose up -d

echo "Waiting for services..."
sleep 10

echo "Testing middleware..."
response=$(curl -s -i http://localhost)

if echo "$response" | grep -q "X-Hello-World: Hello from Yaegi!"; then
    echo "✓ Header added"
else
    echo "✗ Header missing"
    exit 1
fi

if echo "$response" | grep -q "Backend Server Response"; then
    echo "✓ Backend response"
else
    echo "✗ Backend not working"
    exit 1
fi

echo "Test passed"
