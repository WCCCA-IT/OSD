<# 
.SYNOPSIS
    Configure OSDCloud Zero Touch (ZTI) deployment behavior for WCCCA and run post-deploy cleanup.

.DESCRIPTION
    - When running in WinPE (SystemDrive = X:): 
        * Starts a transcript, sets OSDCloud ZTI variables, launches ZTI, 
          writes SetupComplete cmd/ps1 wrappers, copies logs and CMTrace, 
          removes unwanted Appx packages, then restarts.
    - When running in full OS (SystemDrive = C: or other):
        * Performs a second pass of Appx removal for sanity.

.NOTES
    Script Name   : OSD-Set-ZTIConfiguration-WCCCA
    Script Version: 25.10.7.1
    Execution
        - The SetupComplete wrapper calls this script directly from GitHub.
        - Requires internet connectivity for irm calls and OSDCloud functions.
    Logging
        - Transcript is created only in WinPE phase and copied to C:\OSDCloud\Logs.
#>

$ScriptName = 'OSD-Set-ZTIConfiguration-WCCCA'
$ScriptVersion = '25.10.7.1'

#This script configures our Zero Touch deployment.
#This script also performs minor configurations after deployment and in SetupComplete.

if ($env:SystemDrive -eq 'X:') {
	
    # Create a log file for the SetupComplete process.
    $LogName = "OSDCloudDeployment-$((Get-Date).ToString('yyyy-MM-dd-HHmmss')).log"
    Start-Transcript -Path $env:TEMP\$LogName -Append -Force

    Write-Host "Starting $ScriptName $ScriptVersion"
    write-host "Added Function New-SetupCompleteOSDCloudFiles" -ForegroundColor Green

    # Define OSDCloud ZTI behavior. These keys influence actions during WinPE and SetupComplete.
    $Global:MyOSDCloud = [ordered]@{
        ImageFileURL            = 'http://deployment01.wccca.com/IPU/Media/Windows%2011%2025H2%20x64/sources/install.wim' # Install image to apply
        Restart                 = [bool]$false  # Let the wrapper own restarts; OSDCloud will not auto-restart
        RecoveryPartition       = [bool]$true   # Ensure a recovery partition exists (default true except on VMs)
        OEMActivation           = [bool]$True   # Attempt OEM activation via UEFI MSDM table during SetupComplete
        WindowsUpdate           = [bool]$true   # Apply Windows Updates during SetupComplete
        WindowsUpdateDrivers    = [bool]$true   # Pull driver updates from WU during SetupComplete
        WindowsDefenderUpdate   = [bool]$true   # Update Defender platform and signatures during SetupComplete
        SetTimeZone             = [bool]$False  # Skip geo-IP timezone set; managed elsewhere
        ClearDiskConfirm        = [bool]$False  # Skip wipe confirmation for fully unattended runs
        ShutdownSetupComplete   = [bool]$false  # After SetupComplete, proceed to OOBE (no shutdown)
        SyncMSUpCatDriverUSB    = [bool]$false  # Do not cache drivers to USB during WinPE
    }

    Write-Host "OSDCloud Variables"
    Write-Output $Global:MyOSDCloud

    # Start the OSDCloud deployment process with the specified parameters.

    Write-Host -ForegroundColor Green 'Starting OSDCloud deployment (ZTI)'
    Start-OSDCloud -ZTI

function New-SetupCompleteOSDCloudFiles{
    <#
		.SYNOPSIS
            Create SetupComplete wrappers that call the latest script from GitHub post-deployment.
        .DETAILS
    	    - Writes SetupComplete.cmd to invoke SetupComplete.ps1 with ExecutionPolicy bypass.
			- Writes SetupComplete.ps1 that fetches and runs this script from GitHub.
            - Backs up any existing SetupComplete.ps1.
    #>
    $SetupCompletePath = "C:\OSDCloud\Scripts\SetupComplete"
    $ScriptsPath = $SetupCompletePath

    if (!(Test-Path -Path $ScriptsPath)){New-Item -Path $ScriptsPath -ItemType Directory -Force | Out-Null}

    $RunScript = @(@{ Script = "SetupComplete"; BatFile = 'SetupComplete.cmd'; ps1file = 'SetupComplete.ps1';Type = 'Setup'; Path = "$ScriptsPath"})

    Write-Output "Creating $($RunScript.Script) Files in $SetupCompletePath"

    $BatFilePath = "$($RunScript.Path)\$($RunScript.batFile)"
    $PSFilePath = "$($RunScript.Path)\$($RunScript.ps1File)"
            
    #Create Batch File to Call PowerShell File
    if (Test-Path -Path $PSFilePath){
        copy-item $PSFilePath -Destination "$ScriptsPath\SetupComplete.ps1.bak"
    }        
    New-Item -Path $BatFilePath -ItemType File -Force
    $CustomActionContent = New-Object system.text.stringbuilder
    [void]$CustomActionContent.Append('%windir%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy ByPass -File C:\OSDCloud\Scripts\SetupComplete\SetupComplete.ps1')
    Add-Content -Path $BatFilePath -Value $CustomActionContent.ToString()

    #Create PowerShell File to do actions

    New-Item -Path $PSFilePath -ItemType File -Force
    Add-Content -path $PSFilePath "Write-Output 'Starting SetupComplete OSDCloudWrapperDemo Script Process'"
    Add-Content -path $PSFilePath "Write-Output 'iex (irm https://raw.githubusercontent.com/WCCCA-IT/OSD/refs/heads/main/OSD-Set-ZTIConfiguration-WCCCA.ps1)'"
    Add-Content -path $PSFilePath 'if ((Test-WebConnection) -ne $true){Write-error "No Internet, Sleeping 2 Minutes" ; start-sleep -seconds 120}'
    Add-Content -path $PSFilePath 'iex (irm https://raw.githubusercontent.com/WCCCA-IT/OSD/refs/heads/main/OSD-Set-ZTIConfiguration-WCCCA.ps1)'
}

    Write-Host "==================================================" -ForegroundColor DarkGray
    Write-Host "OSDCloud Process Complete, Running Custom Actions From Script Before Reboot" -ForegroundColor Magenta
    Write-Host "Creating Custom SetupComplete Files for this deployment" -ForegroundColor Cyan

    New-SetupCompleteOSDCloudFiles
    #Copy CMTrace Local if in WinPE Media
    if (Test-path -path "x:\windows\system32\cmtrace.exe"){
        copy-item "x:\windows\system32\cmtrace.exe" -Destination "C:\Windows\System\cmtrace.exe" -verbose
    }
        #Copy Logs if available
    if (Test-Path -Path $env:TEMP\$LogName){
        Write-Host -ForegroundColor DarkGray "Copying Log to C:\OSDCloud\Logs"
        Stop-Transcript
        Copy-Item -Path $env:TEMP\$LogName -Destination C:\OSDCloud\Logs -Force
    }

    # Load OSDCloud helper functions into session to remove inbox apps by name.
    iex (irm functions.osdcloud.com)

	$AutopilotParams = @{
    Online = $true
    TenantId = '109c7a39-3998-4b2b-b6d7-56f02b27eec0'
    AppId = 'b7284c30-50f0-4330-95e1-b13c276331ba'
    AppSecret = 'sX38Q~pHfvabE7.H-Bf5vQNEJw~PciHzrfAK-c7G'
    GroupTag = 'IT'
	}
	
	Get-WindowsAutoPilotInfo @AutopilotParams
	
    # Appx packages to remove for a leaner base image. Names map to Appx package family names used by RemoveAppx.
    $AppsToRemove = @(
        'Clipchamp.Clipchamp'
        'FeedbackHub'
        'Microsoft.BingNews'
        'Microsoft.BingSearch'
        'Microsoft.BingWeather'
        'Microsoft.GamingApp'
        'Microsoft.GetHelp'
        'Microsoft.MicrosoftOfficeHub'
        'Microsoft.MicrosoftSolitaireCollection'
        'Microsoft.MicrosoftStickyNotes'
        'Microsoft.OutlookForWindows'
        'Microsoft.Paint'
        'Microsoft.PowerAutomateDesktop'
        'Microsoft.WindowsSoundRecorder'
        'Microsoft.Xbox.TCUI'
        'Microsoft.XboxIdentityProvider'
        'Microsoft.XboxSpeechToTextOverlay'
        'Microsoft.YourPhone'
        'Microsoft.ZuneMusic'
        'MSTeams'
    )

    # Remove selected Appx packages in WinPE phase before reboot to OOBE.
    RemoveAppx -Name $AppsToRemove

    # Hand control back to OOBE by forcing a restart.
    Restart-Computer -Force
}

