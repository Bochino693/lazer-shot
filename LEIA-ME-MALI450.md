# Lazer Shot 2.6 — TV Box Mali-450

Esta pasta é o **Lazer Shot para a TV Box da placa Mali-450** (S905L / S905W, Android 7.1). A placa de vídeo dela só tem OpenGL ES 2.0, por isso este jogo é feito no **Godot 3.6.2 (GLES2)**. A versão 4.6 (Pro Ultra / TX9) é outro projeto, na branch `tvbox-ultra-pro`.

## Novidades da 2.6

- **A foto do jogador é pedida antes de cada partida.** Depois do START (ou do tiro no alvo do COMO JOGAR) aparece a tela **"SORRIA PARA A FOTO!"**, com a imagem ao vivo da webcam numa foto instantânea grande, a contagem 3-2-1, o clique com flash e a foto pronta ("FICOU ÓTIMO!"). Depois vem a contagem da partida. START pula a foto.
  - A câmera liga quando a fase abre (enquanto o jogador lê o COMO JOGAR) e desliga logo depois da foto.
  - **Câmera reconhecida:** em AUTO o jogo tenta todas as câmeras que o Android vê, da última para a primeira (a webcam USB costuma ser a última; a primeira pode ser a entrada HDMI da TV Box). Antes abria sempre a primeira.
  - Se o Android não deu a permissão, a página CÂMERA da configuração diz "SEM PERMISSÃO" e como liberar.
  - Sem câmera, a pose não aparece e o jogo segue normal.
  - No fim da geração, o gerador diz em verde **"Camera: a foto do jogador esta no APK"** ou em vermelho que ela ficou de fora (e por quê).
- **Céu do Deserto refeito, sem borrões.**
  - De dia, os raios pintados em volta do sol continuam até o centro: um clarão de sol, que fica no céu enquanto ele se põe.
  - De noite, o lugar da lua é preenchido com pedaços das nuvens do próprio céu, com a mesma nitidez do resto.
- **Águias nítidas.** O desenho é 1,6 vez maior e nunca é ampliado na tela; as de longe usam mipmaps (sem serrilhado).
- **Mira casando com a arma a 40-60 cm.**
  - **CONFIGURAÇÃO → ARMA E BOTÕES → Mira da arma → CALIBRAR:** com a mira escondida, aponte a arma no centro de 4 alvos e atire. O jogo mede quanto a seta anda entre os alvos e passa a pôr a mira onde a arma aponta, naquela distância. Vale também quando o Android gira a tela (antes só calibrava no giroscópio).
  - **Alvo de partida:** a arma de giroscópio escorrega com o tempo. No COMO JOGAR, a mira fica escondida e aparece o alvo **"APONTE A ARMA NO ALVO E ATIRE"**: o tiro nele recoloca a mira onde a arma aponta, a cada partida. Um tiro muito longe do alvo não mexe na mira. Desliga em ARMA E MIRA → Alvo de partida.
  - Mexer na sensibilidade com − e + desfaz a calibragem.
- **Botão ALEATÓRIO** na escolha de cenário: a roleta sorteia o cenário na hora.
- **Vídeo da tela inicial de volta.** Ele sumia quando a TV Box achava a tela pesada. Agora somem os outros enfeites e a tela vai a 30 quadros/s, mas o vídeo fica (só a CONFIGURAÇÃO desliga).
- **Música contínua.** Sem som de fim de partida: a música da fase segue no resultado e na tela do nome. Toda música recomeça sozinha se acabar com a tela ainda aberta (a do ranking também).
- **Telas sem sobreposição:**
  - o quadro da contagem da escolha de cenário não cobre mais o logo Lazer & Sport;
  - na tela inicial, "APERTE START" e o selo JOGO LIVRE saíram de cima do logo LAZER SHOT.

## Da 2.5

