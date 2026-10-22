# Lazer Shot 2.0 — TV Box Mali-450

Esta pasta é o **Lazer Shot para a TV Box da placa Mali-450** (S905L / S905W, Android 7.1). A placa de vídeo dela só tem OpenGL ES 2.0, por isso este jogo é feito no **Godot 3.6.2 (GLES2)**. A versão 4.6 (Pro Ultra / TX9) é outro projeto, na branch `tvbox-ultra-pro`.

## O que muda em relação à versão 4.6

- **Todos os alvos são 2D.** Nada passa mais por trás do cenário: os alvos ficam sempre na frente.
- **Os danos continuam todos:**
  - o cristal trinca e quebra, e os obeliscos também;
  - furos de bala, lascas de madeira e de pedra;
  - a janela do bar estilhaça;
  - o barril vaza vinho;
  - o laser queima a parede e o LED da Arena estoura.
- **Os fundos continuam vivos:**
  - o navio afunda no Mar;
  - o sol entra pela janela do Bar com raios e poeira;
  - o Egito troca o dia pela noite e tem águias e o olho do astro;
  - a Arena pulsa com a música, com vapor, faíscas e giroflex.
- **Os bônus continuam valendo pontos:** barril (+40 por furo), cristal (+300), pontas dos obeliscos (+150), peixes dourados (+40 cada), LED do alto da Arena (+50).
- **Os efeitos de tiro voltaram em todas as telas:** o traço do tiro, o coice da mira e as faíscas.
- **As telas são as mesmas:**
  - abertura Lazer & Sport GAMES;
  - tela inicial com APERTE START;
  - demonstração dos cenários e vitrine do ranking;
  - escolha de cenário com roleta e missão;
  - como jogar, contagem, fim de jogo e nome no ranking;
  - ranking dos 20 melhores e configuração.
- **Sem vídeo e sem shader de tela cheia.** A Mali-450 engasga com isso. Os fundos ganham vida com luz somada e partículas.
- **Sem câmera:** não há foto antes da partida. No ranking aparece a silhueta.
- **O APK tem outro nome de pacote** (`com.lazersport.lazershot.mali`). Ele instala ao lado da versão 4.6, não por cima.

## Gerar o APK (no PC com Windows)

1. Baixe a branch **`tvbox-mali450`** numa **pasta nova e vazia**, com caminho curto, por exemplo `C:\LazerShotMali`.

   > Não extraia por cima da pasta da versão 4.6. O gerador percebe a mistura e para.

2. Dê dois cliques em **`GERAR_APK_MALI450.bat`**.

   Tudo aparece na janela na hora e fica gravado em `build\android\GERACAO-COMPLETA.log`. A janela termina sozinha.

3. O APK fica em **`APK-Pronto\LazerShot-Mali450.apk`**. Copie para o pendrive e instale na TV Box.

   No fim aparece **APK PRONTO E CONFERIDO**. Antes disso o gerador confere o APK por dentro (o motor ARM 32 e 64 bits, os scripts e as imagens em ETC1) e a assinatura, pelo próprio apksigner do Android SDK. As mensagens técnicas do Godot que não são problema (PC sem placa de som, por exemplo) não aparecem na janela; ficam só no histórico.

O que o PC precisa:

- **Android SDK** em `C:\AndroidSdk`, com `platform-tools` e um `build-tools` (é o mesmo dos outros jogos).
- **Java 17** (Eclipse Temurin 17).
- **Godot 3.6.2 e os modelos de exportação:** o gerador baixa sozinho na primeira vez (cerca de 640 MB).
- **Chave de assinatura:** o gerador usa a mesma de sempre (`%APPDATA%\Godot\keystores\debug.keystore`). Se ela não existir, ele cria. Com a mesma chave, o APK novo instala por cima do anterior sem apagar o ranking nem a configuração.

O gerador não usa o Gradle (o jogo não tem plugin). Por isso é mais rápido e não fica preso esperando o Gradle.

### Opções (no Prompt de Comando, dentro da pasta)

| Comando | Para quê |
|---|---|
| `GERAR_APK_MALI450.bat -Giro -1` | A imagem sai de cabeça para baixo: o topo do jogo vai para a direita do HDMI. |
| `GERAR_APK_MALI450.bat -Giro 0` | O monitor já recebe a imagem em pé (sem giro). |
| `GERAR_APK_MALI450.bat -MiraGirada` | A mira anda de lado quando a arma sobe. |
| `GERAR_APK_MALI450.bat -Instalar -Ip 192.168.0.50` | Gera, instala pela rede (adb) e puxa o registro. |
| `GERAR_APK_MALI450.bat -Registro -Ip 192.168.0.50` | Só puxa o registro do Android para `build\android\LOGCAT-TVBOX.txt`. |

O giro também se troca **na própria TV Box**, na CONFIGURAÇÃO do jogo, em "Giro da tela". Não precisa gerar outro APK.

## Na TV Box

- O HDMI fica **deitado (1920x1080)**. O jogo gira a imagem por dentro para o monitor em pé.
- A **arma** é o mouse: o gatilho atira e o botão perto do gatilho recarrega.
- **Zero Delay:** START = botão 0, RECARGA = 1, TIRO = 2, SELECT = 4.
  - O SELECT soma crédito no modo crédito.
  - Os botões podem ser aprendidos de novo na CONFIGURAÇÃO.
- **Abrir a CONFIGURAÇÃO:** segure o SELECT por 3 s nas telas de abertura (ou aperte F10 num teclado).
  - Lá ficam: modo livre ou crédito, tempos, demonstração, efeitos COMPLETO/LEVE, giro da tela, volumes, botões, limpar o ranking e a caixa-preta (como a sessão anterior terminou).
  - É a única tela com informação técnica.
- **Efeitos LEVE** (na CONFIGURAÇÃO) põe metade das partículas. Serve para a TV Box mais fraca de todas.
- **Ritmo automático:** a tela que não segura 60 quadros por segundo passa sozinha para 30 cravados, que fica liso. A TV Box lembra disso.

## Para quem mexe no jogo

- O jogo está em `scripts/` e `scenes/`, em GDScript do Godot 3.
- `scripts/fase.gd` é a base das quatro fases. Cada fase está em `deserto.gd`, `mar.gd`, `bar.gd` e `arena.gd`.
- A arte de `sprites/` sai de `tools/preparar_mali.py`, a partir de `arte_original/` (as imagens da versão 4.6, que o Godot ignora):
  - fundos em JPG 1080x1920, que o Godot comprime em ETC1;
  - alvos em PNG sem compressão e sem mipmaps;
  - máscaras de acerto em `scripts/dados_arte.gd`;
  - sons em IMA-ADPCM.
- Depois de mudar a arte, abra o projeto no Godot 3.6.2 uma vez, para reimportar.
