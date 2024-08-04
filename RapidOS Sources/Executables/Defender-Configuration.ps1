param (
    [string]$MyArgument
)

function EnableDefender {
    # Stop services and kill processes
    Stop-Service "wscsvc" -force -ea 0 >'' 2>''
    Stop-Process -name "OFFmeansOFF", "MpCmdRun" -force -ea 0

    # Set registry values
    $VALUES = "ServiceKeepAlive", "PreviousRunningMode", "IsServiceRunning", "DisableAntiSpyware", "DisableAntiVirus", "PassiveMode"
    $DWORDS = 0, 0, 0, 0, 0, 0
    foreach ($value in $VALUES) {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name $value -Value $DWORDS[$VALUES.IndexOf($value)] -Type DWORD -Force
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender" -Name $value -Value $DWORDS[$VALUES.IndexOf($value)] -Type DWORD -Force
    }

    # Modify registry parameters
    Reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /f
    Reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRealtimeMonitoring" /f
    Reg delete "HKLM\SOFTWARE\Microsoft\Windows Defender" /v "DisableAntiSpyware" /f 
    Reg delete "HKLM\SOFTWARE\Microsoft\Windows Defender" /v "DisableAntiVirus" /f 
    Reg delete "HKLM\SOFTWARE\Policies\Microsoft\MRT" /v "DontOfferThroughWUAU" /f 
    Reg delete "HKLM\SOFTWARE\Policies\Microsoft\MRT" /v "DontReportInfectionInformation" /f
    
    # This works for earlier versions of Windows 10/11. It's an end-of-life (EOL) trick, so it's essentially there just for show
    $services = "WinDefend", "Sense", "WdBoot", "WdFilter", "WdNisDrv", "WdNisSvc"
    foreach ($service in $services) {
    $regPath = "HKLM:\SYSTEM\ControlSet001\Services\$service"
    $startValue = (Get-ItemProperty -Path $regPath -Name "Start" -ErrorAction SilentlyContinue).Start
        if ($null -eq $startValue) {
            $startValue = 3
        }
        Set-ItemProperty -Path $regPath -Name "Start" -Value $startValue -Type DWORD -Force
    }

    # Enable Windows Defender services
    Push-Location "$env:programfiles\Windows Defender"
    $mpcmdrun = ("OFFmeansOFF.exe", "MpCmdRun.exe")[(test-path "MpCmdRun.exe")]
    Start-Process -wait $mpcmdrun -args "-EnableService -HighPriority"

    # Rename MpCmdRun.exe back to original name
    Push-Location (split-path $(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend" ImagePath -ea 0).ImagePath.Trim('"'))
    Rename-Item OFFmeansOFF.exe MpCmdRun.exe -force -ea 0

    # Update Group Policy
    gpupdate /force

    Write-Host "Microsoft Defender is enabled." -f Green
}

function DisableDefender {
    # Stop services and kill processes
    Stop-Service "wscsvc" -force -ea 0 >'' 2>''
    Stop-Process -name "OFFmeansOFF", "MpCmdRun" -force -ea 0

    # Set registry values
    $VALUES = "ServiceKeepAlive", "PreviousRunningMode", "IsServiceRunning", "DisableAntiSpyware", "DisableAntiVirus", "PassiveMode"
    $DWORDS = 0, 0, 0, 1, 1, 1
    foreach ($value in $VALUES) {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name $value -Value $DWORDS[$VALUES.IndexOf($value)] -Type DWORD -Force
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender" -Name $value -Value $DWORDS[$VALUES.IndexOf($value)] -Type DWORD -Force
    }

    # Modify registry parameters
    Reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d "1" /f
    Reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRealtimeMonitoring" /t REG_DWORD /d "1" /f
    Reg add "HKLM\SOFTWARE\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d "1" /f 
    Reg add "HKLM\SOFTWARE\Microsoft\Windows Defender" /v "DisableAntiVirus" /t REG_DWORD /d "1" /f 
    Reg add "HKLM\SOFTWARE\Policies\Microsoft\MRT" /v "DontOfferThroughWUAU" /t REG_DWORD /d "1" /f 
    Reg add "HKLM\SOFTWARE\Policies\Microsoft\MRT" /v "DontReportInfectionInformation" /t REG_DWORD /d "1" /f 
    
    # This works for earlier versions of Windows 10/11. It's an end-of-life (EOL) trick, so it's essentially there just for show
    $services = "WinDefend", "Sense", "WdBoot", "WdFilter", "WdNisDrv", "WdNisSvc"
    foreach ($service in $services) {
    $regPath = "HKLM:\SYSTEM\ControlSet001\Services\$service"
    $startValue = (Get-ItemProperty -Path $regPath -Name "Start" -ErrorAction SilentlyContinue).Start
        if ($null -eq $startValue) {
            $startValue = 4
        }
        Set-ItemProperty -Path $regPath -Name "Start" -Value $startValue -Type DWORD -Force
    }

    # Disable Windows Defender services
    Push-Location "$env:programfiles\Windows Defender"
    $mpcmdrun = ("OFFmeansOFF.exe", "MpCmdRun.exe")[(test-path "MpCmdRun.exe")]
    Start-Process -wait $mpcmdrun -args "-DisableService -HighPriority"

    # Rename MpCmdRun.exe
    Push-Location (split-path $(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend" ImagePath -ea 0).ImagePath.Trim('"'))
    Rename-Item MpCmdRun.exe OFFmeansOFF.exe -force -ea 0

    # Delete scan history
    Remove-Item "$env:ProgramData\Microsoft\Windows Defender\Scans\mpenginedb.db" -force -ea 0
    Remove-Item "$env:ProgramData\Microsoft\Windows Defender\Scans\History" -force -recurse -ea 0

    # Kill MsMpEng process
    Stop-Process -name "MsMpEng" -force -ea 0

    Write-Host "Microsoft Defender is defeated." -f Green
}

if ($MyArgument -eq "disable_windows_defender") {
    DisableDefender
} elseif ($MyArgument -eq "enable_windows_defender") {
    EnableDefender
} else {
    Write-Host "Please, use 'disable_windows_defender' to disable Defender or 'enable_windows_defender' to enable it."
}