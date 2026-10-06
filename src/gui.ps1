# ============================================================
#  PartageCOM - partage d'un port serie vers deux ports virtuels
#  com0com (pilote) et hub4com (hub) sont INCLUS dans ce fichier
#  et s'installent automatiquement au premier clic sur MARCHE.
#  Chaque etape est verifiee : le script peut etre relance autant
#  de fois que necessaire, meme si une partie est deja faite.
# ============================================================
$ErrorActionPreference = "Stop"
$script:BatPath = $env:PARTAGECOM_BAT
$script:LogFile = [IO.Path]::ChangeExtension($script:BatPath, ".log")

function LogFile($msg) {
    try { Add-Content -Path $script:LogFile -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg) -Encoding UTF8 } catch {}
}

# Ne conserve dans le journal que les lignes des 7 derniers jours (nettoyage au demarrage).
function Prune-Log {
    if (-not (Test-Path $script:LogFile)) { return }
    try {
        $cutoff = (Get-Date).AddDays(-7)
        $lines = Get-Content -Path $script:LogFile -ErrorAction Stop
        $keep = New-Object System.Collections.Generic.List[string]
        $keeping = $true
        foreach ($ln in $lines) {
            $m = [regex]::Match($ln, '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]')
            if ($m.Success) {
                try { $dt = [datetime]::ParseExact($m.Groups[1].Value, 'yyyy-MM-dd HH:mm:ss', $null); $keeping = ($dt -ge $cutoff) } catch { $keeping = $true }
            }
            if ($keeping) { $keep.Add($ln) }
        }
        Set-Content -Path $script:LogFile -Value $keep -Encoding UTF8
    } catch {}
}
Prune-Log

# Masquer la console cmd (elle est reaffichee en cas d'erreur fatale)
Add-Type -Name Win -Namespace Console -MemberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
$script:ConsoleHwnd = [Console.Win]::GetConsoleWindow()
[Console.Win]::ShowWindow($script:ConsoleHwnd, 0) | Out-Null

LogFile "---- Demarrage ($script:BatPath) ----"

# --- Elevation en administrateur ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    LogFile "Pas administrateur : relance avec elevation."
    try {
        Start-Process cmd.exe -Verb RunAs -WindowStyle Hidden -ArgumentList ('/c ""' + $script:BatPath + '" ' + $env:PARTAGECOM_AUTO + '"')
    } catch {
        LogFile "Elevation refusee ou impossible : $($_.Exception.Message)"
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("L'application a besoin des droits administrateur (necessaires a com0com). Relancez et acceptez la demande Windows.", "PartageCOM - F5PBG", "OK", "Warning") | Out-Null
    }
    exit 0
}
LogFile "Administrateur : OK"

