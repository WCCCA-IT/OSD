
# Establishing parameters for ZTI deployment with OSDCloud. 
# Define the image file URL to be used for installation. Image is hosted on WCCCA deployment server and is accessible via HTTP. This image is a bare Windows 11 24H2 x64 install.wim file that OSDCloud will deploy 
# to reduce network traffic and speed up deployment times.

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ImageFileUrl = 'http://deployment01.wccca.com/IPU/Media/Windows%2011%2024H2%20x64/sources/install.wim'
)

# Establish the ZTI configuration.

$startParams = @{
    ZTI          = $true
    ImageFileURL = $ImageFileUrl
}

# After the deployment, configure SetupComplete tasks to finalize installation in OOBE. 

if ($env:SystemDrive -eq 'X:') {

    # Create a log file for the SetupComplete process.
    $LogName = "OSDCloudDeployment-$((Get-Date).ToString('yyyy-MM-dd-HHmmss')).log"
    Start-Transcript -Path $env:TEMP\$LogName -Append -Force

    Write-Host "Starting $ScriptName $ScriptVersion"
    write-host "Added Function New-SetupCompleteOSDCloudFiles" -ForegroundColor Green

    # Variables to define the Windows OS / Edition etc to be applied during OSDCloud
    $Product = (Get-MyComputerProduct)
    $Model = (Get-MyComputerModel)
    $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    $OSVersion = 'Windows 11' # Used to Determine Driver Pack
    $OSReleaseID = '24H2' # Used to Determine Driver Pack

    #Set OSDCloud Variables
    $Global:MyOSDCloud = [ordered]@{
        Restart = [bool]$False
        WindowsUpdate = [bool]$true
        WindowsUpdateDrivers = [bool]$true
        WindowsDefenderUpdate = [bool]$true
    }

    # Determines Driver Packs 
    $DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

    if ($DriverPack){
        $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
    }

    if (Test-HPIASupport){
        Write-Host "Detected HP Device, Enabling HPIA, HP BIOS and HP TPM Updates"
        $Global:MyOSDCloud.HPTPMUpdate = [bool]$True
        $Global:MyOSDCloud.HPIAALL = [bool]$true
        $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true
    }

    Write-Host "OSDCloud Variables"
    Write-Output $Global:MyOSDCloud

    # Start the OSDCloud deployment process with the specified parameters.

    Write-Host -ForegroundColor Green 'Starting OSDCloud deployment (ZTI)'
    Start-OSDCloud @startParams

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
    Add-Content -path $PSFilePath "Write-Output 'iex (irm https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/Dev/CloudScripts/OSDCloudWrapperDemo.ps1)'"
    Add-Content -path $PSFilePath 'if ((Test-WebConnection) -ne $true){Write-error "No Internet, Sleeping 2 Minutes" ; start-sleep -seconds 120}'
    Add-Content -path $PSFilePath 'iex (irm https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/Dev/CloudScripts/OSDCloudWrapperDemo.ps1)'
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
    #Restart
    #restart-computer
else {
    <# This will happen from inside Setup Complete #>
    Write-Host "Starting $ScriptName $ScriptVersion"
    Write-Output "If you see this, then it worked! (Wrapper Script injected into SetupComplete)"
    #IF you want to add more things to do inside of Setup Complete, add them here!
}