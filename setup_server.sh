#!/bin/bash

# Stop on errors
set -e

# Kill any existing galene instances to ensure we don't conflict on ports
pkill galene || true

echo "--- Setting up Galene in ./build ---"

# Prompt for clean build
if [ -d "build" ]; then
    read -p "Build directory exists. Do you want to do a clean build (remove build/)? (y/n) " clean_build
    if [ "$clean_build" = "y" ]; then
        echo "Removing build directory..."
        rm -rf build
    else
        echo "Cleaning existing binaries..."
        rm -f build/galene build/galenectl
    fi
fi

# 1. Create the target directory structure
mkdir -p build/data build/groups build/static

# 2. Build and Move the main binary
echo "[1/5] Building and moving galene binary..."
go build -ldflags='-s -w'
mv galene build/

# 3. Copy static web assets
echo "[2/5] Copying static assets..."
cp -r static/* build/static/

# 4. Install MediaPipe (Background Blur)
echo "[3/5] Downloading MediaPipe libraries..."
if [ ! -f "build/static/third-party/tasks-vision/models/selfie_segmenter.tflite" ]; then
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
    echo "MediaPipe installed."
else
    echo "MediaPipe already installed, skipping."
fi

# 5. Build and install galenectl (Admin Tool)
echo "[4/5] Building galenectl..."
cd galenectl
CGO_ENABLED=0 go build -ldflags='-s -w'
mv galenectl ../build/
cd ..

# 6. Configuration and User Setup
echo "[5/5] Configuring server..."
cd build

# Admin Setup
echo "Configuring admin user 'Scyne'..."
read -s -p "Enter password for admin user 'Scyne': " scyne_pass
echo
scyne_hash=$(./galenectl hash-password -password "$scyne_pass")

# Server Config (Temporary without canonicalHost to allow localhost access)
cat <<EOF > data/config.json
{
    "users": {
        "Scyne": {
            "password": $scyne_hash,
            "permissions": "admin"
        }
    },
    "writableGroups": true
}
EOF

# Galenectl Config (for local use)
cat <<EOF > galenectl.json
{
    "server": "http://localhost:8443/",
    "admin-username": "Scyne",
    "admin-password": "$scyne_pass"
}
EOF

# Start Galene temporarily for API operations
echo "Starting Galene temporarily to setup groups and users..."
./galene -http :8443 -insecure > /dev/null 2>&1 &
GALENE_PID=$!
sleep 5

# Create 'Work' group
echo "Creating 'Work' group..."
./galenectl -config galenectl.json create-group -group Work

# User Creation Loop
while true; do
    echo
    read -p "Do you want to create a new user in 'Work' group? (y/n) " yn
    if [ "$yn" != "y" ]; then break; fi

    read -p "Username: " uname
    read -s -p "Password: " upass
    echo
    ./galenectl -config galenectl.json create-user -group Work -user "$uname"
    ./galenectl -config galenectl.json set-password -group Work -user "$uname" -password "$upass"
done

# Stop Galene
kill $GALENE_PID

# Update Server Config with canonicalHost
cat <<EOF > data/config.json
{
    "users": {
        "Scyne": {
            "password": $scyne_hash,
            "permissions": "admin"
        }
    },
    "canonicalHost": "ec2-44-215-70-124.compute-1.amazonaws.com:9090",
    "writableGroups": true
}
EOF

# Move config.json to data/ if it isn't there (it is, we wrote it there)
# But galenectl.json stays in root of build for admin use

echo "---------------------------------------"
echo "Setup complete!"
echo "You can now run the server from the build directory."
echo "Suggested command: cd build && ./galene -http :9090 -turn 44.215.70.124:1194"
