#!/bin/bash
set -e

# YubiKey SSH Control - Automated Setup Script
# This script sets up secure YubiKey sharing between host and LXD container

echo "=== YubiKey SSH Control Setup ==="
echo ""
echo "usage ./install-yubikey-share.sh CONTAINER_NAME HOST_USER CONTAINER_USER"

if [ $# != 3 ]; then
    echo "incorrect number of arguments"
    exit 1
fi

# Configuration
CONTAINER_NAME=$1
HOST_USER=$2
CONTAINER_USER=$3
HOME_PATH="/home/$2/"
CONTAINER_HOME_PATH="/home/$3"

# Detect container IP
echo ""
echo "Detecting container IP..."
CONTAINER_IP=$(lxc list "$CONTAINER_NAME" -c 4 -f csv | awk '{print $1}')

if [ -z "$CONTAINER_IP" ]; then
    echo "Error: Could not detect container IP. Is the container running?"
    exit 1
fi

echo "Container IP: $CONTAINER_IP"

# Extract IP subnet (e.g., 10.123.45.67 -> 10.123.45.*)
CONTAINER_SUBNET=$(echo "$CONTAINER_IP" | sed 's/\.[0-9]*$/.*/')
echo "Container subnet pattern: $CONTAINER_SUBNET"

# Detect host IP (as seen from container)
echo "Detecting host IP..."
HOST_IP=$(lxc network get lxdbr0 ipv4.address | cut -d'/' -f1)

if [ -z "$HOST_IP" ]; then
    # Fallback method
    HOST_IP=$(ip -4 addr show lxdbr0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
fi

echo "Host IP: $HOST_IP"

# ============================================================================
# PART 1: Setup on Host (One-time key generation)
# ============================================================================

echo ""
echo "=== Setting up HOST ==="

# Create bin directory
mkdir -p $HOME_PATH/bin

# Check if master key exists, if not generate it
if [ ! -f $HOME_PATH/.ssh/yk_control ]; then
    echo ""
    echo "Generating master YubiKey control SSH key..."
    ssh-keygen -t ed25519 -f $HOME_PATH/.ssh/yk_control -C 'yubikey-control-master' -N ''
    chmod 600 $HOME_PATH/.ssh/yk_control
    chmod 644 $HOME_PATH/.ssh/yk_control.pub
    echo "✓ Master SSH key generated at ~/.ssh/yk_control"
else
    echo "✓ Master SSH key already exists at ~/.ssh/yk_control"
fi

# Get the public key
HOST_PUBKEY=$(cat $HOME_PATH/.ssh/yk_control.pub)

# Add functions to zshrc
echo ""
echo "Adding YubiKey control functions to ~/.zshrc..."

if ! grep -q "# YubiKey control functions" ~HOME_PATH/.zshrc; then
    cat >>$HOME_PATH/.zshrc <<'EOF'

# YubiKey control functions
yk-to-container() {
    local container_name="${1:-CONTAINER_NAME_PLACEHOLDER}"
    local yk_device=$(ls /dev/hidraw* 2>/dev/null | head -1)
    
    if [ -z "$yk_device" ]; then
        echo "Error: No YubiKey found on host"
        return 1
    fi
    
    echo "Passing $yk_device to container $container_name..."
    lxc config device add "$container_name" yubikey unix-char path="$yk_device"
    
    if [ $? -eq 0 ]; then
        echo "YubiKey successfully passed to container"
    else
        echo "Error: Failed to pass YubiKey to container"
        return 1
    fi
}

yk-to-host() {
    local container_name="${1:-CONTAINER_NAME_PLACEHOLDER}"
    
    echo "Reclaiming YubiKey from container..."
    lxc config device remove "$container_name" yubikey 2>/dev/null
    
    sleep 1
    
    local yk_device=$(ls /dev/hidraw* 2>/dev/null | head -1)
    if [ -n "$yk_device" ]; then
        echo "YubiKey successfully reclaimed: $yk_device"
    else
        echo "Warning: YubiKey not detected on host yet (may need to wait)"
    fi
}

yk-status() {
    local container_name="${1:-CONTAINER_NAME_PLACEHOLDER}"
    echo "Container devices:"
    lxc config device show "$container_name"
}
EOF

    # Set default container name
    sed -i "s/CONTAINER_NAME_PLACEHOLDER/$CONTAINER_NAME/g" ~/.zshrc

    echo "✓ Functions added to ~/.zshrc"
else
    echo "⚠ Functions already exist in ~/.zshrc, skipping..."
fi

# Source the functions for current session
source $HOME_PATH/.zshrc

# Create dispatcher script (if it doesn't exist or update it)
echo ""
echo "Creating SSH dispatcher script..."

cat >$HOME_PATH/bin/yk-dispatcher <<'EOF'
#!/bin/bash
set -e

# Log file for security monitoring
LOG_FILE=$HOME_PATH/yk-control.log

log_attempt() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Client: $SSH_CLIENT - Command: $SSH_ORIGINAL_COMMAND" >> "$LOG_FILE"
}

log_attempt

# Parse command: format is "claim CONTAINER_NAME" or just "claim"
COMMAND=$(echo "$SSH_ORIGINAL_COMMAND" | awk '{print $1}')
CONTAINER_ARG=$(echo "$SSH_ORIGINAL_COMMAND" | awk '{print $2}')

case "$COMMAND" in
    "claim")
        yk-to-container "$CONTAINER_ARG"
        ;;
    "release")
        yk-to-host "$CONTAINER_ARG"
        ;;
    "status")
        yk-status "$CONTAINER_ARG"
        ;;
    *)
        echo "$(date '+%Y-%m-%d %H:%M:%S') - DENIED - Client: $SSH_CLIENT - Command: $SSH_ORIGINAL_COMMAND" >> "$LOG_FILE"
        echo "Error: Invalid command. Allowed: claim [container], release [container], status [container]"
        exit 1
        ;;