try {
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:configFile = [IO.Path]::ChangeExtension($script:BatPath, ".json")
$script:proc = $null

function Find-Com0comDir {
    foreach ($d in @("C:\Program Files (x86)\com0com", "C:\Program Files\com0com")) {
        if (Test-Path (Join-Path $d "setupc.exe")) { return $d }
    }
    return "C:\Program Files (x86)\com0com"
}

$cfg = @{ PortRadio = "COM5"; Virtuel1 = 14; Virtuel2 = 15; Virtuel3 = 0; Virtuel4 = 0; Virtuel5 = 0; Baud = 38400; BTId = ""; AutoBT = $false; AutoBTHours = 6; TopMost = $false }
if (Test-Path $script:configFile) {
    try {
        $saved = Get-Content $script:configFile -Raw | ConvertFrom-Json
        foreach ($p in $saved.PSObject.Properties) { $cfg[$p.Name] = $p.Value }
    } catch {}
}

function Save-Config {
    $cfg.PortRadio = $cbRadio.Text
    $cfg.Virtuel1  = Get-VPort $cbV1
    $cfg.Virtuel2  = Get-VPort $cbV2
    $cfg.Virtuel3  = Get-VPort $cbV3
    $cfg.Virtuel4  = Get-VPort $cbV4
    $cfg.Virtuel5  = Get-VPort $cbV5
    $cfg.Baud      = [int]$cbBaud.Text
    $cfg.BTId      = $txtBTId.Text.Trim()
    $cfg.AutoBT     = $chkAutoBT.Checked
    $cfg.AutoBTHours = [int]$cbAutoBTHours.Text
    $cfg.TopMost    = $chkTop.Checked
    try { $cfg | ConvertTo-Json | Set-Content $script:configFile -Encoding UTF8 } catch {}
}

function Log($msg) {
    LogFile $msg
    $txtLog.AppendText(("[{0}] {1}`r`n" -f (Get-Date -Format "HH:mm:ss"), $msg))
    [System.Windows.Forms.Application]::DoEvents()
}

function Get-SerialPorts {
    $ports = @([System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object { [int]($_ -replace '\D','') } -Unique)
    if ($ports.Count -eq 0) { $ports = @("COM5") }
    return $ports
}

# --- Extraction des binaires embarques dans le .bat ---
function Extract-Embedded($name, $dest) {
    $lines = [IO.File]::ReadAllLines($script:BatPath)
    $a = [Array]::IndexOf($lines, "#B64_${name}_BEGIN")
    $b = [Array]::IndexOf($lines, "#B64_${name}_END")
    if ($a -lt 0 -or $b -lt 0) { throw "Bloc $name introuvable dans le fichier .bat (fichier incomplet ?)" }
    $bytes = [Convert]::FromBase64String(($lines[($a+1)..($b-1)] -join ''))
    [IO.File]::WriteAllBytes($dest, $bytes)
}

function Install-Components {
    $tmp = Join-Path $env:TEMP "PartageCOM_setup"
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $dir = Find-Com0comDir

    if (-not (Test-Path (Join-Path $dir "setupc.exe"))) {
        $arch = if ([Environment]::Is64BitOperatingSystem) { "COM0COM_X64" } else { "COM0COM_X86" }
        $setup = Join-Path $tmp "com0com_setup.exe"
        Log "Extraction de l'installeur com0com ($arch)..."
        Extract-Embedded $arch $setup
        Log "Installation silencieuse de com0com (pilote signe v3.0.0.0)..."
        Log "Si Windows demande d'autoriser le pilote, acceptez."
        $p = Start-Process -FilePath $setup -ArgumentList "/S" -Wait -PassThru
        Log "Installeur termine (code $($p.ExitCode))."
        Start-Sleep -Seconds 2
        $dir = Find-Com0comDir
        if (-not (Test-Path (Join-Path $dir "setupc.exe"))) { throw "com0com ne semble pas installe. Relancez ou installez-le manuellement." }
    } else { Log "com0com deja installe dans $dir" }

    # IMPORTANT : setupc.exe cherche com0com.inf / cncport.inf dans le repertoire COURANT
    # (d'ou l'erreur "SetupOpenInfFile(C:\Windows\system32\cncport.inf) ERROR: 2" si on le
    # lance depuis ailleurs). On se place donc toujours dans le dossier com0com avant.
    Log "Verification du pilote (setupc preinstall)..."
    $pre = Run-Setupc $dir @("--silent", "preinstall")
    if ($pre.Trim()) { Log $pre.Trim() }
    $chk = Run-Setupc $dir @("--silent", "list")
    if ($chk -match "ERROR") {
        Log "Le pilote n'est pas operationnel. Lancement de l'installeur com0com en mode normal :"
        Log "cliquez sur Next/Install dans la fenetre qui s'ouvre, puis Finish."
        $arch = if ([Environment]::Is64BitOperatingSystem) { "COM0COM_X64" } else { "COM0COM_X86" }
        $setup = Join-Path $tmp "com0com_setup.exe"
        Extract-Embedded $arch $setup
        Start-Process -FilePath $setup -Wait | Out-Null
        Start-Sleep -Seconds 2
        $dir = Find-Com0comDir
    }

    $hub = Join-Path $dir "hub4com.exe"
    if (-not (Test-Path $hub)) {
        Log "Extraction de hub4com.exe vers $dir ..."
        Extract-Embedded "HUB4COM" $hub
    } else { Log "hub4com.exe deja present." }
    return $dir
}

function Hub-Name($n) { return "HUB$n" }

# Execute setupc.exe DEPUIS le dossier com0com (indispensable, voir plus haut)
function Run-Setupc($dir, $arguments) {
    Push-Location $dir
    try { $out = & (Join-Path $dir "setupc.exe") @arguments 2>&1 | Out-String }
    finally { Pop-Location }
    return $out
}

function Ensure-Pair($dir, $n) {
    if ($n -lt 11) { throw "Le port COM$n est trop bas : utilisez un numero >= 11." }
    $list = Run-Setupc $dir @("--silent", "list")
    if ($list -match "PortName=COM$n\b") {
        Log "Paire COM$n deja presente."
        # Corriger les paires creees avec EmuOverrun=yes (perte de caracteres si le logiciel
        # ne lit pas assez vite -> deconnexions). On passe les deux cotes en EmuOverrun=no.
        foreach ($m in [regex]::Matches($list, "(CNC[AB]\d+)\s+PortName=(COM$n|$(Hub-Name $n))\b[^\r\n]*")) {
            # Forcer les deux cotes a la valeur de latence minimale : EmuBR=no, EmuOverrun=no
            if ($m.Value -match "EmuBR=yes" -or $m.Value -match "EmuOverrun=yes") {
                $id = $m.Groups[1].Value
                Log "Correction de $id ($($m.Groups[2].Value)) : EmuBR=no, EmuOverrun=no"
                $out = Run-Setupc $dir @("--silent", "change", $id, "EmuBR=no,EmuOverrun=no")
                if ($out.Trim()) { Log $out.Trim() }
            }
        }
        return
    }
    Log "Creation de la paire COM$n <-> $(Hub-Name $n) ..."
    $out = Run-Setupc $dir @("--silent", "install", "PortName=COM$n,EmuBR=no,EmuOverrun=no", "PortName=$(Hub-Name $n),EmuBR=no,EmuOverrun=no")
    if ($out.Trim()) { Log $out.Trim() }
    if ($out -match "ERROR") { throw "La creation de la paire COM$n a echoue (voir journal)." }
    Start-Sleep -Seconds 2
    $list = Run-Setupc $dir @("--silent", "list")
    if ($list -notmatch "PortName=COM$n\b") { throw "La paire COM$n n'apparait pas apres creation." }
}

function Start-Partage {
    try {
        Save-Config
        $vports = @()
        foreach ($c in @($cbV1, $cbV2, $cbV3, $cbV4, $cbV5)) { $v = Get-VPort $c; if ($v -gt 0) { $vports += $v } }
        if ($vports.Count -lt 2) { throw "Choisissez au moins les deux premiers ports virtuels." }
        if (($vports | Select-Object -Unique).Count -ne $vports.Count) { throw "Les ports virtuels doivent etre tous differents." }
        foreach ($v in $vports) { if ("COM$v" -eq $cbRadio.Text) { throw "Un port virtuel ne peut pas etre le port radio." } }

        $dir = Install-Components
        $hub = Join-Path $dir "hub4com.exe"
        foreach ($v in $vports) { Ensure-Pair $dir $v }

        $hubPorts = ($vports | ForEach-Object { "\\.\$(Hub-Name $_)" }) -join " "
        $hubArgs = "--baud=$($cbBaud.Text) --octs=off --odsr=off --ox=off --ix=off --route=0:All --route=All:0 \\.\$($cbRadio.Text) $hubPorts"
        Log "hub4com $hubArgs"
        $script:proc = Start-Process -FilePath $hub -ArgumentList $hubArgs -WindowStyle Hidden -PassThru
        Start-Sleep -Milliseconds 800
        if ($script:proc.HasExited) { throw "hub4com s'est arrete immediatement (port radio deja ouvert par un autre logiciel ? debit incorrect ?)" }

        Log "Partage ACTIF : $($cbRadio.Text) -> $(($vports | ForEach-Object { "COM$_" }) -join ', ') a $($cbBaud.Text) bauds."
        Set-Etat $true
    } catch {
        Log "ERREUR : $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "PartageCOM - F5PBG", "OK", "Error") | Out-Null
        Set-Etat $false
    }
}

function Stop-Partage {
    if ($script:proc -and -not $script:proc.HasExited) {
        $script:proc.Kill()
        $script:proc.WaitForExit(3000) | Out-Null
    }
    $script:proc = $null
    Log "Partage arrete."
    Set-Etat $false
    Refresh-VirtualLists
}

function Set-Etat($on) {
    if ($on) {
        $btnOnOff.Text = "ARRET"
        $btnOnOff.BackColor = [System.Drawing.Color]::FromArgb(200, 60, 60)
        $lblEtat.Text = "Partage actif"
        $lblEtat.ForeColor = [System.Drawing.Color]::DarkGreen
    } else {
        $btnOnOff.Text = "MARCHE"
        $btnOnOff.BackColor = [System.Drawing.Color]::FromArgb(60, 160, 60)
        $lblEtat.Text = "Partage inactif"
        $lblEtat.ForeColor = [System.Drawing.Color]::DarkRed
    }
    foreach ($c in @($cbRadio, $cbV1, $cbV2, $cbV3, $cbV4, $cbV5, $cbBaud, $btnRefresh)) { $c.Enabled = -not $on }
}

# --- Demarrage automatique (tache planifiee, droits admin, sans UAC) ---
$script:TaskName = "PartageCOM"

function Test-AutoStart {
    try { return [bool](Get-ScheduledTask -TaskName $script:TaskName -ErrorAction Stop) } catch { return $false }
}

function Enable-AutoStart {
    $action   = New-ScheduledTaskAction -Execute $script:BatPath -Argument "/auto" -WorkingDirectory (Split-Path $script:BatPath)
    $trigger  = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
    $trigger.Delay = "PT20S"   # laisse le temps a l'interface USB de la radio d'apparaitre
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Seconds 0) -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName $script:TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
    Log "Demarrage automatique ACTIVE (tache planifiee '$script:TaskName', a l'ouverture de session)."
    Log "Attention : si vous deplacez ou renommez le fichier .bat, decochez puis recochez la case."
}

function Disable-AutoStart {
    Unregister-ScheduledTask -TaskName $script:TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Log "Demarrage automatique DESACTIVE."
}

# --- Listes de ports virtuels : on exclut les ports < 11, les ports physiques deja
#     presents (sauf ceux crees par com0com), le port radio et les doublons ---
function Get-Com0comPorts {
    $dir = Find-Com0comDir
    if (-not (Test-Path (Join-Path $dir "setupc.exe"))) { return @() }
    try {
        $list = Run-Setupc $dir @("--silent", "list")
        return @([regex]::Matches($list, "PortName=(COM\d+)") | ForEach-Object { $_.Groups[1].Value })
    } catch { return @() }
}

$script:lastReopen = $null

function Get-VPort($cb) {
    if ($cb.Text -match "^COM(\d+)$") { return [int]$Matches[1] } else { return 0 }
}

$script:refreshing = $false
function Refresh-VirtualLists {
    if ($script:refreshing) { return }
    $script:refreshing = $true
    try {
        $virt = Get-Com0comPorts
        $forbidden = @([System.IO.Ports.SerialPort]::GetPortNames() | Where-Object { $virt -notcontains $_ })
        $forbidden += $cbRadio.Text
        $combos = @($cbV1, $cbV2, $cbV3, $cbV4, $cbV5)
        for ($i = 0; $i -lt $combos.Count; $i++) {
            $cb = $combos[$i]
            $current = $cb.Text
            $others = @()
            foreach ($o in $combos) { if ($o -ne $cb -and $o.Text -match "^COM") { $others += $o.Text } }
            $cb.BeginUpdate()
            $cb.Items.Clear()
            if ($i -ge 2) { [void]$cb.Items.Add("Aucun") }
            for ($n = 11; $n -le 60; $n++) {
                $name = "COM$n"
                if ($forbidden -contains $name) { continue }
                if ($others -contains $name) { continue }
                [void]$cb.Items.Add($name)
            }
            $cb.EndUpdate()
            if ($cb.Items.Contains($current)) { $cb.SelectedItem = $current }
            elseif ($i -ge 2) { $cb.SelectedItem = "Aucun" }
            elseif ($cb.Items.Count -gt 0) { $cb.SelectedIndex = 0 }
        }
    } finally { $script:refreshing = $false }
}

# --- Surveillance du port radio + redemarrage de l'interface Bluetooth ---
$script:portMiss = 0
$script:cycling  = $false

function Port-Present($name) {
    return ([System.IO.Ports.SerialPort]::GetPortNames() -contains $name)
}

# Sante reelle du port : le peripherique qui le porte doit exister ET etre en etat OK.
# Plus fiable que la simple presence du COM (qui peut rester liste alors que la liaison
# est tombee, car hub4com garde le port ouvert).
function Port-Healthy($name) {
    # Trois signaux : le port COM est-il liste, le peripherique du port est-il OK,
    # et le dongle Bluetooth (si renseigne) est-il OK. Un seul en defaut = liaison perdue.
    $comListed = ([System.IO.Ports.SerialPort]::GetPortNames() -contains $name)

    $pat = "\(" + [regex]::Escape($name) + "\)"
    $comDev = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match $pat } | Select-Object -First 1
    $comStat = if ($comDev) { "$($comDev.Status)" } else { "absent" }
    $comOk = ($comDev -and $comDev.Status -eq "OK")

    $id = $txtBTId.Text.Trim()
    $btStat = "n/a"; $btOk = $true
    if ($id) {
        $bt = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like "*$id*" } | Select-Object -First 1
        $btStat = if ($bt) { "$($bt.Status)" } else { "absent" }
        $btOk = ($bt -and $bt.Status -eq "OK")
    }

    return ($comListed -and $comOk -and $btOk)
}

