# Instalator gadzetu Papaj.
# Pobiera repo do %LOCALAPPDATA%\Papaj, doinstalowuje polski glos TTS (jesli brak),
# dodaje autostart i uruchamia gadzet. Nie wymaga gita.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$dest = Join-Path $env:LOCALAPPDATA 'Papaj'
$zip  = Join-Path $env:TEMP 'papaj.zip'
$tmp  = Join-Path $env:TEMP ('papaj_' + [guid]::NewGuid().ToString('N'))

# Zatrzymaj dzialajaca instancje (zwolnij ewentualne pliki)
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -match 'Papaj\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 400

Write-Host 'Papaj: pobieranie...'
Invoke-WebRequest 'https://github.com/Funkrypt/Papaj/archive/refs/heads/main.zip' -OutFile $zip -UseBasicParsing
Expand-Archive $zip $tmp -Force

Write-Host "Papaj: instalacja w $dest ..."
New-Item $dest -ItemType Directory -Force | Out-Null
Get-ChildItem $dest -File -ErrorAction SilentlyContinue | ForEach-Object { try { $_.IsReadOnly = $false } catch { } }
Copy-Item (Join-Path $tmp 'Papaj-main\*') $dest -Recurse -Force
Remove-Item $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue

# --- Polski glos TTS: doinstaluj, jesli systemu go nie ma ---
function Test-PolishVoice {
    try {
        $null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media, ContentType = WindowsRuntime]
        return [bool]([Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices |
                Where-Object { $_.Language -like 'pl*' } | Select-Object -First 1)
    } catch { return $true }  # gdy nie da sie sprawdzic, nie blokuj instalacji
}
if (-not (Test-PolishVoice)) {
    Write-Host 'Papaj: brak polskiego glosu TTS - doinstalowuje (moze poprosic o uprawnienia administratora)...'
    $cap = 'Language.TextToSpeech~~~pl-PL~0.0.1.0'
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    try {
        if ($isAdmin) {
            Add-WindowsCapability -Online -Name $cap | Out-Null
        } else {
            Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', "Add-WindowsCapability -Online -Name '$cap'"
        }
        Write-Host 'Papaj: polski glos zainstalowany.'
    } catch {
        Write-Warning "Papaj: nie udalo sie doinstalowac polskiego glosu ($($_.Exception.Message)). Gadzet uzyje glosu domyslnego systemu."
    }
}

# --- Autostart ---
$startup = [Environment]::GetFolderPath('Startup')
$sh  = New-Object -ComObject WScript.Shell
$lnk = $sh.CreateShortcut((Join-Path $startup 'Papaj.lnk'))
$lnk.TargetPath       = 'C:\Windows\System32\wscript.exe'
$lnk.Arguments        = '"' + (Join-Path $dest 'start.vbs') + '"'
$lnk.WorkingDirectory = $dest
$lnk.Description      = 'Gadzet Papaj'
$lnk.Save()

# --- Uruchom ---
Start-Process 'C:\Windows\System32\wscript.exe' -ArgumentList ('"' + (Join-Path $dest 'start.vbs') + '"')
Write-Host "Papaj: gotowe. Zainstalowano w $dest, dodano autostart i uruchomiono."
