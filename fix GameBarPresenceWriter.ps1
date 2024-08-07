<#
.NOTES
Author: Ibrahim
Website: https://ibrpride.com
Script Version: 1.2
Last Updated: July 2024
#>

# Check if running as administrator; if not, restart as admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting script with elevated privileges..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
}

# Set console colors
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.PrivateData.ProgressBackgroundColor = "Black"
$Host.PrivateData.ProgressForegroundColor = "White"
Clear-Host

# Function to handle registry commands
function Invoke-RegistryCommand {
    param(
        [string]$Command,
        [string]$Path,
        [string]$Name,
        [string]$Type,
        [string]$Data
    )

    $fullCommand = "Reg.exe {0} `{1}` /v `{2}` /t {3} /d `{4}` /f" -f $Command, $Path, $Name, $Type, $Data

    try {
        Write-Host "Running command:" -ForegroundColor Cyan
        Write-Host $fullCommand
        Invoke-Expression $fullCommand | Out-Null
        Write-Host "Command completed successfully." -ForegroundColor Green
    } catch {
        Write-Host "Error executing command: $_" -ForegroundColor Red
    }
}

# Function to take ownership and rename file
function TakeOwnershipAndRename {
    Write-Host "Taking ownership of the file and renaming..." -ForegroundColor Cyan
    $filePath = "C:\Windows\System32\GameBarPresenceWriter.exe"
    $newFileName = "C:\Windows\System32\GameBarPresenceWriter.exe.old"

    # Take ownership
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c takeown /f $filePath" -Wait -NoNewWindow

    # Grant full control
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c icacls $filePath /grant %USERDOMAIN%\%USERNAME%:F" -Wait -NoNewWindow

    # Rename file
    Rename-Item -Path $filePath -NewName $newFileName -ErrorAction Stop

    Write-Output "Ownership taken and file renamed to $newFileName"
}

# Function to revert changes
function RevertChanges {
    Write-Host "Reverting changes..." -ForegroundColor Cyan
    $newFileName = "C:\Windows\System32\GameBarPresenceWriter.exe.old"
    $originalFileName = "C:\Windows\System32\GameBarPresenceWriter.exe"

    # Rename file back to original
    Rename-Item -Path $newFileName -NewName $originalFileName -ErrorAction Stop

    # Restore ownership to TrustedInstaller
    $acl = Get-Acl $originalFileName
    $owner = New-Object System.Security.Principal.NTAccount("NT SERVICE\TrustedInstaller")
    $acl.SetOwner($owner)
    Set-Acl $originalFileName $acl

    # Grant full control to TrustedInstaller
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c icacls $originalFileName /setowner `"NT SERVICE\TrustedInstaller`"" -Wait -NoNewWindow
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c icacls $originalFileName /grant `"NT SERVICE\TrustedInstaller`":(F)" -Wait -NoNewWindow

    Write-Output "File ownership and permissions reverted to TrustedInstaller and renamed back to original."
}

# Function to disable FSO and Game Bar support
function DisableFSOAndGameBarSupport {
    Write-Host "Disabling FSO and Game Bar Support..." -ForegroundColor Cyan

    $commands = @(
        @{ Command = "Add"; Path = "HKCU\System\GameConfigStore"; Name = "GameDVR_DSEBehavior"; Type = "REG_DWORD"; Data = "2" },
        @{ Command = "Add"; Path = "HKCU\System\GameConfigStore"; Name = "GameDVR_DXGIHonorFSEWindowsCompatible"; Type = "REG_DWORD"; Data = "1" },
        @{ Command = "Add"; Path = "HKCU\System\GameConfigStore"; Name = "GameDVR_EFSEFeatureFlags"; Type = "REG_DWORD"; Data = "0" },
        @{ Command = "Add"; Path = "HKCU\System\GameConfigStore"; Name = "GameDVR_FSEBehavior"; Type = "REG_DWORD"; Data = "2" },
        @{ Command = "Add"; Path = "HKCU\System\GameConfigStore"; Name = "GameDVR_FSEBehaviorMode"; Type = "REG_DWORD"; Data = "2" },
        @{ Command = "Add"; Path = "HKCU\System\GameConfigStore"; Name = "GameDVR_HonorUserFSEBehaviorMode"; Type = "REG_DWORD"; Data = "1" },
        @{ Command = "Add"; Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; Name = "__COMPAT_LAYER"; Type = "REG_SZ"; Data = "~DISABLEDXMAXIMIZEDWINDOWEDMODE" },
        @{ Command = "Add"; Path = "HKCU\System\GameBar"; Name = "GamePanelStartupTipIndex"; Type = "REG_DWORD"; Data = "3" },
        @{ Command = "Add"; Path = "HKCU\System\GameBar"; Name = "ShowStartupPanel"; Type = "REG_DWORD"; Data = "0" },
        @{ Command = "Add"; Path = "HKCU\System\GameBar"; Name = "UseNexusForGameBarEnabled"; Type = "REG_DWORD"; Data = "0" },
        @{ Command = "Add"; Path = "HKLM\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter"; Name = "ActivationType"; Type = "REG_DWORD"; Data = "0" },
        @{ Command = "Add"; Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name = "AllowGameDVR"; Type = "REG_DWORD"; Data = "0" },
        @{ Command = "Add"; Path = "HKLM\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR"; Name = "value"; Type = "REG_DWORD"; Data = "0" },
        @{ Command = "Add"; Path = "HKCU\System\GameConfigStore"; Name = "GameDVR_Enabled"; Type = "REG_DWORD"; Data = "0" },
        @{ Command = "Add"; Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "AppCaptureEnabled"; Type = "REG_DWORD"; Data = "0" }
    )

    foreach ($cmd in $commands) {
        Invoke-RegistryCommand -Command $cmd.Command -Path $cmd.Path -Name $cmd.Name -Type $cmd.Type -Data $cmd.Data
    }

    Write-Output "FSO and Game Bar Support disabled."
}

