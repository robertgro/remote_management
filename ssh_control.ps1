param (
    [int]$connectTimeout = 1
)

$config = Get-Content ./ssh_control.cfg.json | ConvertFrom-Json
$clients = @()

foreach($item in $config.clients.PSObject.Properties) {
    $client = [PSCustomObject]@{Name = $item.Name }
    $item.Value.PSObject.Properties | ForEach-Object { $client | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value }
    $clients += $client
}

do {
    Write-Host #empty line
    Write-Host "`tSSH CLIENT SELECTION " -ForegroundColor Cyan
    Write-Host
    for($i=0; $i -lt $clients.Length; $i++) {
        (ping -n 1 -w 100 $clients[$i].ip 2>&1) | Out-Null
        $responseCode = $LASTEXITCODE
        Write-Host "`t$($i+1). $($clients[$i].Name)" -ForegroundColor Cyan
        if($responseCode -eq 0) {
            Write-Host "`t`tStatus: $($clients[$i].Name) ONLINE" -ForegroundColor Green
        } else {
            Write-Host "`t`tStatus: $($clients[$i].Name) OFFLINE" -ForegroundColor DarkRed
        }
    }
    Write-Host #empty line
    try {
        $answer = (Read-Host "`tSelect a SSH Client to connect to") -as [int]
        Write-Host #empty line
    } catch {
        Write-Error "`tPlease specify a valid number and hit [Enter] key"
    }

} While ((-not($answer)) -or (0 -gt $answer) -or ($clients.Count -lt $answer))

$answer -= 1

if (!($username = Read-Host "`tHit [Enter] to login as admin or [r] for being the root user")) { $username = [string]::Empty }

if($username -and ($username -match "r")) {
    $username = "root"
} else {
    $username = "admin"
}

if (!($port = Read-Host "`tPress [Enter] to connect on port 22 or specify a custom port here")) { $port = 22 }

if (!($sessiontype = Read-Host "`tType [Enter] for CMD or [ps] for a Powershell session")) { $sessiontype = [string]::Empty }

Write-Host

if($sessiontype -and ($sessiontype -match "ps")) {
    if($port -ne 22) {
        # ssh returns with exit 255 if failed, e.g. timeout
        # -q quiet switch https://man.openbsd.org/ssh
        # capture exe stdout by redirect https://stackoverflow.com/questions/12048906/capturing-ssh-output-as-variable-in-bash-script
        # -o ConnectTimeout keep it fast https://stackoverflow.com/questions/4936807/how-to-set-ssh-timeout
        # -o StrictHostKeyChecking skip known host check by override cfg option https://superuser.com/questions/125324/how-can-i-avoid-sshs-host-verification-for-known-hosts
        (ssh -q -o "ConnectTimeout=$connectTimeout" -o "StrictHostKeyChecking no" $username@$($clients[$answer].ip) -p $port exit 2>&1)
        if ($LASTEXITCODE -ne 0) {
            Write-Error "HostTimeOutException", $LASTEXITCODE, $($clients[$answer].ip), $username, $connectTimeout, $port
            exit $LASTEXITCODE
        }
        ssh $username@$($clients[$answer].ip) -p $port powershell -NoLogo

    } else {
        (ssh -q -o "ConnectTimeout=$connectTimeout" -o "StrictHostKeyChecking no" $username@$($clients[$answer].ip) exit 2>&1)
        if ($LASTEXITCODE -ne 0) {
            Write-Error "HostTimeOutException", $LASTEXITCODE, $($clients[$answer].ip), $username, $connectTimeout, $port
            exit $LASTEXITCODE
        }
        ssh $username@$($clients[$answer].ip) powershell -NoLogo
    }
} else {
    if($port -ne 22) {
        (ssh -q -o "ConnectTimeout=$connectTimeout" -o "StrictHostKeyChecking no" $username@$($clients[$answer].ip) -p $port exit 2>&1)
        if ($LASTEXITCODE -ne 0) {
            Write-Error "HostTimeOutException", $LASTEXITCODE, $($clients[$answer].ip), $username, $connectTimeout, $port
            exit $LASTEXITCODE
        }
        ssh $username@$($clients[$answer].ip) -p $port
        
    } else {
        (ssh -q -o "ConnectTimeout=$connectTimeout" -o "StrictHostKeyChecking no" $username@$($clients[$answer].ip) -p $port exit 2>&1)
        if ($LASTEXITCODE -ne 0) {
            Write-Error "HostTimeOutException", $LASTEXITCODE, $($clients[$answer].ip), $username, $connectTimeout, $port
            exit $LASTEXITCODE
        }
        ssh $username@$($clients[$answer].ip)
    }
}