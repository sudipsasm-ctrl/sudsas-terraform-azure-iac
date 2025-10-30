# PowerShell Runbook for Linux Patch Management
# This runbook manages Linux VM patching through Azure Automation
# Author: Senior Azure/Terraform Engineer

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$VMName,
    
    [Parameter(Mandatory = $false)]
    [string]$PatchGroup = "default",
    
    [Parameter(Mandatory = $false)]
    [bool]$RebootIfRequired = $true,
    
    [Parameter(Mandatory = $false)]
    [string]$Environment = "prod"
)

# Ensure we have the required modules
Import-Module Az.Accounts
Import-Module Az.Resources
Import-Module Az.Compute

# Authenticate using the Automation Account's Managed Identity
Write-Output "Connecting to Azure using Managed Identity..."
try {
    $AzureContext = (Connect-AzAccount -Identity).context
    Write-Output "Successfully connected to Azure"
} catch {
    Write-Error "Failed to connect to Azure: $($_.Exception.Message)"
    exit 1
}

# Get automation variables
try {
    $AutomationEnvironment = Get-AutomationVariable -Name "Environment"
    $AutomationPatchGroup = Get-AutomationVariable -Name "PatchGroup"
    
    # Use automation variables if parameters not provided
    if (-not $Environment) { $Environment = $AutomationEnvironment }
    if (-not $PatchGroup) { $PatchGroup = $AutomationPatchGroup }
    
    Write-Output "Using Environment: $Environment, PatchGroup: $PatchGroup"
} catch {
    Write-Warning "Could not retrieve automation variables, using default values"
}

# Function to get VMs based on criteria
function Get-TargetVMs {
    param(
        [string]$ResourceGroupName,
        [string]$VMName,
        [string]$PatchGroup,
        [string]$Environment
    )
    
    $vms = @()
    
    if ($VMName -and $ResourceGroupName) {
        # Single VM specified
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VMName -ErrorAction SilentlyContinue
        if ($vm) {
            $vms += $vm
        }
    } else {
        # Get all VMs with matching tags
        $allVMs = Get-AzVM
        
        foreach ($vm in $allVMs) {
            $vmTags = $vm.Tags
            $matchesPatchGroup = ($vmTags.PatchGroup -eq $PatchGroup) -or (-not $vmTags.PatchGroup -and $PatchGroup -eq "default")
            $matchesEnvironment = ($vmTags.Environment -eq $Environment) -or (-not $Environment)
            
            if ($matchesPatchGroup -and $matchesEnvironment) {
                $vms += $vm
            }
        }
    }
    
    return $vms
}

# Function to check if VM is Linux
function Test-LinuxVM {
    param($VM)
    
    $osType = $VM.StorageProfile.OsDisk.OsType
    return ($osType -eq "Linux")
}

# Function to install updates on Linux VM
function Install-LinuxUpdates {
    param(
        [object]$VM,
        [bool]$RebootIfRequired
    )
    
    $resourceGroupName = $VM.ResourceGroupName
    $vmName = $VM.Name
    
    Write-Output "Processing Linux VM: $vmName in Resource Group: $resourceGroupName"
    
    try {
        # Check VM power state
        $vmStatus = Get-AzVM -ResourceGroupName $resourceGroupName -VMName $vmName -Status
        $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -match "PowerState" }).DisplayStatus
        
        if ($powerState -ne "VM running") {
            Write-Output "VM $vmName is not running (State: $powerState). Starting VM..."
            Start-AzVM -ResourceGroupName $resourceGroupName -VMName $vmName -NoWait
            
            # Wait for VM to start
            do {
                Start-Sleep -Seconds 30
                $vmStatus = Get-AzVM -ResourceGroupName $resourceGroupName -VMName $vmName -Status
                $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -match "PowerState" }).DisplayStatus
                Write-Output "Waiting for VM to start. Current state: $powerState"
            } while ($powerState -ne "VM running")
            
            Write-Output "VM $vmName is now running"
        }
        
        # Update packages using Run Command
        $updateScript = @"
#!/bin/bash
echo "Starting Linux package updates..."

# Detect distribution
if [ -f /etc/debian_version ]; then
    DISTRO="debian"
elif [ -f /etc/redhat-release ]; then
    DISTRO="redhat"
else
    echo "Unsupported distribution"
    exit 1
fi

# Update package lists and install updates
if [ "\$DISTRO" = "debian" ]; then
    echo "Detected Debian/Ubuntu system"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get upgrade -y
    apt-get autoremove -y
    apt-get autoclean
    
    # Check if reboot is required
    if [ -f /var/run/reboot-required ]; then
        echo "REBOOT_REQUIRED=true"
    else
        echo "REBOOT_REQUIRED=false"
    fi
    