# Active/desactive le peripherique Bluetooth. Utilise C:\USBDeview.exe s'il existe
# (comme la commande manuelle de l'utilisateur), sinon les cmdlets PnP natives.
function Set-BTDevice($id, $enable) {
    if (-not $id) { return }
    $usbdeview = "C:\USBDeview.exe"
    if (Test-Path $usbdeview) {
        $op = if ($enable) { "/enable" } else { "/disable" }
        Log "USBDeview /RunAsAdmin $op $id"
        Start-Process -FilePath $usbdeview -ArgumentList @("/RunAsAdmin", $op, $id) -Wait
        return
    }
    $devs = @(Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like "*$id*" })
    if ($devs.Count -eq 0) { Log "Aucun peripherique ne correspond a '$id'."; return }
    foreach ($d in $devs) {
        if ($enable) {
            Enable-PnpDevice  -InstanceId $d.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
            Log "Reactive : $($d.FriendlyName)"
        } else {
            Disable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
            Log "Desactive : $($d.FriendlyName)"
        }
    }
}

# Remonte la chaine des peripheriques jusqu'au peripherique USB parent (le dongle)
function Get-UsbAncestor($instanceId) {
    $cur = $instanceId
    for ($i = 0; $i -lt 12; $i++) {
        if ($cur -like "USB\*") { return $cur }
        $parent = (Get-PnpDeviceProperty -InstanceId $cur -KeyName "DEVPKEY_Device_Parent" -ErrorAction SilentlyContinue).Data
        if (-not $parent) { break }
        $cur = $parent
    }
    return $null
}

