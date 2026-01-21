#!/bin/bash

# Stop on errors
set -e

# Function to print usage
usage() {
    echo "Usage: $0 {add|remove} <group> <username>"
    echo
    echo "Commands:"
    echo "  add     Create a new user and set their password"
    echo "  remove  Delete an existing user"
    exit 1
}

# Check arguments
if [ "$#" -lt 3 ]; then
    usage
fi

ACTION=$1
GROUP=$2
USERNAME=$3

# Locate galenectl
GALENECTL="./galenectl"
if [ ! -f "$GALENECTL" ]; then
    if [ -f "build/galenectl" ]; then
        GALENECTL="build/galenectl"
    else
        echo "Error: galenectl binary not found in current directory or build/."
        echo "Please ensure you have built the project using setup_server.sh"
        exit 1
    fi
fi

# Locate config
CONFIG="./galenectl.json"
if [ ! -f "$CONFIG" ]; then
    if [ -f "build/galenectl.json" ]; then
        CONFIG="build/galenectl.json"
    else
        echo "Error: galenectl.json not found in current directory or build/."
        echo "Please ensure you have run the setup script or configured galenectl."
        exit 1
    fi
fi

case "$ACTION" in
    add)
        echo "Adding user '$USERNAME' to group '$GROUP'..."

        # Check if password is provided via env var (for automation) or prompt
        if [ -z "$USER_PASSWORD" ]; then
            read -s -p "Enter password for '$USERNAME': " PASSWORD
            echo
            read -s -p "Confirm password: " PASSWORD_CONFIRM
            echo

            if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
                echo "Error: Passwords do not match."
                exit 1
            fi
        else
            PASSWORD="$USER_PASSWORD"
        fi

        # Create user
        "$GALENECTL" -config "$CONFIG" create-user -group "$GROUP" -user "$USERNAME"

        # Set password
        "$GALENECTL" -config "$CONFIG" set-password -group "$GROUP" -user "$USERNAME" -password "$PASSWORD"

        echo "User '$USERNAME' added successfully."
        ;;

    remove)
        echo "Removing user '$USERNAME' from group '$GROUP'..."

        # Delete user
        "$GALENECTL" -config "$CONFIG" delete-user -group "$GROUP" -user "$USERNAME"

        echo "User '$USERNAME' removed successfully."
        ;;

    *)
        usage
        ;;
esac
