#!/bin/bash

# Check if tag is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <tag>"
  exit 1
fi

TAG=$1

az acr login -n acnpublic
# Unset ARCH and set Docker flags
unset ARCH
DOCKER_FLAGS="--platform linux/amd64"

# Build the Cilium Docker image
make docker-cilium-image

# Tag the image with the provided tag
docker tag quay.io/cilium/cilium:latest acnpublic.azurecr.io/cilium/cilium:$TAG

# Push the tagged image to the Azure container registry
docker push acnpublic.azurecr.io/cilium/cilium:$TAG