# Fenetre de choix du peripherique : propose le dongle USB (recommande) et le port BT
function Select-BTDevice {
    $port = $cbRadio.Text
    $pat = "\(" + [regex]::Escape($port) + "\)"
    $comDev = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match $pat } | Sort-Object FriendlyName | Select-Object -First 1
    if (-not $comDev) {
        [System.Windows.Forms.MessageBox]::Show("Aucune interface associee au port $port n'a ete trouvee.`r`nSi besoin, saisissez l'identifiant a la main dans la case.", "PartageCOM - F5PBG", "OK", "Information") | Out-Null
        return $null
    }
    $list = @()
    $usbId = Get-UsbAncestor $comDev.InstanceId
    if ($usbId) {
        $usbDev = Get-PnpDevice -InstanceId $usbId -ErrorAction SilentlyContinue
        $uname = if ($usbDev) { $usbDev.FriendlyName } else { "Interface USB Bluetooth" }
        $list += [pscustomobject]@{ Label = "$uname  (recommande)"; Id = $usbId }
    }
    $list += [pscustomobject]@{ Label = "$($comDev.FriendlyName)  [$($comDev.Status)]"; Id = $comDev.InstanceId }
    $seen = @{}; $uniq = @()
    foreach ($e in $list) { if (-not $seen.ContainsKey($e.Id)) { $seen[$e.Id] = $true; $uniq += $e } }
    $list = $uniq
    # Un seul candidat : on le retient directement, sans fenetre de choix
    if ($list.Count -eq 1) { return $list[0].Id }
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Choisir le peripherique Bluetooth a redemarrer - F5PBG"
    $dlg.Size = New-Object System.Drawing.Size(660, 430)
    $dlg.StartPosition = "CenterParent"
    $dlg.FormBorderStyle = "FixedDialog"
    $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false
    $dlg.TopMost = $true

    $info = New-Object System.Windows.Forms.Label
    $info.Text = "Interface liee au port $port (le dongle USB est recommande) :"
    $info.Location = New-Object System.Drawing.Point(10, 8); $info.AutoSize = $true
    $dlg.Controls.Add($info)

    $lb = New-Object System.Windows.Forms.ListBox
    $lb.Location = New-Object System.Drawing.Point(10, 32)
    $lb.Size = New-Object System.Drawing.Size(628, 320)
    $lb.Font = New-Object System.Drawing.Font("Consolas", 8)
    foreach ($e in $list) { [void]$lb.Items.Add(("{0}   |   {1}" -f $e.Label, $e.Id)) }
    if ($lb.Items.Count -gt 0) { $lb.SelectedIndex = 0 }
    $dlg.Controls.Add($lb)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = "Choisir"; $ok.Location = New-Object System.Drawing.Point(448, 358); $ok.Width = 90
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = "Annuler"; $cancel.Location = New-Object System.Drawing.Point(548, 358); $cancel.Width = 90
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $dlg.Controls.Add($ok); $dlg.Controls.Add($cancel)
    $dlg.AcceptButton = $ok; $dlg.CancelButton = $cancel

    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK -and $lb.SelectedIndex -ge 0) {
        return $list[$lb.SelectedIndex].Id
    }
    return $null
}

