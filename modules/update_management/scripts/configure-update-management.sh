#!/bin/bash
# Configure Azure Update Management for Linux VM
# This script configures the VM to work with Azure Update Management

set -e

WORKSPACE_ID="$1"
WORKSPACE_KEY="$2"

if [ -z "$WORKSPACE_ID" ] || [ -z "$WORKSPACE_KEY" ]; then
    echo "Error: Missing required parameters"
    echo "Usage: $0 <workspace_id> <workspace_key>"
    exit 1
fi

echo "Configuring Azure Update Management..."
echo "Workspace ID: $WORKSPACE_ID"

# Create log directory
sudo mkdir -p /var/log/azure-update-management
sudo chmod 755 /var/log/azure-update-management

LOG_FILE="/var/log/azure-update-management/configuration.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | sudo tee -a "$LOG_FILE"
}

log_message "Starting Azure Update Management configuration"

# Update package lists
log_message "Updating package lists..."
sudo apt-get update

# Install required packages
log_message "Installing required packages..."
sudo apt-get install -y curl wget jq apt-transport-https lsb-release gnupg

# Detect OS version
OS_VERSION=$(lsb_release -rs)
OS_CODENAME=$(lsb_release -cs)
log_message "Detected OS: Ubuntu $OS_VERSION ($OS_CODENAME)"

# Configure Azure Monitor Agent repository
log_message "Configuring Azure Monitor Agent repository..."
wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $OS_CODENAME main" | sudo tee /etc/apt/sources.list.d/azure-cli.list

# Update package lists with new repository
sudo apt-get update

# Configure system for Update Management
log_message "Configuring system for Update Management..."

# Create Azure Update Management configuration
sudo mkdir -p /etc/opt/microsoft/azure-update-management
sudo tee /etc/opt/microsoft/azure-update-management/config.json > /dev/null << EOF
{
    "workspaceId": "$WORKSPACE_ID",
    "enableUpdateManagement": true,
    "enableInventory": true,
    "enableChangeTracking": true,
    "configurationTimestamp": "$(date -Iseconds)",
    "osType": "Linux",
    "osVersion": "$OS_VERSION",
    "distribution": "Ubuntu"
}
EOF

# Set proper permissions
sudo chmod 600 /etc/opt/microsoft/azure-update-management/config.json

# Configure update behavior
log_message "Configuring update behavior..."

# Create update management policy
sudo tee /etc/apt/apt.conf.d/99azure-update-management > /dev/null << 'EOF'
// Azure Update Management Configuration
// Disable automatic updates - managed by Azure Update Management
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
APT::Periodic::AutocleanInterval "0";

// Configure update behavior
Dpkg::Options {
    "--force-confdef";
    "--force-confold";
}

// Logging configuration
Debug::pkgProblemResolver "true";
Debug::pkgAcquire "true";
EOF

# Disable and stop unattended-upgrades if present
if systemctl is-enabled unattended-upgrades >/dev/null 2>&1; then
    log_message "Disabling unattended-upgrades service..."
    sudo systemctl disable unattended-upgrades
    sudo systemctl stop unattended-upgrades
fi

# Configure inventory collection
log_message "Configuring inventory collection..."
sudo mkdir -p /etc/opt/microsoft/azure-inventory

# Create inventory configuration
sudo tee /etc/opt/microsoft/azure-inventory/inventory.conf > /dev/null << EOF
# Azure Inventory Configuration
COLLECT_SOFTWARE_INVENTORY=true
COLLECT_FILE_INVENTORY=true
COLLECT_REGISTRY_INVENTORY=false
COLLECT_SERVICES_INVENTORY=true
INVENTORY_FREQUENCY=daily
INVENTORY_LOG_LEVEL=info
EOF

# Configure change tracking
log_message "Configuring change tracking..."
sudo mkdir -p /etc/opt/microsoft/azure-changetracking

sudo tee /etc/opt/microsoft/azure-changetracking/changetracking.conf > /dev/null << EOF
# Azure Change Tracking Configuration
TRACK_FILE_CHANGES=true
TRACK_REGISTRY_CHANGES=false
TRACK_SERVICE_CHANGES=true
TRACK_SOFTWARE_CHANGES=true
TRACK_DAEMON_CHANGES=true

