# Lazer Shot na Pro Ultra 4K / Android 10

Esta branch (`tvbox-ultra-pro`) deixa o Lazer Shot leve o bastante para a TV Box
Pro Ultra e gera o APK. As fases, regras, sons e efeitos são os mesmos do PC.
O projeto continua no Godot 4.6.1 (renderizador Compatibility).

## Gerar o APK (sempre assim)

1. Extraia a pasta inteira num lugar novo do PC.
2. Dê dois cliques em `GERAR_APK_PRO_ULTRA.bat`.
   Precisa do Godot 4.6.1 (em Downloads), do JDK 17 e do Android SDK, igual ao
   Dragon Bowling da Ultra Pro. Os Export Templates 4.6.1 são baixados na
   primeira vez, se faltarem.
3. O APK sai em `APK-Pronto/LazerShot-Pro-Ultra-Android10.apk`. Copie-o para o
   pendrive e instale na TV Box.

A janela fica aberta e o histórico completo vai para
`build/android/GERACAO-COMPLETA.log`.

### Se a imagem ou a mira saírem erradas

- **Imagem de cabeça para baixo** no monitor em pé: gere de novo com
  `GERAR_APK_PRO_ULTRA.bat -Giro -1`.
- **Mira andando de lado** (a arma sobe e a mira vai para o lado): gere de novo
  com `GERAR_APK_PRO_ULTRA.bat -MiraGirada`. Os dois podem ir juntos:
  `GERAR_APK_PRO_ULTRA.bat -Giro -1 -MiraGirada`.

## Tela em pé na TV Box

O HDMI da TV Box sai deitado e o monitor da máquina está em pé. O jogo gira a
imagem 90° por dentro (`scripts/Tela.gd`), como o Dragon Bowling da Ultra Pro:
ocupa a tela inteira, sem faixas pretas. Para as cenas nada muda, elas
continuam vendo uma tela em pé (1024 de largura; a altura cresce para
preencher, como no PC com o monitor em pé).

A arma manda a posição no sentido do monitor em pé. Cada movimento e clique
dela é corrigido antes de chegar ao jogo, tanto nas fases (mira pelo movimento)
quanto nos menus e no ranking (mira pela posição). No PC nada disso é ativado.

## O que deixava o jogo pesado, e o que mudou

Medido no Godot 4.6.1 com as quatro fases e os menus, mira e tiros
automáticos, antes e depois.

| Onde | Problema | Correção |
| --- | --- | --- |
| Vídeos | Teasers em 1080x1920 e fundo do deserto decodificados pelo processador a cada quadro (156 MB). | Reencodados em 576x1024 / 576x864 / 512x768, mesmo formato e proporção (34 MB, ~4x menos pixels por quadro). |
| Imagens | 23 folhas grandes sem compressão na placa de vídeo (~130 MB de memória). | Compressão de vídeo ETC2 no Android (~33 MB). As folhas das garrafas ficaram sem compressão, porque o teste de acerto lê os pixels delas. |
| Bar | Cada tiro errado deixava uma marca permanente, e a fase inteira era redesenhada a cada quadro até o fim da partida (os objetos desenhados subiam de 800 para 3700). | Prateleiras e marcas em camadas próprias, redesenhadas só quando entra uma marca; ficam as 80 mais recentes. |
| Bar | Cada tiro pedia à placa de vídeo a folha de sprites inteira da garrafa só para testar um pixel (tranco a cada disparo). | A imagem de cada folha é lida uma vez e guardada, logo que a fase abre. |
| HUDs das fases e menus | Fonte, cor, contorno e estilo dos painéis eram reaplicados a cada quadro em dezenas de textos; cada troca refaz o texto inteiro. | `scripts/Leve.gd`: só aplica quando o valor muda. O resultado na tela é o mesmo. |
| Menu inicial | Modo do mouse trocado duas vezes por quadro (no Android isso passa pela ponte Java). | Só troca quando precisa. |
| FPS | 120 FPS forçados com vsync adaptativo. | No Android: 60 FPS com vsync (a TV é de 60 Hz). No PC continua 120. |
| Arquivos | ~1 GB de pasta: vídeos .webm/.mp4 que o jogo não usa, gravações de tela, imagens e sons sem uso, cenas sem uso com imagens que nem existiam mais. | Tudo que nenhuma cena ou script usa saiu desta branch (continua no `main`). |
| Música | `theme.wav` sem compressão (7,8 MB). | `theme.ogg` (0,7 MB). |
| Configuração | Cena inicial e autoloads apontados por UID (falham numa pasta nova). | Apontados por caminho. |

As sombras suaves dos painéis neon foram mantidas: fazem parte do visual.

## Botões e arma

A entrada continua a mesma: `input_start`, `input_shot` e `input_recharge`
(Zero Delay/joystick), e a arma como mouse (os botões esquerdo e direito
atiram; o do meio e os laterais recarregam). Confira na máquina se os índices de botões da placa são os mesmos.

## Para testar no PC como se fosse a TV Box

```
LAZER_GIRO=1 godot --path . --resolution 1920x1080
```

`LAZER_MIRA_DIRETA=0` testa a mira girada.
