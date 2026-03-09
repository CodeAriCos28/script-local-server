' =====================================================
' Levantar Django con Waitress - Ejecutar invisible + Logging Avanzado - CORREGIDO
' =====================================================
Dim objShell, objFSO, psCommand, logDir, errorLogFile, generalLogFile, timestamp

Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

' Crear directorios de logs si no existen
logDir = "C:\Log_Server"
If Not objFSO.FolderExists(logDir) Then
    objFSO.CreateFolder(logDir)
End If

If Not objFSO.FolderExists(logDir & "\errors") Then
    objFSO.CreateFolder(logDir & "\errors")
End If

If Not objFSO.FolderExists(logDir & "\general") Then
    objFSO.CreateFolder(logDir & "\general")
End If

If Not objFSO.FolderExists(logDir & "\compressed") Then
    objFSO.CreateFolder(logDir & "\compressed")
End If

' Generar timestamp para archivos
timestamp = Year(Now) & Right("0" & Month(Now), 2) & Right("0" & Day(Now), 2) & "-" & _
           Right("0" & Hour(Now), 2) & Right("0" & Minute(Now), 2) & Right("0" & Second(Now), 2)

errorLogFile = logDir & "\errors\waitress-errors-" & timestamp & ".log"
generalLogFile = logDir & "\general\waitress-general-" & timestamp & ".log"

' Crear un archivo PS1 temporal con el script de PowerShell
Dim psScriptPath, psScriptContent
psScriptPath = objShell.ExpandEnvironmentStrings("%TEMP%") & "\waitress_runner.ps1"

psScriptContent = "Set-Location 'C:\Users\lanti\OneDrive\Escritorio\Visual Studio\ddmaxmotoimport2\sytem_phone'" & vbCrLf & _
"$env:VIRTUAL_ENV = 'C:\Users\lanti\OneDrive\Escritorio\Visual Studio\ddmaxmotoimport2\sytem_phone\venv'" & vbCrLf & _
"$env:Path = ""$env:VIRTUAL_ENV\Scripts;$env:Path""" & vbCrLf & _
". ""$env:VIRTUAL_ENV\Scripts\Activate.ps1""" & vbCrLf & vbCrLf & _
"# Función para comprimir logs viejos" & vbCrLf & _
"$compressOldLogs = {" & vbCrLf & _
"    $cutoffDate = (Get-Date).AddDays(-7)" & vbCrLf & _
"    Get-ChildItem 'C:\Log_Server\errors\*.log', 'C:\Log_Server\general\*.log' | Where-Object { $_.LastWriteTime -lt $cutoffDate } | ForEach-Object {" & vbCrLf & _
"        $zipPath = 'C:\Log_Server\compressed\' + $_.BaseName + '.zip'" & vbCrLf & _
"        try {" & vbCrLf & _
"            Compress-Archive -Path $_.FullName -DestinationPath $zipPath -Force" & vbCrLf & _
"            Remove-Item $_.FullName -Force" & vbCrLf & _
"            Write-Host 'Compressed and removed: ' + $_.Name" & vbCrLf & _
"        } catch {" & vbCrLf & _
"            Write-Host 'Error compressing: ' + $_.Exception.Message" & vbCrLf & _
"        }" & vbCrLf & _
"    }" & vbCrLf & _
"}" & vbCrLf & vbCrLf & _
"# Ejecutar compresión de logs viejos" & vbCrLf & _
"& $compressOldLogs" & vbCrLf & vbCrLf & _
"# Iniciar Waitress con filtrado de logs" & vbCrLf & _
"python -m waitress --listen=0.0.0.0:8000 sytem_phone.wsgi:application 2>&1 | ForEach-Object {" & vbCrLf & _
"    $line = $_.ToString()" & vbCrLf & _
"    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'" & vbCrLf & _
"    $logEntry = ""[$timestamp] $line""" & vbCrLf & vbCrLf & _
"    # Filtrar errores importantes" & vbCrLf & _
"    if ($line -match 'ERROR|CRITICAL|Exception|Traceback|500|400|404|403|401|502|503|504') {" & vbCrLf & _
"        Add-Content -Path '" & Replace(errorLogFile, "\", "\\") & "' -Value $logEntry -Encoding UTF8" & vbCrLf & _
"    }" & vbCrLf & vbCrLf & _
"    # Logs generales importantes" & vbCrLf & _
"    if ($line -match 'serving on|Serving on|started|Starting|stopped|Stopping|configuration') {" & vbCrLf & _
"        Add-Content -Path '" & Replace(generalLogFile, "\", "\\") & "' -Value $logEntry -Encoding UTF8" & vbCrLf & _
"    }" & vbCrLf & _
"}"

' Escribir el script de PowerShell al archivo temporal
Dim psFile
Set psFile = objFSO.CreateTextFile(psScriptPath, True)
psFile.Write psScriptContent
psFile.Close

' Ejecutar el archivo PowerShell
psCommand = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & psScriptPath & """"

' Ejecutar completamente oculto (0 = sin ventana)
objShell.Run psCommand, 0, False

' Limpiar objetos
Set objShell = Nothing
Set objFSO = Nothing