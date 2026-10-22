@echo off
setlocal
title Lazer Shot Mali-450 - Gerar APK
cd /d "%~dp0"
echo ============================================================
echo   LAZER SHOT 2.0 - TV BOX MALI-450 (S905L/S905W, ANDROID 7.1)
echo   GODOT 3.6.2 (OPENGL ES 2) - GERA O APK
echo   Tudo aparece aqui na hora e fica gravado em
echo   build\android\GERACAO-COMPLETA.log
echo ============================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0GERAR_APK_MALI450.ps1" %*
set "RESULTADO=%ERRORLEVEL%"
echo.
if not "%RESULTADO%"=="0" (
    echo FALHA. Envie o arquivo build\android\GERACAO-COMPLETA.log
) else (
    echo PRONTO. O APK esta na pasta APK-Pronto.
)
echo.
pause
exit /b %RESULTADO%
