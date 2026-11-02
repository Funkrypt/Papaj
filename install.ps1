# Instalator gadzetu Papaj.
# Pobiera repo, kopiuje do %LOCALAPPDATA%\Papaj, dodaje autostart i uruchamia gadzet.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$dest = Join-Path $env:LOCALAPPDATA 'Papaj'
$zip  = Join-Path $env:TEMP 'papaj.zip'
$tmp  = Join-Path $env:TEMP ('papaj_' + [guid]::NewGuid().ToString('N'))

Write-Host 'Papaj: pobieranie...'
Invoke-WebRequest 'https://github.com/Funkrypt/Papaj/archive/refs/heads/main.zip' -OutFile $zip -UseBasicParsing
Expand-Archive $zip $tmp -Force

Write-Host "Papaj: instalacja w $dest ..."
New-Item $dest -ItemType Directory -Force | Out-Null
Copy-Item (Join-Path $tmp 'Papaj-main\*') $dest -Recurse -Force
Remove-Item $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue

# Autostart: skrot w folderze Startup
$startup = [Environment]::GetFolderPath('Startup')
$sh  = New-Object -ComObject WScript.Shell
$lnk = $sh.CreateShortcut((Join-Path $startup 'Papaj.lnk'))
$lnk.TargetPath       = 'C:\Windows\System32\wscript.exe'
$lnk.Arguments        = '"' + (Join-Path $dest 'start.vbs') + '"'
$lnk.WorkingDirectory = $dest
$lnk.Description      = 'Gadzet Papaj'
$lnk.Save()

# Uruchom teraz
Start-Process 'C:\Windows\System32\wscript.exe' -ArgumentList ('"' + (Join-Path $dest 'start.vbs') + '"')
Write-Host "Papaj: gotowe. Zainstalowano w $dest, dodano autostart i uruchomiono."