# Attente non bloquante (l'interface reste reactive, le journal se met a jour)
function Wait-Pump($seconds) {
    $end = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $end) { Start-Sleep -Milliseconds 250; [System.Windows.Forms.Application]::DoEvents() }
}

function Cycle-Bluetooth {
    if ($script:cycling) { return }
    $id = $txtBTId.Text.Trim()
    if (-not $id) {
        Log "Aucun peripherique Bluetooth indique : renseignez la case (bouton Detecter)."
        return
    }
    $script:cycling = $true
    try {
        $port = $cbRadio.Text
        Log "Redemarrage de l'interface Bluetooth."
        # Liberer le port avant de cycler le peripherique (sinon il reste verrouille)
        if ($script:proc -and -not $script:proc.HasExited) { $script:proc.Kill(); $script:proc.WaitForExit(3000) | Out-Null }
        $script:proc = $null
        Set-BTDevice $id $false
        Log "Interface desactivee. Attente de 30 s..."
        Wait-Pump 30
        Set-BTDevice $id $true
        Log "Interface reactivee. Attente du port $port (max 60 s)..."
        $ok = $false
        for ($i = 0; $i -lt 60; $i++) { if ((Port-Healthy $port) -and (Port-Present $port)) { $ok = $true; break }; Wait-Pump 1 }
        if (-not $ok) { Log "Port $port non detecte, tentative de reprise quand meme."; Wait-Pump 2 }
        Log "Reprise du partage (relance de hub4com)."
        Start-Partage
    } catch {
        Log "ERREUR pendant le redemarrage Bluetooth : $($_.Exception.Message)"
        Set-Etat $false
    } finally {
        $script:portMiss = 0
        $script:cycling  = $false
    }
}

