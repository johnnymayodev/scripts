#! /bin/bash

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
fi

if ! command -v docker-compose &> /dev/null; then
    sudo apt install docker-compose -y
fi

echo "Docker and Docker Compose installed successfully!"
echo "Docker version: $(docker --version)"

exit 0