- **Deserto:** o sol e a lua pintados saíram do fundo. Na troca do dia, o sol fecha o olho e se põe atrás das pirâmides, e a lua nasce do mesmo lugar.
- **Olho do sol e da lua mais natural:** movimentos rápidos de olho de verdade, piscada, pupila e brilho na íris, pálpebra no tom do disco.
- **Águias voando de lado**, com a cabeça para a frente, em três distâncias (as de longe passam atrás das pirâmides).
- **Mais vida no Deserto:** estrelas piscando e estrelas cadentes de noite; rajadas de areia de dia.
- **Sons que não se cortam:** até 6 vozes por som e 24 no total; o limitador só segura o pico.
- **Foto do jogador pela webcam USB**, no resultado e no ranking. Na primeira vez o Android pergunta se o jogo pode usar a câmera: escolha **Permitir**. A página **CÂMERA** fica em CONFIGURAÇÃO → RANKING E FOTO.

## Da 2.4

- **Só a mira na tela, sem a seta do mouse.** No Android 7 o Godot 3.6 não esconde a seta, e muitas TV Box ignoram a seta transparente que o jogo punha no lugar. Por isso a seta aparecia junto com a mira e, com a tela girada, andava ao contrário.
  - Agora o gerador faz uma cópia dos modelos do Godot (em `build\android\modelos`) em que todos os formatos de seta viram o "nenhum" do Android. É o mesmo jeito que os outros jogos de tiro usam.
  - Os modelos originais não mudam. A cópia é feita uma vez (cerca de 1 minuto) e refeita só se os modelos mudarem.
  - **Precisa gerar o APK de novo** com este gerador. Na janela aparece "Seta do mouse: escondida pelo Android".
- **Som firme no Mar e em todas as fases.** Muitos tiros, recargas e estouros juntos não cortam mais o som do jogo.
  - Os efeitos passam por um limitador antes de somar com a música, e a saída também tem um limitador. O estouro da mistura é que cortava o som todo.
  - No máximo 10 efeitos tocam ao mesmo tempo. O mesmo som repetido em menos de 45 ms toca uma vez só.
  - A folga do som é maior (100 ms), para a TV Box não engasgar.
- **Nada bate no chão e quebra.** Pote, baú e bomba do Mar, cacos de garrafa, cacos da janela do Bar, gotas e lascas passam reto pela tela. Assim que saem da tela, somem e param de gastar processamento.

## Da 2.3

- **Bar com profundidade.** As garrafas pisam nas prateleiras de verdade: nas duas de cima ficam atrás da beirada da tábua; nas duas de baixo, no meio do tampo. Antes a de cima ficava na frente da tábua e a de 80 flutuava.
  - Sombra macia de cada garrafa na parede (a luz vem da janela) e sombra no tampo das prateleiras de baixo.
  - O facho de sol passa na frente das garrafas, com a poeira, e as que estão dentro dele brilham em contraluz. De vez em quando um reflexo corre no vidro.
  - Quando uma garrafa estoura ou a tábua leva tiro, as vizinhas balançam. A bebida molha a parede e o tampo e seca devagar. O lugar da garrafa estourada fica vazio um instante.
- **Tiro atrás de tiro sem travar.** Testado com 8 tiros por segundo a partida inteira nas 4 fases e com as 4 fases seguidas, várias vezes: a memória fica igual de uma partida para outra.
  - A caixa-preta grava em segundo plano. A escrita na memória da TV Box podia travar o jogo por um instante a cada 15 s.
  - Os clarões e os furos do Bar são reaproveitados, e tudo o que o tiro deixa (cacos, furos, marcas) tem limite.
  - No Mar, os furos no navio não tinham limite (agora no máximo 14) e o rastro de bolhas do laser ficou bem mais leve.
  - Na tela que a TV Box acha pesada, os tiros soltam menos estilhaços, além de os enfeites sumirem.
- **Sensibilidade da mira na CONFIGURAÇÃO principal:** ARMA E BOTÕES → **Sensibilidade da mira** (− AUTO + e o AJUSTAR ao lado).
  - **AUTO:** a mira acompanha a arma (em cima da seta quando o Android gira a tela).
  - **Um número:** a mira anda mais (+) ou menos (−) que a arma e ainda chega nas bordas.

## Da 2.2

