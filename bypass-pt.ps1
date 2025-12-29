# Script to Bypass Packet Tracer Login Screen on Windows 10 & 11

<#
Tested on:
* Windows 11 25H2
* Windows 10 22H2
#>

#Requires -RunAsAdministrator
Add-Type -AssemblyName System.Windows.Forms # <-- For the open file dialog box

# Default Packet Tracer folders
$default_pt9_path = "C:\Program Files\Cisco Packet Tracer 9.0.0\bin\PacketTracer.exe"
$default_pt8_path = "C:\Program Files\Cisco Packet Tracer 8.2.2\bin\PacketTracer.exe"

$script:file_path = ""
$action = $($args[0])
$action = [string]$action

# Firewall rule names
$in_rule_name  = "Bypass Packet Tracer Login (In)"
$out_rule_name  = "Bypass Packet Tracer Login (Out)"

$script_filename = $MyInvocation.MyCommand.Name # <-- The filename of this .ps1 script

function script_help {
    Write-Host "USAGE:`n$script_filename [OPTIONAL_ARG]`n"
    Write-Host "Arguments:`n-r, -R, --remove`t-->`tRemove Firewall rules (instead of creating them)"
}

function pt_file_dialog {
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
    InitialDirectory = [Environment]::GetFolderPath('ProgramFiles')
    Title = 'Select Cisco Packet Tracer Executable File'
    Filter = 'Executable Files (*.exe)|*.exe'}

#   Prompt user to locate the .exe file of PT
    Write-Host "Please, locate Cisco Packet Tracer executable (.exe) file manually, using GUI..."; Start-Sleep 1.5
    
#   To press any key to continue
    Write-Host -NoNewLine 'Press any key to continue...'
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

    $full_path = $FileBrowser.showdialog()
    $script:file_path = $FileBrowser.filename
}

function locate_packet_tracer {
#   First try to locate PT in the default installation location
    if ( test-path $default_pt9_path ) {
        Write-Host "Detected Packet Tracer 9 in this directory: $default_pt9_path"
        Write-Host "Is this the correct one to bypass login? [Y\N]`n"
        $input_prompt = Read-Host -prompt ">>> "

        if ( $input_prompt.ToLower() -eq "y" ){
            $script:file_path = $default_pt9_path
        } else {
            Start-Sleep 1
            pt_file_dialog
        }
 
    }
    elseif ( test-path $default_pt8_path ) {
        Write-Host "Detected Packet Tracer 8 in this directory: $default_pt9_path"
        Write-Host "Is this the correct one to bypass login? [Y\N]`n"
        $input_prompt = Read-Host -prompt ">>> "

        if ( $input_prompt.ToLower() -eq "y" ){
            $script:file_path = $default_pt8_path
        } else {
            Start-Sleep 1
            pt_file_dialog
        }

    } else {
        pt_file_dialog
    }
}

function add_inbound_rule {
#   Check if the rule with the same name already exists (just in case)
    if ( get-netfirewallrule -DisplayName $in_rule_name -ErrorAction SilentlyContinue ) {
        Write-Host "Firewall rule '$in_rule_name' already exists`nShould I delete it?`n"
        Write-Host "Options:`n1: --> delete`n2: --> Skip"
        
        $input_prompt = Read-Host -prompt ">>> "
        if ( $input_prompt -eq 1 -or $input_prompt -eq "delete" ) {
            Remove-NetFirewallRule -DisplayName $in_rule_name
#           And create new rule
            New-NetFirewallRule -DisplayName $in_rule_name -Description "Bypass Login Prompt in Cisco Packet Tracer" -Direction Inbound -Program $file_path -Action Block -Profile "Any"
        } else {
#           Skip
            return
        }

    } else {
        New-NetFirewallRule -DisplayName $in_rule_name -Description "Bypass Login Prompt in Cisco Packet Tracer" -Direction Inbound -Program $file_path -Action Block -Profile "Any"
    }
}

function add_outbound_rule {
    #   Check if the rule with the same name already exists (just in case)
    if ( get-netfirewallrule -DisplayName $out_rule_name -ErrorAction SilentlyContinue ) {
        Write-Host "Firewall rule '$out_rule_name' already exists`nShould I delete it?`n"
        Write-Host "Options:`n1: --> delete`n2: --> Skip"
        
        $input_prompt = read-host -prompt ">>> "
        if ( $input_prompt -eq 1 ) {
            Remove-NetFirewallRule -DisplayName $out_rule_name
#           And add new rule
            New-NetFirewallRule -DisplayName $out_rule_name -Description "Bypass Login Prompt in Cisco Packet Tracer" -Direction Outbound -Program $file_path -Action Block -Profile "Any"
        } else {
#           Skip
            return
        }

    } else {
        New-NetFirewallRule -DisplayName $out_rule_name -Description "Bypass Login Prompt in Cisco Packet Tracer" -Direction Outbound -Program $file_path -Action Block -Profile "Any"
    }
}

function execution_policy_reminder {
    Write-Host "It is recommended to set 'ExecutionPolicy' to 'Restricted' for better security:`nSet-ExecutionPolicy Restricted"
}

function finish {
    Write-Host "Complete!`nYou can now launch Cisco Packet Tracer"
    Start-Sleep 1
    execution_policy_reminder
}

function enable_rules {
#   Inbound
    Enable-NetFirewallRule -DisplayName $in_rule_name
#   Outbound
    Enable-NetFirewallRule -DisplayName $out_rule_name
}

# In case the user needs to remove them, the rules are going to be removed by their DisplayName
function remove_rules {
#   Inbound rule
    if ( get-netfirewallrule -DisplayName $in_rule_name -ErrorAction SilentlyContinue ) {
        Remove-NetFirewallRule -DisplayName $in_rule_name
        Write-Host "Removed rule: $in_rule_name"
    } else {
        Write-Host "Rule '$in_rule_name' doesn't exist, so not removing"
    }

#   Outbound rule
    if ( get-netfirewallrule -DisplayName $out_rule_name -ErrorAction SilentlyContinue ) {
        Remove-NetFirewallRule -DisplayName $out_rule_name
        Write-Host "Removed rule: $out_rule_name"
    } else {
        Write-Host "Rule '$in_rule_name' doesn't exist, so not removing"
    }
    Write-Host ""
    execution_policy_reminder

}

function main {
    if ( $action.ToLower() -eq "-r" -or $action.ToLower() -eq "--remove" ) {
        remove_rules
        exit
    }
    elseif ( $action.ToLower() -eq "-h" -or $action.ToLower() -eq "--help" ) {
        script_help
        exit 0
    }

    try {
        locate_packet_tracer
    }
    catch {
        Write-Host "Sorry, couldn't locate Packet Tracer"
        exit
    }
    try {
        add_inbound_rule
        add_outbound_rule
    }
    catch {
        Write-Host "Sorry, there has been issue/s with adding rules"
        exit
    }
    try {
        enable_rules
    }
    catch {
        Write-Host "Sorry, couldn't enable rules"
        exit
    }
    Start-Sleep 1
    finish
    exit
}

main