# Reouvre le port (coupe puis relance hub4com) : equivalent d'un arret/marche.
function Restart-Hub {
    if ($script:proc -and -not $script:proc.HasExited) { $script:proc.Kill(); $script:proc.WaitForExit(3000) | Out-Null }
    $script:proc = $null
    Wait-Pump 2
    Start-Partage
}

# Reouverture automatique si hub4com est tombe. Anti-boucle : si une 2e chute survient
# dans la minute et qu'un dongle est connu, on cycle le dongle avant de rouvrir.
function Soft-Reset {
    if ($script:cycling) { return }
    $script:cycling = $true
    try {
        $now = Get-Date
        $recent = ($script:lastReopen -ne $null -and (($now - $script:lastReopen).TotalSeconds -lt 60))
        $id = $txtBTId.Text.Trim()
        if ($recent -and $id) {
            Log "Nouvelle chute rapide : cycle du dongle Bluetooth."
            Set-BTDevice $id $false
            Log "Dongle desactive, attente 30 s..."
            Wait-Pump 30
            Set-BTDevice $id $true
            Log "Dongle reactive, attente du port (max 60 s)..."
            for ($i = 0; $i -lt 60; $i++) { if ((Port-Healthy $cbRadio.Text) -and (Port-Present $cbRadio.Text)) { break }; Wait-Pump 1 }
        } else {
            Log "Reouverture du port (equivalent arret/marche)."
        }
        if ($script:proc -and -not $script:proc.HasExited) { $script:proc.Kill(); $script:proc.WaitForExit(3000) | Out-Null }
        $script:proc = $null
        Wait-Pump 2
        Start-Partage
        $script:lastReopen = Get-Date
    } catch {
        Log "ERREUR pendant la reinitialisation : $($_.Exception.Message)"
    } finally { $script:cycling = $false }
}

# Reinitialisation programmee : strictement identique au bouton "Reinitialiser la liaison".
function Scheduled-BTReset {
    if ($script:cycling) { return }
    $script:cycling = $true
    try { Log "Reinitialisation automatique : reouverture du port."; Restart-Hub } finally { $script:cycling = $false }
}

# --- Interface ---# --- Interface ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "PartageCOM V1.00 @F5PBG 2026 - Partage de port série"
$form.Size = New-Object System.Drawing.Size(520, 640)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

function Add-Label($text, $x, $y) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = New-Object System.Drawing.Point($x, $y); $l.AutoSize = $true
    $form.Controls.Add($l); return $l
}

Add-Label "Port de l'emetteur (a partager) :" 20 20 | Out-Null
$cbRadio = New-Object System.Windows.Forms.ComboBox
$cbRadio.Location = New-Object System.Drawing.Point(260, 17); $cbRadio.Width = 120
$cbRadio.DropDownStyle = "DropDownList"
$cbRadio.Items.AddRange((Get-SerialPorts))
if ($cbRadio.Items.Contains($cfg.PortRadio)) { $cbRadio.SelectedItem = $cfg.PortRadio } else { $cbRadio.SelectedIndex = 0 }
$form.Controls.Add($cbRadio)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Actualiser"; $btnRefresh.Location = New-Object System.Drawing.Point(376, 16); $btnRefresh.Width = 80
$btnRefresh.Add_Click({
    $sel = $cbRadio.Text; $cbRadio.Items.Clear(); $cbRadio.Items.AddRange((Get-SerialPorts))
    if ($cbRadio.Items.Contains($sel)) { $cbRadio.SelectedItem = $sel } else { $cbRadio.SelectedIndex = 0 }
    Refresh-VirtualLists
})
$form.Controls.Add($btnRefresh)

