#!/bin/bash
# Regrava as prévias do menu (background_video/teaser_*.mp4 e .ogv) com o
# robô jogando cada tela (tools/demos/robo.gd), pelo Movie Maker do Godot.
#
#   bash tools/demos/gravar_demos.sh [pasta_do_projeto_importado] [segundos]
#
# A pasta precisa ser uma cópia do projeto já importada (com .godot). A janela
# é forçada para 1080x1920 só nessa cópia (override.cfg), e as prévias saem
# como as antigas: mp4 h264 576x1024 30 q/s com AAC; ogv 432x768 24 q/s
# (1,3 Mbit/s: plano B, perto de 4,5 MB cada).
# Precisa de godot 4.6, xvfb-run e ffmpeg (libx264, libtheora, libvorbis).
set -e
P=${1:-.}
SEG=${2:-26}
AQUI=$(cd "$(dirname "$0")" && pwd)
SAIDA=$(cd "$AQUI/../.." && pwd)/background_video
TMP=$(mktemp -d)
for par in "deserto teaser_desert" "mar teaser_mar" "bar teaser_bar" "arena teaser_arena"; do
  set -- $par
  CENA=$1; NOME=$2
  printf '[display]\n\nwindow/size/mode=0\nwindow/size/window_width_override=1080\nwindow/size/window_height_override=1920\n' > "$P/override.cfg"
  CENA=$CENA DUR=$((SEG + 2)) xvfb-run -a -s "-screen 0 1080x1920x24" godot --path "$P" \
    --write-movie "$TMP/$CENA.avi" --fixed-fps 30 -s "$AQUI/robo.gd" > "$TMP/$CENA.log" 2>&1 || true
  rm -f "$P/override.cfg"
  Q=$(grep -o "comecou no quadro [0-9]*" "$TMP/$CENA.log" | grep -o "[0-9]*$" | head -1)
  INI=$(python3 -c "print(max(0.0, ${Q:-0}/30.0 - 0.3))")
  FV="fade=t=in:st=0:d=0.4,fade=t=out:st=$((SEG - 1)):d=1"
  FA="afade=t=in:st=0:d=0.4,afade=t=out:st=$((SEG - 1)):d=1"
  ffmpeg -v error -y -ss "$INI" -t "$SEG" -i "$TMP/$CENA.avi" -vf "scale=576:1024:flags=lanczos,$FV" \
    -c:v libx264 -profile:v main -level 4.0 -pix_fmt yuv420p -preset slow -b:v 2600k -maxrate 3200k -bufsize 6000k -r 30 \
    -af "$FA" -c:a aac -b:a 128k -ar 48000 -ac 2 -movflags +faststart "$SAIDA/$NOME.mp4"
  ffmpeg -v error -y -ss "$INI" -t "$SEG" -i "$TMP/$CENA.avi" -vf "scale=432:768:flags=lanczos,$FV" \
    -c:v libtheora -b:v 1300k -r 24 -af "$FA" -c:a libvorbis -q:a 4 -ar 48000 -ac 2 "$SAIDA/$NOME.ogv"
  rm -f "$TMP/$CENA.avi"
  echo "$NOME pronto"
done
rm -rf "$TMP"
