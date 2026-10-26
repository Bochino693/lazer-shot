#!/bin/sh
# Compila a CameraFoto (a foto do jogador) em camera_foto.jar, com as
# assinaturas do Android em stubs/ (só para compilar; o de verdade vem da
# TV Box). O gerador do APK converte o .jar em classes2.dex com o d8 do
# Android SDK do PC e põe no modelo do APK.
set -e
cd "$(dirname "$0")"
rm -rf build && mkdir -p build/stubs build/classes
javac -encoding UTF-8 --release 8 -d build/stubs $(find stubs -name '*.java')
javac -encoding UTF-8 --release 8 -cp build/stubs -d build/classes $(find src -name '*.java')
(cd build/classes && jar --create --file ../../camera_foto.jar --date=2026-01-01T00:00:00Z org)
rm -rf build
echo "camera_foto.jar pronto"