$labelsV = @("Port virtuel 1 (ex. HRD) :", "Port virtuel 2 (ex. OpsLog) :", "Port virtuel 3 (optionnel) :", "Port virtuel 4 (optionnel) :", "Port virtuel 5 (optionnel) :")
$cbV1 = $null; $cbV2 = $null; $cbV3 = $null; $cbV4 = $null; $cbV5 = $null
for ($i = 0; $i -lt 5; $i++) {
    $y = 55 + 35 * $i
    Add-Label $labelsV[$i] 20 ($y + 3) | Out-Null
    $cb = New-Object System.Windows.Forms.ComboBox
    $cb.Location = New-Object System.Drawing.Point(260, $y); $cb.Width = 120
    $cb.DropDownStyle = "DropDownList"
    $form.Controls.Add($cb)
    Set-Variable -Name ("cbV" + ($i + 1)) -Value $cb
}
# valeurs initiales (depuis la config), puis construction des listes
$initV = @($cfg.Virtuel1, $cfg.Virtuel2, $cfg.Virtuel3, $cfg.Virtuel4, $cfg.Virtuel5)
$combosInit = @($cbV1, $cbV2, $cbV3, $cbV4, $cbV5)
for ($i = 0; $i -lt 5; $i++) {
    $v = [int]$initV[$i]
    if ($v -gt 0) { [void]$combosInit[$i].Items.Add("COM$v"); $combosInit[$i].SelectedIndex = 0 }
}
Refresh-VirtualLists
foreach ($c in $combosInit) { $c.Add_SelectedIndexChanged({ Refresh-VirtualLists }) }
$cbRadio.Add_SelectedIndexChanged({ Refresh-VirtualLists })

Add-Label "Debit (bauds) :" 20 233 | Out-Null
$cbBaud = New-Object System.Windows.Forms.ComboBox
$cbBaud.Location = New-Object System.Drawing.Point(260, 230); $cbBaud.Width = 120
$cbBaud.Items.AddRange(@("4800","9600","19200","38400","57600","115200"))
$cbBaud.Text = "$($cfg.Baud)"
$form.Controls.Add($cbBaud)

$btnOnOff = New-Object System.Windows.Forms.Button
$btnOnOff.Location = New-Object System.Drawing.Point(20, 280); $btnOnOff.Size = New-Object System.Drawing.Size(150, 45)
$btnOnOff.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnOnOff.ForeColor = [System.Drawing.Color]::White; $btnOnOff.FlatStyle = "Flat"
$btnOnOff.Add_Click({ if ($script:proc -and -not $script:proc.HasExited) { Stop-Partage } else { Start-Partage } })
$form.Controls.Add($btnOnOff)

$btnReset = New-Object System.Windows.Forms.Button
$btnReset.Text = "Reinitialiser la liaison"
$btnReset.Location = New-Object System.Drawing.Point(300, 280)
$btnReset.Size = New-Object System.Drawing.Size(180, 45)
$btnReset.Add_Click({
    if ($script:cycling) { return }
    $script:cycling = $true
    try { Log "Reinitialisation manuelle : reouverture du port."; Restart-Hub } finally { $script:cycling = $false }
})
$form.Controls.Add($btnReset)

$lblEtat = Add-Label "" 190 293
$lblEtat.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20, 340); $txtLog.Size = New-Object System.Drawing.Size(460, 110)
$txtLog.Multiline = $true; $txtLog.ScrollBars = "Vertical"; $txtLog.ReadOnly = $true
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8)
$form.Controls.Add($txtLog)

$lblSign = New-Object System.Windows.Forms.Label
$lblSign.Text = "F5PBG"
$lblSign.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblSign.ForeColor = [System.Drawing.Color]::Gray
$lblSign.AutoSize = $true
$lblSign.Location = New-Object System.Drawing.Point(432, 583)
$form.Controls.Add($lblSign)

$chkAuto = New-Object System.Windows.Forms.CheckBox
$chkAuto.Text = "Demarrer automatiquement avec Windows (partage actif, fenetre reduite)"
$chkAuto.Location = New-Object System.Drawing.Point(20, 458); $chkAuto.AutoSize = $true
$chkAuto.Checked = Test-AutoStart
$chkAuto.Add_Click({
    try {
        if ($chkAuto.Checked) { Enable-AutoStart } else { Disable-AutoStart }
    } catch {
        Log "ERREUR tache planifiee : $($_.Exception.Message)"
        $chkAuto.Checked = Test-AutoStart
    }
})
$form.Controls.Add($chkAuto)

Add-Label "Périphérique Bluetooth à redémarrer si nécessaire :" 20 487 | Out-Null
$txtBTId = New-Object System.Windows.Forms.TextBox
$txtBTId.Location = New-Object System.Drawing.Point(20, 507); $txtBTId.Width = 320
$txtBTId.Text = "$($cfg.BTId)"
$form.Controls.Add($txtBTId)

