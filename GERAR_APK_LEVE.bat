@echo off
rem So a versao LEVE (Pro Ultra, a TV Box mais fraca). Aceita as mesmas opcoes
rem do GERAR_APK_PRO_ULTRA.bat (ex.: GERAR_APK_LEVE.bat -Instalar -Ip 192.168.0.50).
call "%~dp0GERAR_APK_PRO_ULTRA.bat" -Versao Leve %*