elif [ "\$DISTRO" = "redhat" ]; then
    echo "Detected RedHat/CentOS/RHEL system"
    yum update -y
    yum autoremove -y
    
    # Check if reboot is required (simplified check)
    if [ \$(rpm -q --last kernel | head -1 | cut -d' ' -f1) != \$(uname -r | sed 's/-[^-]*\$//') ]; then
        echo "REBOOT_REQUIRED=true"
    else
        echo "REBOOT_REQUIRED=false"
    fi
fi

echo "Package updates completed"
"@
        
        $scriptParams = @{
            ResourceGroupName = $resourceGroupName
            VMName           = $vmName
            CommandId        = "RunShellScript"
            ScriptString     = $updateScript
        }
        
        Write-Output "Executing update script on VM: $vmName"
        $result = Invoke-AzVMRunCommand @scriptParams
        
        # Parse output
        $output = $result.Value[0].Message
        Write-Output "Update script output:`n$output"
        
        # Check if reboot is required
        $rebootRequired = $output -match "REBOOT_REQUIRED=true"
        
        if ($rebootRequired -and $RebootIfRequired) {
            Write-Output "Reboot required for VM: $vmName. Initiating reboot..."
            Restart-AzVM -ResourceGroupName $resourceGroupName -VMName $vmName -NoWait
            
            # Add tag to indicate patch completion
            $vm = Get-AzVM -ResourceGroupName $resourceGroupName -VMName $vmName
            $newTags = $vm.Tags
            $newTags["LastPatchDate"] = (Get-Date -Format "yyyy-MM-dd")
            $newTags["PatchStatus"] = "Completed-Rebooted"
            
            Set-AzResource -ResourceId $vm.Id -Tag $newTags -Force
            
        } elseif ($rebootRequired -and -not $RebootIfRequired) {
            Write-Output "Reboot required for VM: $vmName, but reboot is disabled in configuration"
            
            # Add tag to indicate patch completion but reboot pending
            $vm = Get-AzVM -ResourceGroupName $resourceGroupName -VMName $vmName
            $newTags = $vm.Tags
            $newTags["LastPatchDate"] = (Get-Date -Format "yyyy-MM-dd")
            $newTags["PatchStatus"] = "Completed-RebootPending"
            
            Set-AzResource -ResourceId $vm.Id -Tag $newTags -Force
            
        } else {
            Write-Output "No reboot required for VM: $vmName"
            
            # Add tag to indicate patch completion
            $vm = Get-AzVM -ResourceGroupName $resourceGroupName -VMName $vmName
            $newTags = $vm.Tags
            $newTags["LastPatchDate"] = (Get-Date -Format "yyyy-MM-dd")
            $newTags["PatchStatus"] = "Completed-NoReboot"
            
            Set-AzResource -ResourceId $vm.Id -Tag $newTags -Force
        }
        
        Write-Output "Successfully processed VM: $vmName"
        return $true
        
    } catch {
        Write-Error "Failed to process VM: $vmName - $($_.Exception.Message)"
        
        # Add tag to indicate patch failure
        try {
            $vm = Get-AzVM -ResourceGroupName $resourceGroupName -VMName $vmName
            $newTags = $vm.Tags
            $newTags["LastPatchAttempt"] = (Get-Date -Format "yyyy-MM-dd")
            $newTags["PatchStatus"] = "Failed"
            
            Set-AzResource -ResourceId $vm.Id -Tag $newTags -Force
        } catch {
            Write-Warning "Could not update tags for failed VM: $vmName"
        }
        
        return $false
    }
}

# Main execution
Write-Output "Starting Linux patch management runbook"
Write-Output "Parameters: ResourceGroup='$ResourceGroupName', VMName='$VMName', PatchGroup='$PatchGroup', RebootIfRequired=$RebootIfRequired, Environment='$Environment'"

# Get target VMs
$targetVMs = Get-TargetVMs -ResourceGroupName $ResourceGroupName -VMName $VMName -PatchGroup $PatchGroup -Environment $Environment

if ($targetVMs.Count -eq 0) {
    Write-Output "No VMs found matching the criteria"
    exit 0
}

Write-Output "Found $($targetVMs.Count) VMs to process"

$successCount = 0
$failureCount = 0

# Process each VM
foreach ($vm in $targetVMs) {
    if (Test-LinuxVM -VM $vm) {
        Write-Output "Processing Linux VM: $($vm.Name)"
        
        $result = Install-LinuxUpdates -VM $vm -RebootIfRequired $RebootIfRequired
        
        if ($result) {
            $successCount++
        } else {
            $failureCount++
        }
    } else {
        Write-Output "Skipping non-Linux VM: $($vm.Name)"
    }
}

Write-Output "Patch management completed"
Write-Output "Successfully processed: $successCount VMs"
Write-Output "Failed to process: $failureCount VMs"

if ($failureCount -gt 0) {
    Write-Warning "Some VMs failed to patch. Check the logs for details."
    exit 1
} else {
    Write-Output "All VMs processed successfully"
    exit 0
}