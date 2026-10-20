@echo off
setlocal
title Lazer Shot - Gerar APK
cd /d "%~dp0"
echo ============================================================
echo   LAZER SHOT - GERAR APK (LEVE: Pro Ultra / AVANCADA: TX9)
echo   So uma versao: GERAR_APK_LEVE.bat ou GERAR_APK_AVANCADA.bat
echo   Tudo aparece aqui na hora e fica gravado em
echo   build\android\GERACAO-COMPLETA.log
echo ============================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0GERAR_APK_PRO_ULTRA.ps1" %*
set "RESULTADO=%ERRORLEVEL%"
echo.
if not "%RESULTADO%"=="0" (
    echo FALHA. Envie o arquivo build\android\GERACAO-COMPLETA.log
) else (
    echo PRONTO.
)
echo.
pause
exit /b %RESULTADO%
