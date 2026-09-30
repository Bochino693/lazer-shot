@echo off
setlocal
cd /d "%~dp0"
if not exist "build\android" mkdir "build\android"
set "LOG=%~dp0build\android\GERACAO-COMPLETA.log"
echo Gerando APK. Aguarde; o console permanecera aberto.
echo O historico completo sera salvo em: %LOG%
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0GERAR_APK_PRO_ULTRA.ps1" %* > "%LOG%" 2>&1
set "RESULTADO=%ERRORLEVEL%"
type "%LOG%"
if not "%RESULTADO%"=="0" (
    echo.
    echo FALHA NA GERACAO. Envie o arquivo build\android\GERACAO-COMPLETA.log.
) else (
    echo.
    echo GERACAO CONCLUIDA. Confira APK-Pronto\LazerShot-Pro-Ultra-Android10.apk.
)
echo.
pause
exit /b %RESULTADO%
