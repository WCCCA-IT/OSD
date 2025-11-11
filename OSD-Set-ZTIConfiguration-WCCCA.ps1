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

    #Set OSDCloud Variables
    $Global:MyOSDCloud = [ordered]@{
        ImageFileURL = 'http://deployment01.wccca.com/IPU/Media/Windows%2011%2025H2%20x64/sources/install.wim'
		Reboot = [bool]$False
        OEMActivation = [bool]$True
	    RecoveryPartition = [bool]$true
        WindowsUpdate = [bool]$true
        ShutdownSetupComplete = [bool]$true
        WindowsUpdateDrivers = [bool]$true
        WindowsDefenderUpdate = [bool]$true
	    ClearDiskConfirm = [bool]$false
        CheckSHA1 = [bool]$true
    }

    Write-Host "OSDCloud Variables"
    Write-Output $Global:MyOSDCloud

    # Start the OSDCloud deployment process with the specified parameters.

    Write-Host -ForegroundColor Green 'Starting OSDCloud deployment (ZTI)'
    Start-OSDCloud -ZTI

function New-SetupCompleteOSDCloudFiles{
    
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
    Write-Host "Creating Custom SetupComplete Files for WCCCA" -ForegroundColor Cyan

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

	#Invoke OSDCloud functions for easy removal of applications in Windows OS
	iex (irm functions.osdcloud.com)
	
		# OSDCloud RemoveAppx
# OSDCloud RemoveAppx
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

	RemoveAppx -Name $AppsToRemove

	#Performing restart
	Restart-Computer -Force
}

#This portion occurs when SetupComplete.cmd is triggered after Pre-Provisioning Autopilot. 
#Since the endpoint will be in C: as opposed to X: in WinPE, this part of the script will trigger.
else {
    Write-Host "Starting $ScriptName $ScriptVersion"

	#Invoke OSDCloud functions for easy removal of applications in Windows OS.
	#Performing another pass-through as a sanity check.
	
	iex (irm functions.osdcloud.com)
	
# OSDCloud RemoveAppx
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

RemoveAppx -Name $AppsToRemove

}
