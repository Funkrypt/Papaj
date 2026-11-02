' Uruchamia Papaj.ps1 z folderu, w ktorym lezy ten plik (przenosne).
dir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """ & dir & "\Papaj.ps1""", 0, False
