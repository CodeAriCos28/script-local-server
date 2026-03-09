@echo off
setlocal enabledelayedexpansion

:: ===============================================
:: CONFIGURACION
:: ===============================================
:: MySQL
set MYSQL_USER=root
set MYSQL_PASSWORD=LastedKing200#
set MYSQL_HOST=localhost
set MYSQL_PORT=3306
set DATABASE_NAME=ddmaxmotoimport
set MYSQL_PATH=C:\Program Files\MySQL\MySQL Server 8.4\bin
set BACKUP_DIR=C:\mysql_backups

:: Google Drive
set RCLONE_PATH=C:\rclone\rclone-v1.71.2-windows-amd64\rclone.exe
set GDRIVE_REMOTE=gdrive:/MySQL_Backups

:: Numero maximo de backups a mantener
set MAX_BACKUPS=3

:: ===============================================
:: INICIO DEL SCRIPT
:: ===============================================
cls
echo ===============================================
echo        BACKUP MYSQL + GOOGLE DRIVE
echo ===============================================
echo Database: %DATABASE_NAME%
echo Maximo de backups: %MAX_BACKUPS%
echo ===============================================
echo.

:: Crear directorio si no existe
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

:: Obtener fecha actual
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%"
set "current_date=%YYYY%_%MM%_%DD%_%HH%_%Min%"
set BACKUP_FILE=%DATABASE_NAME%_backup_%current_date%.sql
set BACKUP_ZIP=%DATABASE_NAME%_backup_%current_date%.zip

:: ===============================================
:: [1/5] MANTENER SOLO LOS 3 BACKUPS MAS RECIENTES
:: ===============================================
echo [1/5] Verificando cantidad de backups existentes...

:: Contar backups actuales
set backup_count=0
for %%f in ("%BACKUP_DIR%\%DATABASE_NAME%_backup_*.zip") do (
    if exist "%%f" set /a backup_count+=1
)

echo Backups actuales: %backup_count%

if %backup_count% geq %MAX_BACKUPS% (
    echo Eliminando backups antiguos para mantener solo %MAX_BACKUPS%...
    
    :: Calcular cuantos eliminar
    set /a to_delete=%backup_count%-%MAX_BACKUPS%+1
    
    :: Eliminar los mas antiguos (ordenados por fecha)
    set deleted=0
    for /f "tokens=*" %%f in ('dir "%BACKUP_DIR%\%DATABASE_NAME%_backup_*.zip" /b /o:d 2^>nul') do (
        if !deleted! lss !to_delete! (
            echo Eliminando: %%f
            del "%BACKUP_DIR%\%%f"
            set /a deleted+=1
        )
    )
    echo Backups antiguos eliminados: !deleted!
) else (
    echo No es necesario eliminar backups
)
echo.

:: ===============================================
:: [2/5] CREAR BACKUP MYSQL
:: ===============================================
echo [2/5] Creando backup de MySQL...
"%MYSQL_PATH%\mysqldump.exe" -h%MYSQL_HOST% -P%MYSQL_PORT% -u%MYSQL_USER% -p%MYSQL_PASSWORD% --routines --triggers --single-transaction --lock-tables=false %DATABASE_NAME% > "%BACKUP_DIR%\%BACKUP_FILE%"
if %errorlevel% neq 0 (
    echo ERROR: No se pudo crear el backup
    pause
    exit /b 1
)
echo Backup SQL creado
echo.

:: ===============================================
:: [3/5] COMPRIMIR ARCHIVO
:: ===============================================
echo [3/5] Comprimiendo archivo...
powershell -command "Compress-Archive -Path '%BACKUP_DIR%\%BACKUP_FILE%' -DestinationPath '%BACKUP_DIR%\%BACKUP_ZIP%' -Force"
if %errorlevel% neq 0 (
    echo ERROR: No se pudo comprimir
    pause
    exit /b 1
)
del "%BACKUP_DIR%\%BACKUP_FILE%"
echo Archivo comprimido: %BACKUP_ZIP%
echo.

:: ===============================================
:: [4/5] SINCRONIZAR CON GOOGLE DRIVE
:: ===============================================
echo [4/5] Sincronizando con Google Drive...
echo Carpeta: MySQL_Backups
echo Esto puede tomar unos minutos...
echo.

:: Crear carpeta en Google Drive si no existe
"%RCLONE_PATH%" mkdir "%GDRIVE_REMOTE%" 2>nul

:: Sincronizar
"%RCLONE_PATH%" sync "%BACKUP_DIR%" "%GDRIVE_REMOTE%" --exclude "logs/**" --progress --delete-during

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Fallo la sincronizacion con Google Drive
    echo Verifica tu conexion a internet
    pause
    exit /b 1
)

echo.
echo Sincronizacion completada
echo.

:: ===============================================
:: [5/5] VERIFICACION
:: ===============================================
echo [5/5] Verificando...

:: Contar archivos locales
set local_count=0
for %%f in ("%BACKUP_DIR%\%DATABASE_NAME%_backup_*.zip") do (
    if exist "%%f" set /a local_count+=1
)

:: Contar archivos en Google Drive
set gdrive_count=0
set "temp_file=%TEMP%\gdrive_count_%RANDOM%.txt"
"%RCLONE_PATH%" lsf "%GDRIVE_REMOTE%" --include "%DATABASE_NAME%_backup_*.zip" > "%temp_file%" 2>&1
if exist "%temp_file%" (
    for /f "delims=" %%f in (%temp_file%) do (
        set /a gdrive_count+=1
    )
    del "%temp_file%"
)

echo Archivos locales: %local_count%
echo Archivos en Google Drive: %gdrive_count%

if %local_count% equ %gdrive_count% (
    echo Estado: OK - Todo sincronizado correctamente
) else (
    echo ADVERTENCIA: Las cantidades no coinciden
)
echo.

:: ===============================================
:: RESUMEN
:: ===============================================
echo ===============================================
echo                   RESUMEN
echo ===============================================
echo Backup: %BACKUP_ZIP%
echo Ubicacion: %BACKUP_DIR%
echo Google Drive: Sincronizado
echo Total de backups mantenidos: %local_count%
echo Maximo permitido: %MAX_BACKUPS%
echo ===============================================
echo.
echo PROCESO COMPLETADO
echo.
pause