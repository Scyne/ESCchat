#!/bin/bash

# Stop on errors
set -e

echo "--- Setting up Galene in ./build ---"

# 1. Create the target directory structure
# Galene needs specific folders to store data and groups
mkdir -p build/data build/groups build/static

# 2. Move the main binary (as requested)
echo "[1/5] Moving galene binary to ./build..."
mv galene build/

# 3. Copy static web assets
# The server needs these files to serve the web client
echo "[2/5] Copying static assets..."
cp -r static/* build/static/

# 4. Install MediaPipe (Background Blur)
# This follows the official instructions but targets the ./build folder
echo "[3/5] Downloading MediaPipe libraries..."
mkdir -p temp_mediapipe
cd temp_mediapipe

# Download and extract tasks-vision
wget -q https://registry.npmjs.org/@mediapipe/tasks-vision/-/tasks-vision-0.10.21.tgz
tar xzf tasks-vision-*.tgz

# Prepare destination in build folder
mkdir -p ../build/static/third-party/tasks-vision/models

# Move the package files
mv package/* ../build/static/third-party/tasks-vision/

# Download the specific model file
cd ../build/static/third-party/tasks-vision/models
wget -q https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/latest/selfie_segmenter.tflite

# Cleanup
cd ../../../../../
rm -rf temp_mediapipe

# 5. Build and install galenectl (Admin Tool)
# You will need this to create groups and users later
echo "[4/5] Building galenectl..."
cd galenectl
CGO_ENABLED=0 go build -ldflags='-s -w'
mv galenectl ../build/
cd ..

# 6. Initial Configuration
echo "[5/5] Generating initial configuration..."
cd build
# Initialize config (creates config.json and galenectl.json)
./galenectl -admin-username admin initial-setup
# Move config.json to data/ as required
mv config.json data/

echo "---------------------------------------"
echo "Setup complete!"
echo "You can now run the server from the build directory."
