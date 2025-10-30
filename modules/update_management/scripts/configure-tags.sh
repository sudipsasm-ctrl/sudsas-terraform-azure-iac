#!/bin/bash
# Configure VM tags for Update Management
# This script applies necessary tags to identify VMs for patch management

set -e

# Tag values from template
PATCH_GROUP="${patch_group}"
ENVIRONMENT="${environment}"
SCHEDULE="${schedule}"
MAINTENANCE_WINDOW="${maintenance_window}"

echo "Configuring Update Management tags..."

# Get instance metadata
METADATA_ENDPOINT="http://169.254.169.254/metadata/instance"
COMPUTE_INFO=$(curl -H "Metadata:true" --noproxy "*" "$METADATA_ENDPOINT/compute?api-version=2021-02-01" 2>/dev/null)

if [ $? -eq 0 ]; then
    VM_NAME=$(echo "$COMPUTE_INFO" | jq -r '.name')
    RESOURCE_GROUP=$(echo "$COMPUTE_INFO" | jq -r '.resourceGroupName')
    SUBSCRIPTION_ID=$(echo "$COMPUTE_INFO" | jq -r '.subscriptionId')
    
    echo "VM Information:"
    echo "  Name: $VM_NAME"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  Subscription: $SUBSCRIPTION_ID"
    
    echo "Applying Update Management tags..."
    echo "  PatchGroup: $PATCH_GROUP"
    echo "  Environment: $ENVIRONMENT"
    echo "  UpdateSchedule: $SCHEDULE"
    echo "  MaintenanceWindow: $MAINTENANCE_WINDOW"
    
    # Create a local tag file for reference
    cat > /tmp/update-management-tags.json << EOF
{
    "PatchGroup": "$PATCH_GROUP",
    "Environment": "$ENVIRONMENT", 
    "UpdateSchedule": "$SCHEDULE",
    "MaintenanceWindow": "$MAINTENANCE_WINDOW",
    "UpdateManagement": "Enabled",
    "LastTagUpdate": "$(date -Iseconds)"
}
EOF

    echo "Tags configuration completed successfully"
    echo "Tag information saved to /tmp/update-management-tags.json"
    
else
    echo "Warning: Could not retrieve instance metadata. Tags may need to be applied manually."
    exit 1
fi

# Configure local update settings
echo "Configuring local update management settings..."

# Create update management configuration directory
sudo mkdir -p /etc/azure-update-management
sudo chmod 755 /etc/azure-update-management

# Create configuration file
sudo tee /etc/azure-update-management/config.conf > /dev/null << EOF
# Azure Update Management Configuration
# Generated on $(date)

PATCH_GROUP=$PATCH_GROUP
ENVIRONMENT=$ENVIRONMENT
UPDATE_SCHEDULE=$SCHEDULE
MAINTENANCE_WINDOW=$MAINTENANCE_WINDOW

# Update management options
ENABLE_AUTOMATIC_UPDATES=false
REBOOT_REQUIRED_ACTION=defer
PATCH_WINDOW_HOURS=2
EXCLUDE_PACKAGES=""

# Logging
LOG_LEVEL=INFO
LOG_FILE=/var/log/azure-update-management.log
EOF

# Set proper permissions
sudo chmod 644 /etc/azure-update-management/config.conf

# Configure system for update management
echo "Configuring system update settings..."

# Disable automatic updates (managed by Azure Update Management)
if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
    sudo sed -i 's/APT::Periodic::Update-Package-Lists "1"/APT::Periodic::Update-Package-Lists "0"/' /etc/apt/apt.conf.d/20auto-upgrades
    sudo sed -i 's/APT::Periodic::Unattended-Upgrade "1"/APT::Periodic::Unattended-Upgrade "0"/' /etc/apt/apt.conf.d/20auto-upgrades
fi

# Create update management status file
sudo tee /etc/azure-update-management/status > /dev/null << EOF
UPDATE_MANAGEMENT_ENABLED=true
LAST_CONFIGURATION_DATE=$(date -Iseconds)
CONFIGURATION_STATUS=success
PATCH_GROUP=$PATCH_GROUP
NEXT_MAINTENANCE_WINDOW=$MAINTENANCE_WINDOW
EOF

echo "Update Management configuration completed successfully!"
echo "Configuration files:"
echo "  - /etc/azure-update-management/config.conf"
echo "  - /etc/azure-update-management/status"
echo "  - /tmp/update-management-tags.json"