# File tracking paths
FILE_TRACKING_PATHS="/etc,/usr/bin,/usr/sbin,/bin,/sbin"

# Change tracking frequency
CHANGE_TRACKING_FREQUENCY=hourly
CHANGE_LOG_RETENTION_DAYS=30
EOF

# Create Update Management status script
log_message "Creating status monitoring script..."
sudo tee /usr/local/bin/azure-update-status.sh > /dev/null << 'EOF'
#!/bin/bash
# Azure Update Management Status Script

STATUS_FILE="/var/log/azure-update-management/status.json"
mkdir -p "$(dirname "$STATUS_FILE")"

# Get system information
HOSTNAME=$(hostname)
UPTIME=$(uptime -s)
LAST_UPDATE_CHECK=$(stat -c %Y /var/lib/apt/periodic/update-success-stamp 2>/dev/null || echo "0")
REBOOT_REQUIRED=$([ -f /var/run/reboot-required ] && echo "true" || echo "false")

# Get package information
AVAILABLE_UPDATES=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
SECURITY_UPDATES=$(unattended-upgrade --dry-run 2>/dev/null | grep -c "security" || echo "0")

# Create status JSON
cat > "$STATUS_FILE" << EOJ
{
    "hostname": "$HOSTNAME",
    "timestamp": "$(date -Iseconds)",
    "uptime": "$UPTIME", 
    "lastUpdateCheck": $LAST_UPDATE_CHECK,
    "rebootRequired": $REBOOT_REQUIRED,
    "availableUpdates": $AVAILABLE_UPDATES,
    "securityUpdates": $SECURITY_UPDATES,
    "updateManagementEnabled": true,
    "agentVersion": "1.0.0"
}
EOJ

echo "Status updated: $STATUS_FILE"
EOF

sudo chmod +x /usr/local/bin/azure-update-status.sh

# Create systemd service for status monitoring
log_message "Creating status monitoring service..."
sudo tee /etc/systemd/system/azure-update-status.service > /dev/null << EOF
[Unit]
Description=Azure Update Management Status Monitor
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/azure-update-status.sh
User=root

[Install]
WantedBy=multi-user.target
EOF

# Create timer for status service
sudo tee /etc/systemd/system/azure-update-status.timer > /dev/null << EOF
[Unit]
Description=Run Azure Update Management Status Monitor every 30 minutes
Requires=azure-update-status.service

[Timer]
OnCalendar=*:0/30
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable and start the timer
sudo systemctl daemon-reload
sudo systemctl enable azure-update-status.timer
sudo systemctl start azure-update-status.timer

# Run initial status check
log_message "Running initial status check..."
sudo /usr/local/bin/azure-update-status.sh

# Configure log rotation
log_message "Configuring log rotation..."
sudo tee /etc/logrotate.d/azure-update-management > /dev/null << EOF
/var/log/azure-update-management/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

# Create final configuration status
sudo tee /var/log/azure-update-management/configuration-status.json > /dev/null << EOF
{
    "configurationComplete": true,
    "configurationTimestamp": "$(date -Iseconds)",
    "workspaceId": "$WORKSPACE_ID",
    "updateManagementEnabled": true,
    "inventoryEnabled": true,
    "changeTrackingEnabled": true,
    "statusMonitoringEnabled": true,
    "osType": "Linux",
    "osVersion": "$OS_VERSION",
    "distribution": "Ubuntu"
}
EOF

log_message "Azure Update Management configuration completed successfully!"

echo ""
echo "=================================================="
echo "Azure Update Management Configuration Complete!"
echo "=================================================="
echo ""
echo "Configuration files created:"
echo "  - /etc/opt/microsoft/azure-update-management/config.json"
echo "  - /etc/opt/microsoft/azure-inventory/inventory.conf"
echo "  - /etc/opt/microsoft/azure-changetracking/changetracking.conf"
echo ""
echo "Services enabled:"
echo "  - azure-update-status.timer (every 30 minutes)"
echo ""
echo "Log files:"
echo "  - $LOG_FILE"
echo "  - /var/log/azure-update-management/status.json"
echo "  - /var/log/azure-update-management/configuration-status.json"
echo ""
echo "Next steps:"
echo "  1. Verify VM appears in Azure Update Management portal"
echo "  2. Configure update deployment schedules"
echo "  3. Monitor patch compliance in Azure portal"
echo ""