- **Mira coerente com a arma, sem pular.**
  - O app abre deitado e pede ao Android a tela em pé. Se a TV Box girar de verdade, a **seta do mouse anda junto com a arma** e a mira fica em cima dela, com um filtro leve que tira o tremor da mão parada.
  - Se a TV Box não girar (ou puser o app numa faixa estreita no meio da tela, sem girar), o jogo volta a ficar deitado e gira a imagem por dentro, sozinho. A mira soma o movimento da arma na medida certa: de uma beirada à outra do HDMI ela percorre a tela inteira, sem salto na beirada. A TV Box lembra a resposta e não tenta de novo.
  - Sem coice: o tiro sai exatamente onde a mira está.
  - Na CONFIGURAÇÃO, "Quem gira a tela" mostra quem está girando agora.
- **START separado da recarga.** A recarga é o **clique direito** da arma (o botão perto do gatilho), que nunca dá START. O START são os **outros botões do lado** (o do meio, os laterais e o VOLTAR). Na partida, qualquer botão do lado recarrega.
- **Munição em balas:** o placar mostra os 30 cartuchos (duas fileiras de 15), sem escrever MUNIÇÃO. O cartucho gasto apaga; com pouca munição eles piscam em laranja, sem munição em vermelho, e na recarga voltam um a um.
- **Vídeo na tela inicial:** o corredor do estande em movimento, o mesmo da versão 4.6, em tamanho leve para a Mali-450. Desliga na CONFIGURAÇÃO → "Vídeo da tela inicial".
- **Mais nítido:** as águas-vivas, o baú e a bomba do Mar e as lanternas da Arena foram refeitos em tamanho maior (não são mais ampliados na tela).
- **Leve e firme:** a tela que não segura 60 quadros por segundo primeiro desliga os enfeites (o vídeo inclusive) e a mira continua a 60. Só se ainda assim não der, ela passa a 30 cravados.
- **Bar:** a garrafa verde (caveira) não flutua mais acima da prateleira; pisa na tábua como as outras.

## Da 2.1 (continua valendo)

- **Ajuste da arma na própria TV Box:** CONFIGURAÇÃO → BOTÕES → **Arma e mira** → AJUSTAR.
  - Tipo de arma (AUTO, SETA ou GIROSCÓPIO), sensibilidade (AUTO ou um número; também na página principal) e a compensação da aceleração do Android.
  - **CALIBRAR** (quando o jogo gira por dentro): atire nos 4 alvos que aparecem. O jogo mede quanto a arma anda e acerta a sensibilidade sozinho.
  - Alvos de teste nos cantos e no meio: atire neles para conferir.
- **Abertura sem o símbolo do Godot:** ao abrir o jogo aparece o logo da Lazer & Sport, já em pé no monitor.
- **O tiro de cada cenário** sai da arma, embaixo da tela, até a mira:
  - **Bar:** bala de revólver, sem laser (o clarão da boca da arma e a bala traçante; no ponto, faísca e fumaça);
  - **Egito de dia:** laser amarelo; **de noite:** laser branco;
  - **Mar:** laser cor de água, com bolhas pelo caminho;
  - **Arena:** o laser vermelho da abertura (faíscas em brasa no ponto).
- **Janela do Bar com desenho próprio e destruição de verdade:** cada tiro estoura a vidraça (trincas saindo do furo, cacos do próprio vidro caindo e quicando na tábua, pontas presas na moldura, as vizinhas trincando, o céu aparecendo pelo buraco e o sol entrando mais forte).
  - Os **5 primeiros tiros** na janela valem **+50** cada.
  - No 5º, o resto do vidro desaba e a janela não dá mais pontos.
