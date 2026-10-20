@echo off
setlocal
cd /d "%~dp0"
if not exist "build\android" mkdir "build\android"
set "LOG=%~dp0build\android\GERACAO-COMPLETA.log"
echo Gerando os APKs do Lazer Shot (LEVE para a PROSB-3000 e AVANCADA).
echo So uma versao: GERAR_APK_LEVE.bat ou GERAR_APK_AVANCADA.bat.
echo Aguarde; o console permanecera aberto (o Gradle leva alguns minutos).
echo O historico completo sera salvo em: %LOG%
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0GERAR_APK_PRO_ULTRA.ps1" %* > "%LOG%" 2>&1
set "RESULTADO=%ERRORLEVEL%"
type "%LOG%"
if not "%RESULTADO%"=="0" (
    echo.
    echo FALHA NA GERACAO. Envie o arquivo build\android\GERACAO-COMPLETA.log.
) else (
    echo.
    echo GERACAO CONCLUIDA. Confira a pasta APK-Pronto:
    echo   LazerShot-Leve-PROSB3000.apk  = TV Box PROSB-3000 (a mais fraca)
    echo   LazerShot-Avancada.apk        = TV Box mais forte
)
echo.
pause
exit /b %RESULTADO%