esac
EOF

chmod +x $HOME_PATH/bin/yk-dispatcher
echo "✓ Dispatcher script created at ~/bin/yk-dispatcher"

# Ensure SSH directory exists and has correct permissions
mkdir -p $HOME_PATH/.ssh
chmod 700 $HOME_PATH/.ssh
touch $HOME_PATH/.ssh/authorized_keys
chmod 600 $HOME_PATH/.ssh/authorized_keys

# Add restricted key to authorized_keys on host (only once, for all containers)
echo ""
echo "Checking authorized_keys for YubiKey control entry..."

HOST_HOME=$(eval echo ~$HOST_USER)

# Check if the key already exists
if grep -q "yubikey-control-master" $HOME_PATH/.ssh/authorized_keys 2>/dev/null; then
    echo "⚠ YubiKey control key already exists in authorized_keys"
    read -p "Update subnet restriction to $CONTAINER_SUBNET? (y/n): " UPDATE_SUBNET

    if [ "$UPDATE_SUBNET" = "y" ]; then
        # Remove old entry
        grep -v "yubikey-control-master" $HOME_PATH/.ssh/authorized_keys >$HOME_PATH/.ssh/authorized_keys.tmp
        mv $HOME_PATH/.ssh/authorized_keys.tmp $HOME_PATH/.ssh/authorized_keys

        # Add new entry with updated subnet
        AUTHORIZED_KEYS_LINE="from=\"$CONTAINER_SUBNET\",command=\"$HOST_HOME/bin/yk-dispatcher\",restrict $HOST_PUBKEY"
        echo "$AUTHORIZED_KEYS_LINE" >>$HOME_PATH/.ssh/authorized_keys
        echo "✓ Updated authorized_keys with new subnet: $CONTAINER_SUBNET"
    fi
else
    # Add new entry
    AUTHORIZED_KEYS_LINE="from=\"$CONTAINER_SUBNET\",command=\"$HOST_HOME/bin/yk-dispatcher\",restrict $HOST_PUBKEY"
    echo "$AUTHORIZED_KEYS_LINE" >>$HOME_PATH/.ssh/authorized_keys
    chmod 600 $HOME_PATH/.ssh/authorized_keys
    echo "✓ Added YubiKey control key to authorized_keys"
    echo "  Allowed subnet: $CONTAINER_SUBNET"
fi

echo "✓ Host setup complete"

# ============================================================================
# PART 2: Setup in Container (Copy key from host)
# ============================================================================

echo ""
echo "=== Setting up CONTAINER ==="

# Create SSH directory in container
echo ""
echo "Setting up SSH directory in container..."

lxc exec "$CONTAINER_NAME" -- su - "$CONTAINER_USER" -c "
    mkdir -p $CONTAINER_HOME_PATH/.ssh
    chmod 700 $CONTAINER_HOME_PATH/.ssh
"

# Copy the private key from host to container
echo "Copying SSH key from host to container..."
lxc file push $HOME_PATH/.ssh/yk_control "$CONTAINER_NAME/home/$CONTAINER_USER/.ssh/yk_control"
lxc file push $HOME_PATH/.ssh/yk_control.pub "$CONTAINER_NAME/home/$CONTAINER_USER/.ssh/yk_control.pub"

# Set correct permissions in container
lxc exec "$CONTAINER_NAME" -- su - "$CONTAINER_USER" -c "
    chmod 600 $CONTAINER_HOME_PATH/.ssh/yk_control
    chmod 644 $CONTAINER_HOME_PATH/.ssh/yk_control.pub
    chown $CONTAINER_USER:$CONTAINER_USER $CONTAINER_HOME_PATH/.ssh/yk_control $CONTAINER_HOME_PATH/.ssh/yk_control.pub
"

echo "✓ SSH key copied to container"

# Add aliases to container's zshrc
echo ""
echo "Adding aliases to container's ~/.zshrc..."