- **Deserto: o cristal quebrado corta a energia.**
  - A energia já cai e pisca a cada tiro no cristal.
  - Quebrado, os feixes estalam e apagam, os cristais dos obeliscos e as pontas de ouro das pirâmides escurecem e o cristal não carrega (sem POWER OF RA!).
  - Quando ele se refaz, a energia volta correndo do cristal até os obeliscos.
  - Cristal de um obelisco quebrado corta só aquele lado.

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
- **Os bônus continuam valendo pontos:** barril (+40 por furo), janela do bar (+50 nos 5 primeiros tiros), cristal (+300), pontas dos obeliscos (+150), peixes dourados (+40 cada), LED do alto da Arena (+50).
- **Os efeitos de tiro voltaram em todas as telas:** o traço do tiro, o pulso da mira e as faíscas.
- **As telas são as mesmas:**
  - abertura Lazer & Sport GAMES;
  - tela inicial com APERTE START;
  - demonstração dos cenários e vitrine do ranking;
  - escolha de cenário com roleta e missão;
  - como jogar, contagem, fim de jogo e nome no ranking;
  - ranking dos 20 melhores e configuração.
- **Sem shader de tela cheia** (a Mali-450 engasga com isso). O único vídeo é o da tela inicial, leve (540x960, VP8). Os fundos das fases ganham vida com luz somada e partículas.
- **Câmera:** a foto do jogador sai da webcam USB da TV Box no começo da partida, sem a tela de pose da 4.6. Sem câmera, o ranking mostra a silhueta.
- **O APK tem outro nome de pacote** (`com.lazersport.lazershot.mali`). Ele instala ao lado da versão 4.6, não por cima.

## Gerar o APK (no PC com Windows)

1. Baixe a branch **`tvbox-mali450`** numa **pasta nova e vazia**, com caminho curto, por exemplo `C:\LazerShotMali`.

   > Não extraia por cima da pasta da versão 4.6. O gerador percebe a mistura e para.

2. Dê dois cliques em **`GERAR_APK_MALI450.bat`**.

   Tudo aparece na janela na hora e fica gravado em `build\android\GERACAO-COMPLETA.log`. A janela termina sozinha.

3. O APK fica em **`APK-Pronto\LazerShot-Mali450-2.6.0.apk`** (a versão vai no nome do arquivo). Copie para o pendrive, use **Ejetar** no Windows antes de tirar o pendrive e instale na TV Box.

   No fim aparece **APK PRONTO E CONFERIDO**, com a linha **Assinatura: v1 + v2**. Antes disso o gerador confere o APK por dentro: o motor ARM 32 e 64 bits, os scripts e as imagens em ETC1. As mensagens técnicas do Godot que não são problema (PC sem placa de som, por exemplo) não aparecem na janela; ficam só no histórico.

   **A assinatura é feita pelo próprio gerador.** Ele chama o `apksigner.jar` do build-tools direto pelo Java e confere as assinaturas v1 e v2. Se o apksigner falhar, assina pelo `jarsigner` do Java (só a v1, que a TV Box também aceita).

   Nas versões 2.0.0 e 2.0.1, quem assinava era o Godot, pelo `apksigner.bat` do SDK. Em SDK sem o pacote antigo "tools", esse `.bat` termina sem fazer nada e sem dar erro. O APK saía sem assinatura e a TV Box dizia **"o pacote parece estar corrompido"**.

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
| `GERAR_APK_MALI450.bat -JogoGira` | Nem pede ao Android a tela em pé: o jogo sempre gira por dentro. |
| `GERAR_APK_MALI450.bat -Instalar -Ip 192.168.0.50` | Gera, instala pela rede (adb) e puxa o registro. |
| `GERAR_APK_MALI450.bat -Registro -Ip 192.168.0.50` | Só puxa o registro do Android para `build\android\LOGCAT-TVBOX.txt`. |

O giro e quem gira também se trocam **na própria TV Box**, na CONFIGURAÇÃO do jogo, em "Giro da tela" e "Quem gira a tela". Não precisa gerar outro APK.

### Se o APK não sair

- **"O APK nao saiu (codigo 1853227063)" ou erro da NVIDIA:** o código é `0x6E760037`, o driver da placa de vídeo NVIDIA fechando o Godot ("Error code 7"). Acontece em placa antiga, como a GeForce 8400GS.
  - Desde esta versão o gerador monta o APK sem desenhar nada (`--disable-render-loop`): a placa só abre o OpenGL e fica parada. O APK sai igual, arquivo por arquivo.
  - Se ainda acontecer: reinicie o PC, feche jogos e navegadores e rode de novo. Se continuar, reinstale o driver da placa (para a 8400GS, o último é o 342.01) ou gere o APK em outro PC.
  - Quando falha, o gerador mostra as últimas linhas do Godot e o motivo da saída.
