@echo off
rem RESERVA: as duas versoes SEM o Gradle e SEM a foto antes da partida (como
rem a 1.30). O jogo funciona inteiro. Use para testar na TV Box se o
rem GERAR_APK_PRO_ULTRA.bat falhar no Gradle. Os APKs saem com -SEM-CAMERA no
rem nome. Aceita as mesmas opcoes (ex.: GERAR_APK_SEM_CAMERA.bat -Versao Leve).
call "%~dp0GERAR_APK_PRO_ULTRA.bat" -SemCamera %*