else {
    # In full OS. SetupComplete.cmd invoked this branch. Perform a second pass of app cleanup.
    Write-Host "Starting $ScriptName $ScriptVersion"

    # Load OSDCloud helper functions again in the full OS context.
    iex (irm functions.osdcloud.com)

	#Register for Autopilot
	$AutopilotParams = @{
    Online = $true
    TenantId = '109c7a39-3998-4b2b-b6d7-56f02b27eec0'
    AppId = 'b7284c30-50f0-4330-95e1-b13c276331ba'
    AppSecret = 'sX38Q~pHfvabE7.H-Bf5vQNEJw~PciHzrfAK-c7G'
    GroupTag = 'IT'
	}
	
	Get-WindowsAutoPilotInfo @AutopilotParams
	
    # Same removal list as in WinPE to ensure drift is corrected.
    $AppsToRemove = @(
        'Clipchamp.Clipchamp'
        'FeedbackHub'
        'Microsoft.BingNews'
        'Microsoft.BingSearch'
        'Microsoft.BingWeather'
        'Microsoft.GamingApp'
        'Microsoft.GetHelp'
        'Microsoft.MicrosoftOfficeHub'
        'Microsoft.MicrosoftSolitaireCollection'
        'Microsoft.MicrosoftStickyNotes'
        'Microsoft.OutlookForWindows'
        'Microsoft.Paint'
        'Microsoft.PowerAutomateDesktop'
        'Microsoft.WindowsSoundRecorder'
        'Microsoft.Xbox.TCUI'
        'Microsoft.XboxIdentityProvider'
        'Microsoft.XboxSpeechToTextOverlay'
        'Microsoft.YourPhone'
        'Microsoft.ZuneMusic'
        'MSTeams'
    )

    # Remove selected Appx packages in the full OS in case any reappeared or failed to remove earlier.
    RemoveAppx -Name $AppsToRemove
}
