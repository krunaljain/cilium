#!/bin/bash

# Script to build, push a Cilium image, and update the Cilium DaemonSet in Kubernetes

# Usage: ./script.sh <tag> <k8s_context>

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <tag> <k8s_context>"
  exit 1
fi

TAG=$1
K8S_CONTEXT=$2
REGISTRY="acnpublic.azurecr.io"
NEW_IMAGE="$REGISTRY/cilium/cilium:$TAG"

# Step 1: Login to Azure Container Registry
echo "Logging in to Azure Container Registry..."
az acr login -n acnpublic
if [[ $? -ne 0 ]]; then
  echo "Failed to log in to Azure Container Registry. Exiting."
  exit 1
fi

# Step 2: Build the Cilium Docker image
echo "Building the Cilium Docker image..."
unset ARCH
DOCKER_FLAGS="--platform linux/amd64"
make docker-cilium-image

# Step 3: Tag and push the Docker image
echo "Tagging and pushing the Docker image..."
docker tag quay.io/cilium/cilium:latest "$NEW_IMAGE"
docker push "$NEW_IMAGE"
if [[ $? -ne 0 ]]; then
  echo "Failed to push the Docker image. Exiting."
  exit 1
fi

# Step 4: Retrieve the image digest for the newly pushed image
IMAGE_SHA=$(az acr repository show-manifests --name acnpublic --repository cilium/cilium --query "[?tags[?contains(@, '$TAG')]].digest" -o tsv)
if [[ -z "$IMAGE_SHA" ]]; then
  echo "Failed to retrieve the image digest. Exiting."
  exit 1
fi

# Step 5: Update the DaemonSet directly in Kubernetes with the new image (tag + digest)
echo "Updating the Cilium DaemonSet with the new image (tag + digest)..."
kubectl --context "$K8S_CONTEXT" get ds -n kube-system cilium -o yaml | \
  sed -E "s|image: .*cilium/cilium.*|image: ${NEW_IMAGE}@${IMAGE_SHA}|g" | \
  kubectl --context "$K8S_CONTEXT" apply -f -
if [[ $? -ne 0 ]]; then
  echo "Failed to update the Cilium DaemonSet. Exiting."
  exit 1
fi

echo "Cilium image successfully updated to '${NEW_IMAGE}@${IMAGE_SHA}' in the Kubernetes cluster with context '${K8S_CONTEXT}'."