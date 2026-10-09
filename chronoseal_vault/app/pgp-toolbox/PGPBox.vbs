Option Explicit

Dim shell, fso, root, psScript, command
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

root = fso.GetParentFolderName(WScript.ScriptFullName)
psScript = root & "\start.ps1"
command = "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & psScript & """"

' One-click launcher: no CMD window, works with UNC project paths.
shell.Run command, 0, False