- **"AVISO: o build-tools do Android SDK nao tem o d8" ou "o d8 nao converteu a classe da camera":** o APK sai, mas sem a foto do jogador. O d8 vem no build-tools do Android SDK (versão 28 ou mais nova) e precisa do Java 11 ou mais novo (o gerador prefere o 17). Instale um build-tools novo pelo sdkmanager e rode de novo. O motivo fica em `build\android\d8.log`.
- **"AVISO: nao deu para preparar os modelos do Lazer":** o APK sai, mas com a seta transparente antiga, que algumas TV Box ainda mostram. Apague a pasta `build\android\modelos` e rode de novo. Se continuar, apague também a pasta dos modelos do Godot (`%APPDATA%\Godot\templates\3.6.2.stable`) para eles baixarem de novo.

### Se a TV Box não instalar

1. **"O pacote parece estar corrompido":** gere o APK de novo com esta versão (2.0.2 ou mais nova) e confira a linha **Assinatura** no fim da janela. Apague da TV Box (ou do pendrive) o APK antigo e copie o novo.
2. **Arquivo copiado pela metade** também dá "corrompido": no Windows, use sempre **Ejetar** antes de tirar o pendrive.
3. **"Conflito com um pacote existente":** já existe na TV Box um Lazer Shot Mali assinado com outra chave (de outro PC). Desinstale-o e instale o novo. O ranking e a configuração dele se perdem.
4. **Para ver o motivo exato:** ligue a depuração (ADB) na TV Box e rode `GERAR_APK_MALI450.bat -Instalar -Ip IP-DA-TVBOX`. O gerador instala pela rede e mostra a resposta do Android.

## Na TV Box

- O HDMI sai **deitado** e o monitor fica **em pé**. Deixe a TV Box em **1080p** (Configurações → Tela → Resolução): em 720p tudo fica menos nítido.
- **Quem gira a imagem:** ao abrir, o jogo pede ao Android a tela em pé.
  - Se a TV Box girar, a **seta do mouse anda junto com a arma** e a mira fica em cima dela. É o melhor jeito.
  - Se não girar, o jogo gira por dentro sozinho. A seta do mouse fica escondida nos dois casos (desde a 2.4, gerando o APK com este gerador).
  - Para a TV Box girar: se ela tiver **Configurações → Tela → Rotação da tela** (o nome muda de uma para outra), escolha **Original** (ou "seguir o app"). Nas TV Box Amlogic, as opções do tipo "retrato no meio" (middle_port) e "forçar paisagem" (force_land) não giram. Depois, na CONFIGURAÇÃO do jogo, toque em **AUTO** em "Quem gira a tela" para ele tentar de novo.
  - **Imagem de cabeça para baixo:** CONFIGURAÇÃO → "Giro da tela" → troque ESQUERDA por DIREITA.
- A **arma** é o mouse: o **gatilho** atira; o **clique direito** (o botão perto do gatilho) recarrega; os **outros botões do lado** dão START (na partida, também recarregam).
- **A mira não cai onde a arma aponta:** CONFIGURAÇÃO → ARMA E BOTÕES → **Mira da arma → CALIBRAR**. Fique na distância de jogo (40 a 60 cm da tela), aponte a arma no centro de cada um dos 4 alvos e atire (a mira fica escondida: olhe pela arma, não pela mira). Depois atire nos alvos de teste para conferir e toque em SALVAR. A cada partida, o tiro no alvo do COMO JOGAR acerta o que a arma escorregou. Se a mira ainda correr demais, diminua a **Velocidade do ponteiro** nas configurações do Android (Idioma e entrada) e calibre de novo.
- **Zero Delay:** START = botão 0, RECARGA = 1, TIRO = 2, SELECT = 4.
  - O SELECT soma crédito no modo crédito.
  - Os botões podem ser aprendidos de novo na CONFIGURAÇÃO.