lxc exec "$CONTAINER_NAME" -- su - "$CONTAINER_USER" -c "
    if ! grep -q '# YubiKey control aliases' $CONTAINER_HOME_PATH/.zshrc; then
        cat >> $CONTAINER_HOME_PATH/.zshrc << 'INNEREOF'

# YubiKey control aliases
alias yk-claim='ssh -i $CONTAINER_HOME_PATH/.ssh/yk_control -o \"IdentitiesOnly=yes\" -o \"StrictHostKeyChecking=accept-new\" HOST_IP_PLACEHOLDER claim CONTAINER_NAME_PLACEHOLDER'
alias yk-release='ssh -i $CONTAINER_HOME_PATH/.ssh/yk_control -o \"IdentitiesOnly=yes\" HOST_IP_PLACEHOLDER release CONTAINER_NAME_PLACEHOLDER'
alias yk-status='ssh -i $CONTAINER_HOME_PATH/.ssh/yk_control -o \"IdentitiesOnly=yes\" HOST_IP_PLACEHOLDER status CONTAINER_NAME_PLACEHOLDER'
INNEREOF
        echo '✓ Aliases added to container ~/.zshrc'
    else
        echo '⚠ Aliases already exist in container ~/.zshrc, skipping...'
    fi
"

# Replace placeholders with actual values
lxc exec "$CONTAINER_NAME" -- su - "$CONTAINER_USER" -c "
    sed -i 's/HOST_IP_PLACEHOLDER/$HOST_IP/g' $CONTAINER_HOME_PATH/.zshrc
    sed -i 's/CONTAINER_NAME_PLACEHOLDER/$CONTAINER_NAME/g' $CONTAINER_HOME_PATH/.zshrc
"

echo "✓ Container setup complete"

# ============================================================================
# PART 3: Test the setup
# ============================================================================

echo ""
echo "=== Testing Setup ==="

# Test 1: Try to claim YubiKey
echo ""
echo "Test 1: Claiming YubiKey from container..."
if lxc exec "$CONTAINER_NAME" -- su - "$CONTAINER_USER" -c "ssh -i $CONTAINER_HOME_PATH/.ssh/yk_control -o 'StrictHostKeyChecking=accept-new' -o 'IdentitiesOnly=yes' $HOST_IP claim $CONTAINER_NAME"; then
    echo "✓ Test 1 passed: YubiKey claimed successfully"
else
    echo "✗ Test 1 failed: Could not claim YubiKey"
fi

sleep 2

# Test 2: Try to release YubiKey
echo ""
echo "Test 2: Releasing YubiKey from container..."
if lxc exec "$CONTAINER_NAME" -- su - "$CONTAINER_USER" -c "ssh -i $CONTAINER_HOME_PATH/.ssh/yk_control -o 'IdentitiesOnly=yes' $HOST_IP release $CONTAINER_NAME"; then
    echo "✓ Test 2 passed: YubiKey released successfully"
else
    echo "✗ Test 2 failed: Could not release YubiKey"
fi

sleep 2

# Test 3: Try to run unauthorized command (should fail)
echo ""
echo "Test 3: Testing security restrictions (should deny)..."
if lxc exec "$CONTAINER_NAME" -- su - "$CONTAINER_USER" -c "ssh -i $CONTAINER_HOME_PATH/.ssh/yk_control -o 'IdentitiesOnly=yes' $HOST_IP 'ls -la' 2>&1" | grep -q "Invalid command"; then
    echo "✓ Test 3 passed: Unauthorized commands blocked"
else
    echo "⚠ Test 3: Could not verify command restrictions"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Configuration Summary:"
echo "  Container: $CONTAINER_NAME"
echo "  Container IP: $CONTAINER_IP"
echo "  Allowed subnet: $CONTAINER_SUBNET"
echo "  Host IP: $HOST_IP"
echo "  Host User: $HOST_USER"
echo "  Container User: $CONTAINER_USER"
echo "  Master key: ~/.ssh/yk_control"
echo ""
echo "Available commands in container:"
echo "  yk-claim    - Claim YubiKey from host"
echo "  yk-release  - Release YubiKey back to host"
echo "  yk-status   - Check YubiKey status"
echo ""
echo "Available commands on host:"
echo "  yk-to-container [container]  - Send YubiKey to container"
echo "  yk-to-host [container]       - Reclaim YubiKey from container"
echo "  yk-status [container]        - Check container devices"
echo ""
echo "Security features enabled:"
echo "  ✓ IP restricted to subnet: $CONTAINER_SUBNET"
echo "  ✓ Command restricted to: claim, release, status"
echo "  ✓ No shell access"
echo "  ✓ No port forwarding"
echo "  ✓ All attempts logged to: ~/yk-control.log"
echo "  ✓ Single master key used for all containers"
echo ""
echo "To add more containers, just run this script again."
echo "The same key will be copied, and they'll all work with the same subnet."
echo ""
echo "To test in container, run:"
echo "  lxc exec $CONTAINER_NAME -- su - $CONTAINER_USER"
echo "  yk-claim"
echo ""
echo "Done!"