$btnDetect = New-Object System.Windows.Forms.Button
$btnDetect.Text = "Detecter..."; $btnDetect.Location = New-Object System.Drawing.Point(350, 505); $btnDetect.Width = 110
$btnDetect.Add_Click({
    try {
        $id = Select-BTDevice
        if ($id) { $txtBTId.Text = $id; Log "Peripherique Bluetooth selectionne : $id" }
    } catch { Log "Detection impossible : $($_.Exception.Message)" }
})
$form.Controls.Add($btnDetect)

$chkAutoBT = New-Object System.Windows.Forms.CheckBox
$chkAutoBT.Text = "Reinitialisation automatique Bluetooth toutes les"
$chkAutoBT.Location = New-Object System.Drawing.Point(20, 537); $chkAutoBT.AutoSize = $true
$chkAutoBT.Checked = [bool]$cfg.AutoBT
$form.Controls.Add($chkAutoBT)

$cbAutoBTHours = New-Object System.Windows.Forms.ComboBox
$cbAutoBTHours.Location = New-Object System.Drawing.Point(355, 534); $cbAutoBTHours.Width = 55
$cbAutoBTHours.DropDownStyle = "DropDownList"
1..12 | ForEach-Object { [void]$cbAutoBTHours.Items.Add("$_") }
if ($cbAutoBTHours.Items.Contains("$($cfg.AutoBTHours)")) { $cbAutoBTHours.SelectedItem = "$($cfg.AutoBTHours)" } else { $cbAutoBTHours.SelectedIndex = 5 }
$form.Controls.Add($cbAutoBTHours)

Add-Label "heures" 418 537 | Out-Null

$chkTop = New-Object System.Windows.Forms.CheckBox
$chkTop.Text = "Garder la fenêtre au premier plan"
$chkTop.Location = New-Object System.Drawing.Point(20, 562); $chkTop.AutoSize = $true
$chkTop.Checked = [bool]$cfg.TopMost
$form.Controls.Add($chkTop)
$chkTop.Add_Click({ $form.TopMost = $chkTop.Checked })
$form.TopMost = $chkTop.Checked

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000
$timer.Add_Tick({
    if ($script:cycling) { return }
    if ($script:proc -and $script:proc.HasExited) {
        Log "hub4com s'est arrete de maniere inattendue."
        $script:proc = $null
        Set-Etat $false
        Log "Reouverture automatique du port."
        Soft-Reset
    }
})
$timer.Start()

$btTimer = New-Object System.Windows.Forms.Timer
$btTimer.Add_Tick({ Scheduled-BTReset })
function Configure-BTTimer {
    $btTimer.Stop()
    if ($chkAutoBT.Checked) {
        $h = [int]$cbAutoBTHours.Text; if ($h -lt 1) { $h = 1 }
        $btTimer.Interval = $h * 3600 * 1000
        $btTimer.Start()
        Log "Reinit. auto Bluetooth : toutes les $h h."
    } else {
        Log "Reinit. auto Bluetooth desactivee."
    }
}
$chkAutoBT.Add_Click({ Configure-BTTimer })
$cbAutoBTHours.Add_SelectedIndexChanged({ if ($chkAutoBT.Checked) { Configure-BTTimer } })
if ($chkAutoBT.Checked) { Configure-BTTimer }

$form.Add_FormClosing({
    param($sender, $e)
    # Croix de fermeture : si le partage tourne, on reduit au lieu de fermer.
    if ($e.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing -and $script:proc -and -not $script:proc.HasExited) {
        $e.Cancel = $true
        $form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
        return
    }
    if ($script:proc -and -not $script:proc.HasExited) { Stop-Partage }
    Save-Config
})

Set-Etat $false
Log "Pret. Choisissez les ports puis cliquez sur MARCHE."
Log "Au premier lancement, com0com et hub4com (inclus) seront installes."

if ($env:PARTAGECOM_AUTO -eq "/auto") {
    $form.Add_Shown({
        Log "Mode automatique : demarrage du partage."
        Start-Partage
        if ($script:proc) { $form.WindowState = "Minimized" }
    })
}
[void]$form.ShowDialog()

LogFile "---- Fermeture normale ----"
} catch {
    $err = "Erreur au demarrage de PartageCOM :`r`n$($_.Exception.Message)`r`n`r`nLigne : $($_.InvocationInfo.ScriptLineNumber)`r`nDetails dans : $script:LogFile"
    LogFile "ERREUR FATALE : $($_.Exception.Message) (ligne $($_.InvocationInfo.ScriptLineNumber))"
    LogFile $_.ScriptStackTrace
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show($err, "PartageCOM - F5PBG", "OK", "Error") | Out-Null
    } catch {
        [Console.Win]::ShowWindow($script:ConsoleHwnd, 5) | Out-Null
        Write-Host $err
        Read-Host "Appuyez sur Entree pour fermer"
    }
    exit 1
}
