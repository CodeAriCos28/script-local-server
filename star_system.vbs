' =====================================================
' Levantar Django con Waitress - Ejecutar invisible
' =====================================================
Dim objShell, psCommand
Set objShell = CreateObject("WScript.Shell")

' Comando PowerShell completo para ejecutar Django con Waitress
psCommand = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -Command """ & _
           "Set-Location 'C:\Users\lanti\OneDrive\Escritorio\Visual Studio\ddmaxmotoimport2\sytem_phone'; " & _
           "$env:VIRTUAL_ENV = 'C:\Users\lanti\OneDrive\Escritorio\Visual Studio\ddmaxmotoimport2\sytem_phone\venv'; " & _
           "$env:Path = \""$env:VIRTUAL_ENV\Scripts;$env:Path\""; " & _
           ". \""$env:VIRTUAL_ENV\Scripts\Activate.ps1\""; " & _
           "python -m waitress --listen=0.0.0.0:8002 sytem_phone.wsgi:application" & _
           """"

' Ejecutar completamente oculto (0 = sin ventana)
objShell.Run psCommand, 0, False

Set objShell = Nothing