# Function to enable FSO and Game Bar support
function EnableFSOAndGameBarSupport {
    Write-Host "Enabling FSO and Game Bar Support..." -ForegroundColor Cyan

    $commands = @(
        @{ Command = "Delete"; Path = "HKCU\System\GameConfigStore"; Name = "GameDVR_DSEBehavior"; Type = "REG_DWORD"; Data = "" },
        @{ Command = "Add"; Path = "HKCU\System\GameConfigStore"; Name = "GameDVR_DXGIHonorFSEWindowsCompatible"; Type = "REG_DWORD"; Data = "0" },
        @{ Command = "Add"; Path = "HKCU\System\GameConfigStore"; Name = "GameDVR_EFSEFeatureFlags"; Type = "REG_DWORD"; Data = "0" },
        @{ Command = "Delete"; Path = "HKCU\System\GameConfigStore"; Name = "GameDVR_FSEBehavior"; Type = "REG_DWORD"; Data = "" },
        @{ Command = "Add"; Path = "HKCU\System\GameConfigStore"; Name = "GameDVR_FSEBehaviorMode"; Type = "REG_DWORD"; Data = "2" },
        @{ Command = "Add"; Path = "HKCU\System\GameConfigStore"; Name = "GameDVR_HonorUserFSEBehaviorMode"; Type = "REG_DWORD"; Data = "0" },
        @{ Command = "Delete"; Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; Name = "__COMPAT_LAYER"; Type = "REG_SZ"; Data = "" },
        @{ Command = "Delete"; Path = "HKCU\System\GameBar"; Name = "GamePanelStartupTipIndex"; Type = "REG_DWORD"; Data = "" },
        @{ Command = "Delete"; Path = "HKCU\System\GameBar"; Name = "ShowStartupPanel"; Type = "REG_DWORD"; Data = "" },
        @{ Command = "Delete"; Path = "HKCU\System\GameBar"; Name = "UseNexusForGameBarEnabled"; Type = "REG_DWORD"; Data = "" },
        @{ Command = "Add"; Path = "HKLM\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter"; Name = "ActivationType"; Type = "REG_DWORD"; Data = "1" },
        @{ Command = "Add"; Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name = "AllowGameDVR"; Type = "REG_DWORD"; Data = "1" },
        @{ Command = "Add"; Path = "HKLM\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR"; Name = "value"; Type = "REG_DWORD"; Data = "1" },
        @{ Command = "Add"; Path = "HKCU\System\GameConfigStore"; Name = "GameDVR_Enabled"; Type = "REG_DWORD"; Data = "1" },
        @{ Command = "Delete"; Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "AppCaptureEnabled"; Type = "REG_DWORD"; Data = "" }
    )

    foreach ($cmd in $commands) {
        Invoke-RegistryCommand -Command $cmd.Command -Path $cmd.Path -Name $cmd.Name -Type $cmd.Type -Data $cmd.Data
    }

    Write-Output "FSO and Game Bar Support enabled."
}

# Main script logic
Write-Host "Choose an option:" -ForegroundColor Yellow
Write-Host "1. Disable the GameBarPresenceWriter file." -ForegroundColor Yellow
Write-Host "2. Revert the changes." -ForegroundColor Yellow
Write-Host "3. Goto next." -ForegroundColor Yellow
$choice = Read-Host "Enter your choice (1/2/3)"

switch ($choice) {
    "1" {
        TakeOwnershipAndRename
    }
    "2" {
        RevertChanges
    }
    "3" {
        Write-Host "No modifications made."
        
    }
    default {
        Write-Host "Invalid choice. No action taken."
    }
}

Write-Host "Choose an option for FSO and Game Bar support:" -ForegroundColor Yellow
Write-Host "1. Disable FSO and Game Bar support." -ForegroundColor Yellow
Write-Host "2. Enable FSO and Game Bar support." -ForegroundColor Yellow
Write-Host "3. Revert to previous settings." -ForegroundColor Yellow
$choice = Read-Host "Enter your choice (1/2/3)"

switch ($choice) {
    "1" {
        DisableFSOAndGameBarSupport
    }
    "2" {
        EnableFSOAndGameBarSupport
    }
    "3" {
        Write-Host "No changes made."
    }
    default {
        Write-Host "Invalid choice. No action taken."
    }
}

# Pause the script to view the output
Write-Host "Press any key to exit..." -ForegroundColor Yellow
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