- **Abrir a CONFIGURAÇÃO:** segure o SELECT por 3 s nas telas de abertura (ou aperte F10 num teclado).
  - Lá ficam: modo livre ou crédito, tempos, demonstração, efeitos COMPLETO/LEVE, vídeo da tela inicial, giro da tela e quem gira, volumes, botões, limpar o ranking, a foto do jogador (e a página CÂMERA) e a caixa-preta (como a sessão anterior terminou).
  - É a única tela com informação técnica.
- **Efeitos LEVE** (na CONFIGURAÇÃO) põe metade das partículas. Serve para a TV Box mais fraca de todas.
- **Ritmo automático:** a tela que não segura 60 quadros por segundo primeiro fica sem enfeites; se ainda não der, passa sozinha para 30 cravados, que fica liso. A TV Box lembra disso.

## Para quem mexe no jogo

- O jogo está em `scripts/` e `scenes/`, em GDScript do Godot 3.
- `scripts/fase.gd` é a base das quatro fases. Cada fase está em `deserto.gd`, `mar.gd`, `bar.gd` e `arena.gd`.
- A estante do Bar (onde cada garrafa pisa, as beiradas desenhadas por cima e a luz) está no começo de `scripts/bar.gd`, medida no `fundo_bar`. As sombras das garrafas (`sprites/bar_sombra_*.png`) saem de `tools/preparar_mali.py` (`SO_BAR=1`).
- A arte de `sprites/` sai de `tools/preparar_mali.py`, a partir de `arte_original/` (as imagens da versão 4.6, que o Godot ignora):
  - fundos em JPG 1080x1920, que o Godot comprime em ETC1;
  - alvos em PNG sem compressão e sem mipmaps;
  - máscaras de acerto em `scripts/dados_arte.gd`;
  - sons em IMA-ADPCM.
- Depois de mudar a arte, abra o projeto no Godot 3.6.2 uma vez, para reimportar.
- Quem gira a tela está em `scripts/tela.gd`: o app abre deitado, lê `persist.sys.app.rotation` (Amlogic), pede o retrato e confere pela janela (em pé do tamanho da tela inteira = o Android girou; faixa no meio ou nada em 5 s = o jogo gira por dentro). A resposta fica em `user://tela.cfg`. No PC dá para fingir a TV Box com `LAZER_GIRO=1` e `LAZER_PROP_ROTACAO`.
- A mira da arma está em `scripts/mira_global.gd` (a seta com filtro 1€ quando o Android gira; giroscópio, aceleração do Android e beiradas quando o jogo gira) e o ajuste dela em `scripts/config.gd` (página Arma e mira).
- O vídeo da tela inicial é `videos/back_init.webm` (VP8, 540x960, 24 quadros/s, sem som), feito do `back_init.mp4` da versão 4.6 com o ffmpeg: `-vf "crop=698:1088:11:0,scale=540:960:flags=lanczos" -r 24 -c:v libvpx -b:v 1500k -crf 8 -qmin 4 -qmax 40 -auto-alt-ref 0 -g 48 -an`.
- A foto do jogador: `scripts/foto_jogador.gd` (o autoload FotoJogador) chama a classe Java `android_camera/src/org/lazershot/CameraFoto.java` pelo JavaClassWrapper; a pose é `scripts/pose_foto.gd`. A classe é compilada em `android_camera/camera_foto.jar` por `android_camera/COMPILAR.sh` (javac, com as assinaturas do Android em `android_camera/stubs/`). No PC dá para testar com `LAZER_CAMERA_FALSA=foto.jpg`.
- O céu do Deserto sem o astro (raios de dia, remendos de nuvem de noite), a águia de lado e o recorte das camadas do olho saem de `tools/preparar_mali.py` (`SO_EGITO=1`, cerca de 2 minutos).
- A abertura do Android (no lugar do símbolo do Godot) está em `splash/`, uma imagem para cada giro, feita por `tools/preparar_mali.py`. Como o app abre deitado, o gerador escolhe a já girada para o lado do giro pedido.
