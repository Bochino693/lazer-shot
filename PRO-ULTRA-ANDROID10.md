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

### Se o jogo não abrir ou fechar sozinho na TV Box

O jogo não mostra nada técnico na tela. Por trás, ele tem duas proteções:

- **Caixa-preta** (`scripts/caixa_preta.gd`): grava em silêncio o aparelho,
  a placa de vídeo, a memória, cada troca de tela, cada erro e um pulso a
  cada 30 s. Cada linha vai para o disco na hora. A última sessão que parou
  sozinha em menos de 10 min fica guardada como `queda.txt`.
- **Contorno pontual** (só na TV Box): o jogo avisa quando entra num trecho
  que depende do aparelho (a apresentação Lazer & Sport, um vídeo começando
  pelo decodificador da TV Box). Se o app morrer **dentro** desse trecho, só
  ele é contornado nas próximas aberturas desta versão: a apresentação é
  pulada, ou os vídeos passam a tocar pelo player do Godot. Todo o resto do
  jogo continua igual. Instalar uma versão nova zera tudo.

Para ver o que aconteceu, sem cabo: no gerenciador de arquivos da TV Box,
abra `Android/data/com.lazersport.lazershot/files/caixa_preta` e copie
`queda.txt`, `anterior.txt` e `sessao.txt` para o pendrive.

Com adb (TV Box com a depuração ligada, no cabo ou com
`adb connect IP-DA-TVBOX`):

```
GERAR_APK_PRO_ULTRA.bat -Registro
```

Ele abre o jogo, espera 40 s e salva `build/android/LOGCAT-TVBOX.txt` e a
pasta `build/android/caixa_preta`. Com `-Instalar`, o mesmo acontece logo
depois de instalar o APK novo.

A versão do APK aparece em Configurações > Apps da TV Box (1.24.0, código 26).

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

A arma funciona como mouse: o **gatilho** atira. Dos 4 botões dela, só os
**dois do lado direito** são usados:

| Botão (lado direito) | Função | Padrão |
| --- | --- | --- |
| Perto do **bico** | **START** | nenhum: aprenda na configuração |
| Perto do **gatilho** | **RECARGA** | clique direito, meio, laterais e o VOLTAR do Android |

O botão perto do gatilho manda o **VOLTAR do Android**, que antes **fechava o
jogo**. Agora o VOLTAR nunca fecha o jogo: vira recarga (ou START, se ele
for o START aprendido).

**Para gravar os botões da arma:** abra a configuração, atire em **APRENDER**
ao lado de "START na arma" (ou "RECARGA na arma") e aperte o botão na arma.
O mesmo botão não pode ser START e RECARGA. A Zero Delay/joystick continua com
`input_start`, `input_shot`, `input_recharge` e `input_select`; o START e o
SELECT dela também se aprendem ali. Fica gravado (não precisa gerar outro
APK). Padrões da Zero Delay: START = botão 0, SELECT = botão 4.

## Modo de jogo: LIVRE ou CRÉDITO

- **LIVRE (padrão):** o START começa a partida sem cobrar nada.
- **CRÉDITO:** cada aperto do **SELECT da Zero Delay** (onde se liga o
  moedeiro/noteiro) soma 1 crédito, com som de ficha. O START só começa (ou
  "joga novamente") se houver créditos suficientes e desconta os créditos da
  partida; sem crédito aparece **INSIRA CRÉDITO**. Os créditos ficam guardados
  mesmo desligando a máquina.
- A tela inicial mostra o selo **JOGO LIVRE** ou **CRÉDITOS 03**; nas outras
  telas ele aparece por alguns segundos quando entra ficha.
- Contadores de **fichas** e **partidas** na configuração (com zerar).

## Configuração (F10 ou SELECT segurado 3 s)

Abre com **F10** (teclado) ou **segurando o SELECT por 3 segundos** na tela
inicial, no ranking ou na escolha de cenário. Feita para a arma: aponte e atire
nos botões (também funciona com mouse, ou setas + START).

| Item | O que faz |
| --- | --- |
| Modo de jogo | LIVRE / CRÉDITO |
| Créditos por partida | quantos créditos cada partida custa (1 a 10) |
| Créditos na máquina | ajusta ou zera os créditos atuais |
| Tempo de partida | 0:30 a 10:00 |
| Dificuldade | FÁCIL / DIFÍCIL (difícil = sem mira na tela) |
| Tela de resultado / Nome no ranking | tempos dessas telas (padrão: volta ao início em 17 s sem START; nome em 50 s) |
| Tempo da abertura / Tempo do vídeo | ciclo da tela inicial |
| Vídeos de demonstração / Ranking na abertura | liga e desliga cada parte do ciclo |
| Música / Efeitos | volumes (agora valem no jogo inteiro) |
| START na arma / RECARGA na arma | APRENDER os botões do lado direito da arma |
| START / SELECT na Zero Delay | APRENDER o botão da Zero Delay |

**SALVAR E SAIR** grava; **SAIR SEM SALVAR** descarta; **PADRÃO** (dois tiros)
volta aos valores de fábrica sem apagar créditos e contadores. Tudo fica em
`user://config_admin.cfg` e é lido já no boot.

## Rodada 2: liso na TV Box, transições e efeitos novos

**Desenhos por quadro** (pior momento, com tiros; antes → agora):

| Fase | Antes | Agora |
| --- | ---: | ---: |
| Mar | 1874 | 113 |
| Bar | 603 | 123 |
| Deserto | 394 | 82 |
| Arena | 311 | 42 |

O que pesava: cada círculo, arco, linha e polígono dos efeitos e das miras era
um desenho separado na placa de vídeo (bolhas do mar, furos de bala, cacos,
teias dos alvos do deserto com 18 linhas cada). Agora tudo sai de recortes de
uma textura só (`sprites/pincel.png`, gerada por `tools/gerar_pincel.py`) e o
Godot junta em lote (`scripts/pincel.gd`).

**Sem tela cinza:** todas as trocas de tela passam pela `TransicaoGlobal`:
escurece, carrega a próxima cena numa thread por trás do preto (anel girando se
demorar), deixa a cena nova montar escondida e clareia. Fundo e boot pretos.
Testado quadro a quadro: nenhum quadro cinza ou branco.

**Mais vida:**
- **Mar:** as duas baleias foram recortadas da foto do fundo e nadam na água
  aberta (surgem da névoa, batem a cauda, sobem e descem e somem na distância);
  as 8 cachoeiras escorrem (recortes do próprio fundo com shader).
- **Bar:** a garrafa estoura em cacos da **própria imagem**, rachando a partir do
  ponto do tiro; os cacos batem na prateleira, quicam e deitam, ou caem pela
  beirada, brilham na luz e o líquido espirra na cor da bebida. Três estilos se
  revezam (estouro, desaba, gargalo voando). Feixe de sol da janela com poeira
  brilhando.

**Letras:** fonte Exo 2 (licença OFL, em `fonts/`) no lugar da Orbitron e como
fonte padrão do jogo; a LuckiestGuy continua nos títulos.

## Rodada 3: rápido, jogável e sem telas estranhas

**Ritmo de quadros:** na TV Box só o vsync manda (60 Hz da TV). O limitador do
motor também em 60 brigava com ele e de tempos em tempos perdia um quadro (a
"travadinha" constante).

**Carregamento vivo:** a cena e os arquivos que ela lê ao abrir
(`scripts/precarga.gd`, gerado por `tools/gerar_precarga.py`) carregam em
threads. Ao entrar numa fase aparece um cartão com a capa, o nome, uma dica e a
barra de progresso real, que termina em **PRONTO**. O quadro preso ao abrir a
fase caiu pela metade (bar 362 → 164 ms no PC de teste). Se um script passar a
carregar arquivos novos, rode `python3 tools/gerar_precarga.py` de novo.

**Egito (Deserto Sagrado):**
- os dois vídeos de fundo (esticados e decodificados na CPU o tempo todo)
  viraram imagens fixas em alta, enquadradas sem esticar; um shader anima só os
  feixes, o cristal e o sol/lua. A troca sol/lua tem cruzamento suave. A marca
  d'água da versão noite saiu;
- ritmo: 5 alvos no começo (no máximo 9 com o nível), um novo a cada ~0,85 s,
  120-185 px/s, 3,6-4,6 s na tela e troca de brasão rara e perceptível; as
  batidas nas bordas não aceleram mais os alvos.

**Mira 30% maior em todas as telas** (`Pincel.ESCALA_MIRA = 1.3`).

**Menu de cenários:** escolha automática em 10 s, roleta que gira em volta dos
cards e freia (~1-1,4 s), dificuldade em 8 s; sem escolha, vale a dificuldade
padrão da configuração.

**Imagem:**
- as prévias (arena, bar, deserto, mar) foram refeitas dos originais sem as
  marcas BANDICAM/clideo;
- o vídeo de fundo do menu, da abertura e do ranking fica em tela cheia (ver
  rodada 4).

**Menos pintura por quadro:** flash e dano do Mar só são desenhados enquanto
aparecem; o fundo preto repetido do menu saiu; o feixe de sol do bar pinta só
a faixa acesa (28% da tela em vez de 100%).

## Rodada 4: mira estável, menu liso e ranking padronizado

**A arma é o mouse, e a mira é uma só** (`scripts/MiraGlobal.gd`): o ponteiro
fica sempre capturado (nenhuma tela troca o modo, o que no Android fazia a mira
pular), cada movimento da arma soma na mesma mira com a sensibilidade do botão
MIRA do menu, um filtro leve tira o tremor da mão sem atrasar o movimento, e a
mira continua no mesmo lugar ao trocar de tela. O direcional do controle não
mexe mais a mira. Na configuração o gatilho aperta o botão sob a mira; no ajuste
de sensibilidade, o tiro no slider leva o valor até o ponto acertado.

**Escolha de cenário sem tranco:** cada vídeo do menu (fundo + 4 prévias) é
aberto uma vez só, ainda com a tela escura; só o vídeo que está na tela
decodifica, o que sai congela no último quadro enquanto o novo surge por cima,
e o card precisa ficar sob a mira um instante (0,22 s) para trocar. Antes,
durante a roleta e o modal, o vídeo era recarregado e reiniciado a cada quadro.
Na abertura a prévia também já fica pronta e entra por cima do vídeo inicial.

**Vídeos em tela cheia**, sem faixas: o fundo 2:3 preenche a tela 9:16 cortando
no máximo 1,5% de cada lado (logo e título ficam inteiros) e o resto vira um
ajuste leve de escala.

**Ranking igual em todas as fases** (`scripts/nome_ranking.gd`): teclado com a
tecla sob a mira acesa, letras que entram com um estalo, casas do nome com
cursor, tempo em barra; SALVAR, START ou o fim do tempo salvam (vazio vira
ANONIMO). Depois do nome a tela de resultado volta sozinha ao início em
**17 s** se ninguém apertar START, em todas as fases (configurável; quem tinha
o padrão antigo de 21 s passa para 17). O contador não mostra mais 9999.

**Letras:** todos os textos usam a Exo 2 (a LuckiestGuy desenhava alguns "O"
menores e fora da linha); acentos e símbolos (🏆 ▶ ★ ✔ ⌫) saem das fontes do
próprio jogo, iguais na TV Box e no PC.

## Rodada 5: fundos vivos, sem vídeo pesado, e partida sem engasgo

**Fundo vivo no lugar dos vídeos** (`scripts/fundo_vivo.gd` +
`shaders/fundo_vivo.gdshader`): na TV Box o vídeo é decodificado pelo
processador a cada quadro (5 a 8 vezes mais lento que no PC); era o grosso das
travadas do menu e da abertura. Agora abertura, menu de cenários e ranking usam
uma imagem que ganha vida na placa de vídeo: luzes que piscam e sobem com o
grave da música, chão e água ondulando com reflexo, brilho grande na batida,
zoom lento ("respiração"), uma faixa de brilho que cruza a tela de tempos em
tempos e faíscas subindo. Sem música tocando, um pulso calmo próprio mantém
tudo em movimento. Uma máscara por imagem (R = luzes, G = superfícies,
B = brilho da batida) diz onde cada efeito acontece; elas são geradas por
`tools/gerar_fundos_vivos.py`.

- **Menu:** a mira sobre um cartão troca o fundo para a arte daquele cenário
  (Egito com o mesmo fundo animado da fase, Mar, Bar, Arena), com cruzamento
  suave; a roleta e o modal de dificuldade também mostram o cenário da vez.
  Todos os fundos ficam prontos (e já desenhados uma vez) sob a transição, então
  o primeiro passar da mira não engasga.
- **Abertura e ranking:** o vídeo `back_init` saiu; o fundo vivo usa um quadro
  dele. O único vídeo que sobrou é a prévia do modo demonstração, agora em
  432x768 e 24 quadros (cerca de 40% menos trabalho de decodificação) e só
  enquanto aparece.
- **Abertura:** o efeito de entrada só começa com a tela estável (depois da
  transição e de 4 quadros seguidos no ritmo), e não mais nos primeiros quadros,
  que são os mais pesados de qualquer tela.

**Egito vivo:** a energia dos feixes corre mais rápido e mais forte com o grave,
o cristal acende na batida e solta uma onda de luz pelo cenário, raios giram em
volta do sol/da lua, o ar tremula no horizonte, a imagem respira devagar,
faíscas sobem do cristal e poeira dourada (azulada à noite) atravessa a tela.

**Partida sem engasgo:**
- Egito: cada alvo novo copiava a cena inteira do alvo (`duplicate()` padrão,
  ~1,5 ms no PC, ~10 ms na TV Box, um tranco a cada alvo). Agora copia só os
  nós (~0,1 ms, mesmo alvo).
- Egito: o estilo dos cartões do HUD era refeito todo quadro (157 µs → 9 µs);
  isso também apagava o aviso do cartão TEMPO, que agora fica laranja nos 30 s
  finais e vermelho nos 10 s finais como deveria.
- Egito: as teias de luz dos alvos redesenham ~6 vezes por segundo em vez de
  todo quadro.
- Arena: as marcas de laser na parede só são redesenhadas quando há fumaça
  animando ou marca nova.

Medição no PC de teste (pior quadro de cada segundo, só processador, com tiros
a cada 0,35 s; varia de uma medição para outra): abertura 0,3 ms, menu
~1 ms (antes ~3,8 ms com vídeo), ranking 0,8 ms, Egito 1,6–2,1 ms (antes
2,8–3,6 ms), Arena 2,0–2,6 ms, Bar ~1,9 ms, Mar 2,3–2,9 ms. Na TV Box
multiplique por 5 a 8.

**Pré-carga:** `tools/gerar_precarga.py` agora segue também os componentes
usados por nome (FundoVivo, NomeRanking); cada tela pré-carrega só os fundos
que pede.

## Rodada 6: mira sem pontos cegos e vídeo pelo hardware da TV Box

**Mira da arma** (`scripts/MiraGlobal.gd`). A arma é um mouse com giroscópio.
O jogo pede ao Android para "capturar" o ponteiro (ele manda só o quanto a
arma andou). O Android só aceita esse pedido com a janela em foco e o solta
quando o foco sai; o Godot pede uma vez só e nunca mais. Sem captura, o
cursor do sistema bate na borda da tela deitada do HDMI e somar o movimento
deixava parte da tela fora de alcance (os "pontos cegos"). Agora:
- a captura é pedida de novo a cada segundo enquanto não estiver valendo e
  sempre que o app volta ao foco;
- enquanto ela não volta, a mira vai para onde o ponteiro real está (cobre a
  tela inteira, sem buraco);
- sem filtro nenhum: a mira anda exatamente o que a arma andou, na hora;
- o cursor do sistema fica invisível (não pisca seta ao refazer a captura).

**Vídeo de volta, pelo decodificador de hardware** (`scripts/video_nativo.gd`
+ `shaders/video_oes.gdshader`). O player de vídeo do Godot 4.6 (Theora)
decodifica no processador, na mesma linha do jogo, converte a cor pixel a
pixel e reenvia a imagem inteira a cada quadro; não há configuração do Godot
que mude isso. A TV Box toca 1080p liso porque usa o decodificador de vídeo
dela. Agora o vídeo (H.264, `background_video/*.mp4`) vai para ele:
MediaPlayer do Android → SurfaceTexture → `ExternalTexture` do Godot, e o
quadro é desenhado direto da placa de vídeo, dentro do jogo (gira com a tela,
fica atrás dos textos). Custo de processador praticamente zero.
- Abertura: o vídeo inicial volta (720x1088). Embaixo dele fica um quadro
  parado do próprio vídeo, então a tela nunca fica preta esperando.
- Modo demonstração: as prévias também tocam pelo hardware, com som.
- Menu e ranking: o vídeo da abertura volta ao fundo; no menu, a mira sobre um
  cartão mostra a arte do cenário.
- Na primeira vez, os vídeos são copiados para a memória interna (cerca de
  32 MB, uma vez só); o MediaPlayer precisa de um arquivo de verdade.
- Plano B automático: se o hardware não entregar quadro em 3 s (ou der erro),
  a abertura e as prévias tocam o .ogv no player do Godot, como antes; menu e
  ranking ficam com o fundo animado (para não travar).
- Configuração > ABERTURA: "Vídeo pelo hardware" (LIGADO/DESLIGADO) e "Imagem
  do vídeo" (NORMAL/VIRADA, caso algum aparelho entregue o quadro de cabeça
  para baixo).
- O export inclui `*.mp4` (`export_presets.cfg`, filtro de inclusão do preset
  Android).

**Abertura limpa:** sem os riscos coloridos de glitch. A tela abre do preto
sobre o vídeo já em movimento e a chamada (APERTE START) surge suave.

**Troca de tela:** assim que a tela fica preta, a tela que sai para de
processar e de desenhar (animações, vídeo, efeitos), deixando o processador
para carregar a próxima; ela sai da memória quando a nova monta.

Não deu para testar na TV Box real nesta rodada (só no PC e no pacote
exportado). Se na TV Box o vídeo da abertura aparecer parado (só o quadro de
baixo) ou trocar pelo vídeo antigo, o hardware não aceitou: avise.

## Rodada 7: mira certa na tela em pé, Egito com vídeo e menu orquestrado

**Mira (o erro de verdade).** Com a tela girada da TV Box, a mira recebia o
movimento da arma ainda no sentido do HDMI deitado: arma para a direita
subia a mira, arma para cima ia para a lateral (por isso "não passa de um
ponto" e "fica nas laterais", até com mouse comum). Agora `MiraGlobal` leva o
movimento e o ponto para a tela em pé com a mesma conversão que o Godot usa
nas telas. Conferido no simulador da TV Box (`LAZER_GIRO=1`, janela
1920x1080): direita = direita, cima = cima, e os 4 cantos do ponteiro caem
nos 4 cantos da tela.

**Tiros sem travar.**
- Os efeitos curtos (tiro, acertos, recarga, bips...) eram MP3: cada som
  decodificava MP3 de novo, e numa rajada eram dezenas ao mesmo tempo no
  processador da TV Box. Agora são WAV (`songs/*.wav`, PCM, sem compressão):
  tocar não custa nada. A música continua MP3/OGG.
- Cada som criava um player novo na árvore e apagava no fim. Agora
  `Maquina.efeito()` tem um player fixo por efeito, com até 6 vozes juntas.
  Numa rajada de 145 tiros no Egito, os nós da tela ficaram em 214 (antes
  subiam a 360).

**Egito com os vídeos de volta.** Sol e lua (`back_sun.mp4`, `back_moon.mp4`)
tocam pelo decodificador de hardware. Na troca de modo, o novo vídeo entra por
cima do anterior quando o primeiro quadro chega. Com vídeo na tela, o fundo
animado de baixo nem é desenhado (placa de vídeo livre). Se o hardware falhar,
volta o fundo animado do modo.

**Menu: vídeos pré-carregados e troca orquestrada.**
- Os vídeos são copiados para a memória interna já no início do jogo, numa
  thread (`Maquina.VIDEOS_HARDWARE`): nenhum espera cópia na hora.
- Mira num cartão: a arte do cenário aparece na hora (já carregada); a prévia
  em vídeo daquele cenário só começa se a mira parar 0,25 s e entra suave
  quando o primeiro quadro chega. A prévia anterior sai em 0,2 s.
- O vídeo da abertura no fundo pausa enquanto não aparece; no máximo 2
  decodificadores trabalhando.

**Carregamento entre telas.** A pré-carga pedia de novo, em paralelo, peças
que já vinham com a tela (`preload` nos scripts): duas threads lendo o mesmo
arquivo às vezes falhavam e a tela caía no carregamento travado. Agora
`tools/gerar_precarga.py` só pede o que é carregado em tempo de execução.

**Limpeza:** 12 funções que ninguém chamava saíram (abertura, menu, Egito).

## Rodada 8: Egito recriado, Mar com navio, pedras e cardumes, Bar com líquido

**Egito recriado em camadas (sem vídeo).** `scripts/deserto_vivo.gd` monta o
fundo na placa de vídeo, e os vídeos `back_sun`/`back_moon` saíram do jogo:
- **Sol com o Olho de Rá** (olho direito: olha para a direita, traço comprido
  para a esquerda) e **lua com o Olho de Hórus** (olho esquerdo: olha para a
  esquerda, traço para a direita). Os dois completos, no traçado do hieróglifo
  D10 (U+13080): sobrancelha, pálpebras, pupila tocando as duas pálpebras,
  rabo, lágrima e espiral. O olho antigo (incompleto) foi apagado da foto.
- Sol e lua em 2x de resolução (nítidos até em 4K), com luz correndo pelo
  olho, pupila que cintila, borda que respira com a música e um "pisco"
  (clarão) de tempos em tempos e na troca sol/lua.
- **Luz em volta se movendo:** raios do sol girando em dois leques, coroa e
  chamas na borda; na lua, halo frio, anel girando e feixes de luar.
- **Pontas de ouro nas 3 pirâmides:** ao sol, ouro quente com a face acesa
  trocando conforme a luz anda e um reflexo que corre de uma para outra; ao
  luar, o mesmo ouro frio e prateado.
- **Diamante:** arco-íris correndo pelas arestas de dia, vermelho por dentro
  de noite, faixa de luz subindo e facetas acendendo uma de cada vez; estrelas
  de brilho piscando nas pontas do diamante, nas pirâmides e no disco.
- De noite: estrelas piscando no céu e estrela cadente de vez em quando.
- Câmera "respirando" (zoom lento; tirado na Rodada 9) ancorada no alto: o sol nunca entra
  embaixo do placar.
- Artes geradas por `tools/gerar_egito.py` (a partir das fotos originais).

**Mar.** Tudo em `scripts/mar_vida.gd`, artes e sons por `tools/gerar_mar.py`:
- **Pedras com escritas:** as runas acendem com uma faixa de luz que desce do
  topo à base (as já passadas ficam acesas um pouco). Tiro na pedra solta a
  lasca do próprio lugar (recortada da foto) + lasquinhas, poeira e bolhas, e
  deixa o buraco com rachaduras; runa quebrada apaga. Status "PEDRA!".
- **Navio cai aos 9 s de partida:** o fundo da partida (`atlantis_jogo.png`)
  não tem o navio; ele desce de cima balançando, azulado pela névoa, com a
  água ondulando e a luz passando por ele, soltando bolhas; bate no fundo
  levantando areia, farpas e bolhas, a tela treme e o cenário volta a ser
  exatamente a foto. Sons próprios da descida e da batida.
- **Cardumes:** os peixinhos parados da foto saíram; três cardumes nadam
  juntos pela água (MultiMesh, o nado é todo no shader).
- **Baleias cantam** ao aparecer na água (canto ao longe, a de trás mais
  grave).
- O menu continua com a foto original (`atlantis.png`).

**Bar.** Garrafa quebrando (`scripts/estilhacos.gd`):
- Mais cacos da própria garrafa (rachadura com mais raios e anéis).
- Lasquinhas de vidro na cor da garrafa (verde, âmbar, transparente) que
  cintilam girando, quicam e deitam na prateleira ou caem na de baixo.
- O líquido faz poça na prateleira, escorre pela beirada e pinga na
  prateleira de baixo (ou no chão), onde respinga e deixa mancha. Whisky e rum
  em âmbar com reflexo; vodka e gin como madeira molhada com brilho.

**Custo.** Rajada de 145 tiros (PC, sem limite de quadros): 95% dos quadros
até 9,0 ms no Bar, 8,4 ms no Mar e 7,4 ms no Egito; nós da tela estáveis.
No Egito as camadas cobrem só partes da tela (disco, raios, pontas, diamante)
em vez de vídeo.

## Rodada 9: abertura Lazer & Sport Games, ícone oficial, olhos vivos no Egito

**Abertura Lazer & Sport Games** (`scenes/abertura_ls.tscn`, agora a primeira
tela do jogo). Estande de tiro no escuro, uns 6 s: três placas-alvo sobem na
parede, a mira entra e o laser derruba uma a uma (a placa gira e cai,
faíscas, furo em brasa esfriando); a mira trava no centro, carrega e o tiro
final acerta o alvo do logo: clarão, onda de choque, tela tremendo, o logo da
Lazer & Sport entra com mola, "GAMES" bate embaixo e "apresenta" aparece.
Depois segue para o menu de sempre. Tiro, START ou clique pulam (depois de
0,6 s). Tudo desenhado na hora; a única imagem é o logo
(`sprites/logo_lazer_sport.png`).

**Nome e ícone oficiais: Lazer Shot, sem nada do Godot.** Nome do projeto,
do app no Android e do .exe: "Lazer Shot" (empresa "Lazer & Sport"). Ícone
novo (mira vermelha neon com o feixe e LAZER SHOT) em todos os formatos:
comum, adaptativo (frente na área segura + fundo), monocromático (temas do
Android 13+; antes caía no robô do Godot) e o .ico do Windows. O `icon.svg`
do Godot saiu e a tela de splash do Godot continua desligada. Tudo gerado por
`tools/gerar_icone.py`.

**Egito.**
- **Sem zoom:** a câmera não "respira" mais; o fundo fica parado, ancorado no
  alto.
- **Luz em volta se movendo de verdade:** os dois leques de raios do sol giram
  em sentidos contrários, o comprimento dos raios respira, ondas de luz correm
  para fora e um anel se abre de tempos em tempos; na lua, feixes girando e
  anéis de luar.
- **Olhos vivos, desenhados de novo** (nem o Rá nem o Hórus de antes): o
  **sol tem um olhar masculino** (sobrancelha grossa e reta, pálpebra pesada,
  olho estreito, íris dourada, rabo em cunha e espiral fechada) e a **lua um
  olhar feminino** (sobrancelha fina em arco, delineado de gatinho, cílios,
  íris branca, lágrima fina com uma gota e espiral elegante). Os dois são
  maiores, com relevo (sombra e luz gravadas no disco, parecendo uma coisa só
  com o sol/a lua) e vivos: **piscam** (às vezes duas vezes seguidas) e a
  **pupila passeia** pelo olho com movimentos rápidos de olhar. O olho é
  desenhado no shader (`shaders/egito_disco.gdshader`) a partir de um mapa
  (`sprites/egito_olho_*.png`).
- **Mais difícil:** sol e lua mais rápidos (mínimo 215, máximo 330), mudam de
  direção de repente (guinadas a cada ~0,5 a 1,3 s, mais frequentes com o
  nível), duram menos na tela, área de acerto menor e a dificuldade sobe a
  partir de 800 pontos.

**Mar: navio caindo de forma natural.**
- Desce como um navio de verdade na água: acelera e chega na velocidade de
  afundar (4,2 s até o fundo), balança cada vez menos e assenta com um
  pequeno quique.
- Rastro de bolhas saindo do casco, mastros e vergas enquanto desce (bolhas
  que sobem rebolando e crescem).
- Na batida: nuvem de lodo empurrada rente ao chão, jatos de areia, tábuas
  recortadas do próprio navio voando e girando, farpas de madeira molhada
  (tingidas pela água e sumindo na névoa) e bolhas escapando do casco.

**Custo.** Rajada no Mar medida lado a lado com a Rodada 8, nas mesmas
condições: igual (os efeitos do navio só existem na queda). A abertura usa
desenho simples e partículas curtas.

## Rodada 10: Olho de Rá e de Hórus nítidos, águias, efeitos de acerto e navio limpo

**Egito: sol e lua refeitos, sem shader no olho.** Arte nova pintada em 3x
(`tools/gerar_astros.py`), nítida em 1080p e 4K, com o disco 11% maior:
- **Sol = Olho de Rá** (pupila cheia) e **lua = Olho de Hórus** (pupila
  vazada), no traço clássico do hieróglifo e espelhados entre si:
  sobrancelha em barra, pálpebra de cima grossa que segue reta para o lado,
  lágrima reta e espiral embaixo. O traço é esmalte escuro com brilho na
  borda e sombra, gravado no astro.
- O sol é plasma dourado com grânulos e coroa; a lua, prata com mares e
  crateras em relevo.
- Continua vivo, mas sem efeito de shader: são camadas comuns (branco do olho,
  pupila que passeia, pálpebra que desce ao piscar e o disco por cima). O
  disco só clareia no "pisco" e na batida da música.
- O sol e a lua novos também foram pintados nos fundos (o menu já mostra).

**Egito: águias ao fundo** (`tools/gerar_aguias.py`, `scripts/deserto_vivo.gd`):
- Três águias vistas de baixo, com as penas da ponta das asas abertas. Sobem
  em térmicas (círculos que o vento leva), planam de uma para outra, batem as
  asas de vez em quando e inclinam nas curvas. Tamanho, rapidez, raio, vento e
  turbulência são sorteados a cada voo: nenhum se repete.
- Chegam de longe crescendo e vão embora subindo. Contra o sol ou a lua viram
  silhueta; de noite são silhuetas e às vezes cruzam a lua.
- Grito da águia com eco do vale (`songs/aguia.wav`); de noite vem de mais
  longe (`songs/aguia_noite.wav`). Um grito de cada vez, a cada 9 a 22 s.

**Egito: acertos e dificuldade.**
- Acertar sol ou lua solta efeito (`scripts/egito_acerto.gd`), além da troca
  do sprite. No sol: clarão quente, leque de raios de luz, anéis dourados,
  estilhaços do próprio medalhão e brasas. Na lua: clarão frio, anéis
  prateados, arcos de luar e pó de estrelas. Acertar o astro errado deixa o
  anel vermelho.
- Mais difícil: o artefato encolhe rápido no começo e passa a maior parte do
  tempo pequeno; o tamanho mínimo caiu de 0,33 para 0,27 e a área de acerto
  mínima de 34 para 28 px.

**Mar.**
- **Navio sem a borda:** o recorte agora é só o navio (o fundo entre cordas e
  velas fica transparente, sem a placa de névoa em volta), com a cor da foto
  (sem tinta azul e sem shader).
- **O mar cedendo:** na descida, redemoinhos claros sobem pelo casco e bolhas
  saem das vergas e do fundo; tábuas do fundo do casco se soltam e ficam para
  trás. Na batida: colunas de areia e água jogadas para cima, jatos nas pontas
  do casco, grãos de areia, 14 tábuas do fundo voando, farpas e bolhas, tudo
  atrás das pedras da frente.
- **Alvos com efeito próprio** (`scripts/mar_acerto.gd`), por cima da animação
  de acerto. Água-viva: o sino se desfaz em pedaços de geleia, com brilhos
  piscando, anéis na água, tentáculos afundando e bolhas. Vaso: cacos da
  própria imagem voando e afundando, pó de barro, grãos e brilhos verdes. Baú:
  tábuas voando, estrelas de ouro, anel dourado e as moedas.

**Bar: tiro que erra** (`scripts/bar_tiro.gd`, `tools/gerar_bar.py`):
- Na estante: lascas recortadas da própria madeira pulam para a frente,
  giram e caem, com cavacos e pó.
- No cartaz JOY-BOY do barril: pedaços do próprio cartaz caem planando e
  virando como papel, com fiapos brancos. Na madeira do barril, lascas.
- O furo que fica tem profundidade: madeira crua lascada no sentido do veio,
  buraco escuro com fundo e borda clara embaixo; no cartaz, papel rasgado com
  a madeira do barril aparecendo e uma aba dobrada.

**Custo.** Os efeitos de acerto/erro ficam limitados (5 no Bar, 4 no Mar e no
Egito ao mesmo tempo) para a rajada não pesar. O shader do disco do Egito e o
do navio saíram.

### Rodada 10b: o Olho de Rá e o de Hórus como joia

O traço chapado do hieróglifo virou uma joia egípcia (`tools/gerar_astros.py`),
nítida em 1080p e 4K e ainda sem shader:
- **Esmalte azul-lápis** com pontinhos de pirita, em peças de **ouro (sol)**
  ou **prata (lua)** em relevo, com brilho, contorno e sombra no astro.
  Sobrancelha em faixas com fio de metal no meio e riscos; fio de metal
  acima da pálpebra.
- **Olho maior e realista**: íris grande com fibras, aro escuro, pupila e
  reflexos. **Sol: amarelo-castanho. Lua: branco-azulado.**
- **Pálpebra-joia**: abaulada (luz no meio, sombra na dobra), com um fio
  gravado e a faixa de esmalte com borda de metal na beirada. Ao piscar,
  desce com uma sombra suave sobre o olho.
- **Aro gravado** com uma volta de símbolos egípcios (ankh, sol, água, pena,
  djed).
- Rá e Hórus continuam espelhados (no Rá o traço vai para a esquerda). Os
  fundos do sol e da lua foram pintados de novo com o olho novo.

## Rodada 11: Arena nas 5 cores, trajetória do tiro, cristal que quebra, placar novo e sons

**Arena: duas mecânicas e as cores da ordem** (`scripts/arena.gd`):
- As lanternas agora têm **5 cores, sempre na mesma ordem**: 1 azul,
  2 verde, 3 amarelo, 4 vermelho, 5 roxo (`sprites/arena_lanternas.png`,
  `tools/gerar_lanternas.py`). A cor diz qual é o 1º, 2º, 3º... tiro.
- **Rodada de MEMÓRIA**: as lanternas acendem e apagam na ordem das cores, e
  o jogador repete. Começa com 1 e sobe até 5.
- **Rodada FIXA**: as lanternas nascem **acesas, uma após a outra a cada 1 a
  1,5 s**, já na cor da ordem; é acertar na ordem. Acerto rápido (antes de
  1,1 s) dá +10, a fixa completa dá **+50**.
- As rodadas **ciclam**: memória → fixa → memória... Errar a ordem continua
  tirando 100 pontos; na memória volta ao nível 1 e na fixa a rodada
  recomeça com outra ordem.
- **Troca de arte** na fixa: o fundo cruza para `sprites/arena_fixa.png`
  (letreiro nas 5 cores, furos em neon frio, giroflex roxo), uma linha de
  varredura colorida desce a parede e o letreiro "SEQUÊNCIA FIXA" cruza a
  tela. Na memória volta à arte normal.
- As instruções da Arena são o COMO JOGAR da Rodada 13 (`scripts/como_jogar.gd`):
  as cores, os pontos e as duas rodadas.

**Arena viva** (`scripts/arena_vivo.gd`), tudo com o Pincel:
- O fundo usa o mesmo shader dos fundos do menu: luzes piscando com a
  música, reflexo no chão, brilho na batida.
- O giroflex gira na troca de rodada, fica vermelho no erro e pisca nas
  cores na vitória e na cor de cada lanterna acertada.
- As duas arandelas jogam luz na parede, com poeira no ar. Os canos soltam
  vapor e a caixa elétrica solta faíscas de vez em quando, com som.
- Uma faixa com as 5 luzes da ordem fica embaixo dos furos, e a próxima
  pulsa.

**Trajetória do tiro em todas as telas** (`scripts/trajetoria.gd`). Sai de
baixo da tela (a arma) e vai até onde a mira estava:
- **Arena:** laser vermelho como o da abertura, com pulso correndo e
  clarão no ponto.
- **Egito:** raio de sol dourado (dia) ou raio de luar prateado (noite),
  com brilhos soltos e som próprio.
- **Mar:** a bala corta a água, com um risco claro, um rastro de bolhas que
  sobem e anéis na água.
- **Bar:** traçante quente e um fio de fumaça que fica no ar.

**Placar único e compacto** (`scripts/placar.gd`). Uma faixa fina no topo,
usando a largura toda, igual nas 4 telas: TEMPO | PONTOS | MUNIÇÃO (barra)
| ACERTOS/TIROS | campo da fase. O campo da fase é FIXA/MEMÓRIA na Arena,
SOL/LUA no Egito, BOMBAS no Mar e COMBO no Bar. O fundo aparece inteiro. O
placar antigo fica escondido; as variáveis da fase continuam iguais.

**Egito** (`scripts/deserto_vivo.gd`):
- **Cristal com dano:** cada tiro trinca o cristal (tremor, cacos, brilho
  falhando). No 9º tiro ele **quebra**: estilhaços, clarão, onda, som de
  vidro, e a **energia apaga**. Os feixes do fundo ficam cinza e param o
  brilho e as faíscas. O cristal fica escuro e rachado
  (`sprites/egito_cristal_morto_*.png`, `tools/gerar_cristal_morto.py`) por
  30 s, depois se refaz com som e a energia volta.
- **Pontas de ouro tocam:** um tiro nas placas de ouro dá clarão e anel no
  metal (`shaders/egito_pontas.gdshader`), faíscas e lasquinhas de ouro,
  com um "ping" metálico. Pedra lasca com pó e areia levanta com os grãos.
- **Olhos em 4x:** o Olho de Rá e o de Hórus foram gerados em 4x (antes 3x)
  e preenchem o astro até a borda, sem vazar
  (`tools/gerar_astros.py`). O halo virou uma imagem separada, leve.

**Mar: templo de Atlântida no lugar dos tabletes apagados**
(`tools/gerar_mar.py`, `scripts/mar_vida.gd`). Os poneglifos quase apagados
do fundo saíram:
- O lugar foi preenchido com a textura da própria rocha, sem borrão.
- No paredão, um **templo** cercado de rocha: escadaria, 6 colunas (uma
  quebrada, uma só no toco), frontão com a ponta partida e tambores caídos.
- Uma **estátua de Poseidon** com tridente fica sobre um pedestal, e há
  pedras, corais e algas nas quinas.
- A porta tem uma luz de cristal que respira com a música, com pontinhos
  subindo.
- Depois que o navio pousa, o templo continua atrás dele
  (`mar_navio_pouso.png`).

**Sons** (`tools/gerar_sons_efeitos.py`, síntese física em 44,1 kHz):
- **Cristal:** trinca, quebra (vidro estilhaçando com cacos quicando) e volta.
- **Egito:** ouro tocando, areia, raio de sol e raio de luar.
- **Arena:** laser batendo na parede, vapor, faísca, troca de rodada e
  lanterna subindo/descendo.
- **Mar:** bolhas do tiro.
- **Bar:** madeira e papel ao errar.

Tudo em WAV sem compressão, tocado pelo `Maquina.efeito`.

**Custo.** Rajada de tiros (render por software, PC de teste, média por
quadro): Arena 41 ms, Egito 60 ms, Mar 58 ms, Bar 54 ms. É o mesmo nível da
Rodada 10, e os nós da tela ficam estáveis. Trajetória e efeitos do fundo
são desenhos do Pincel (uma textura) e só redesenham enquanto há algo no ar.

### Rodada 11b: caixa-preta para a TV Box

- **Caixa-preta** (`scripts/caixa_preta.gd`, criada pela `Tela` antes de
  qualquer cena): veja "Se o jogo não abrir ou fechar sozinho na TV Box" no
  começo deste arquivo. A transição marca cada troca de tela
  (`Tela.marca("...")`).
- `GERAR_APK_PRO_ULTRA.bat -Registro` puxa o logcat da TV Box pelo adb.
- Shaders do Egito: `pow(x, 2.0)` com `x` negativo virou `x * x`. O GLSL ES
  não define `pow` de base negativa, e nas GPUs Mali isso dá pontos pretos ou
  piscando nos anéis de luz.

### Rodada 11c: abrir na TV Box como na Rodada 6

A Rodada 6 foi a última testada na TV Box. Desde então entrou uma coisa que
só roda no Android, logo ao abrir: a cópia de todos os vídeos de dentro do
APK para a memória interna, numa thread, enquanto a primeira tela carregava.
No PC isso nunca roda. Ela saiu: como na Rodada 6, cada vídeo só é copiado
quando vai tocar.

- Modo de segurança automático (veja "Se o jogo não abrir ou fechar sozinho
  na TV Box"). Nada de diagnóstico aparece na tela do jogo.
- Os vídeos pelo hardware marcam cada passo na caixa-preta (preparando,
  tocando, falhou e por quê).
- APK 1.11.2 (código 13).

## Rodada 12: apresentação e vídeos de volta, sem travadas de primeira vez

**O que tinha acontecido.** A 1.11.2 abriu, mas sem a apresentação e sem o
vídeo do menu: o "modo de segurança" daquela versão leu os fechamentos da
1.11.1 (que fechava sozinha) e ligou sem a nova ter fechado. Ele saiu. No
lugar, o contorno pontual (veja "Se o jogo não abrir...") só mexe no trecho
que de fato derrubou o app, nesta mesma versão.

**Travadas de primeira vez** (`scripts/aquecedor.gd`). Na TV Box, a primeira
vez que um shader é usado a placa compila o programa (centenas de
milissegundos num shader grande como o do Egito), a primeira vez que uma
imagem aparece ela sobe para a placa e a primeira vez que uma letra aparece
num tamanho a fonte é desenhada. Isso acontecia no meio do jogo:
- na partida do app, debaixo do preto inicial da apresentação, todos os
  shaders do jogo são montados nos três jeitos em que são desenhados
  (retângulo, polígono, partículas), mais a mistura somada;
- em cada troca de tela, debaixo do cartão de carregamento, as imagens, os
  materiais, as partículas e os textos da tela nova (inclusive o que ainda
  está escondido: instruções, contagem, fim de jogo, com os números) ficam
  prontos. A tela nova fica parada nesses quadros para o relógio dela não dar
  um salto.
Com o cache de shaders do Godot, da segunda vez em diante a placa só lê o
programa já pronto.

**Ritmo estável** (`scripts/MiraGlobal.gd`, só na TV Box). Uma tela que não
segura 60 quadros por segundo alterna quadros de 16 e 33 ms, e isso aparece
como tranco. Se em 2 s mais de um quarto dos quadros passou de 20 ms, aquela
tela fica em 30 por segundo cravados; a próxima volta a tentar 60.

**Medições** (PC de teste, renderizador por software, 1920×1080 girado). A
Rodada 6, a última que rodou na TV Box antes, já custava o mesmo para a placa
de vídeo que a atual (Egito 26 × 29 ms, Arena 24 × 24 ms, Bar 34 × 30 ms). O
peso maior de cada fase é o fundo em tela cheia (~10 ms só a imagem); o
shader do fundo soma ~3–5 ms e os raios do sol do Egito ~4 ms. Os scripts do
jogo gastam menos de 1 ms por quadro; os picos vinham do motor preparando
coisas na primeira vez, que agora acontece debaixo do carregamento.

**Também nesta rodada**
- Shaders do Egito sem `pow()` de base negativa (NaN nas placas Mali).
- Sem a cópia de vídeos ao abrir o jogo (só rodava no Android).
- Caixa-preta: cópia na pasta do app visível no gerenciador de arquivos e
  `queda.txt`; `-Registro` também puxa essa pasta.
- APK 1.12.0 (código 14).

## Rodada 13: modais novos, letras de longe e trocas de tela sem tranco

**A TV Box.** A Proeletronic SmartPro (PROSB-3000) é Allwinner H313: quatro
Cortex-A53 e uma Mali-G31 MP2, a placa de vídeo OpenGL ES 3 mais fraca que
existe, com memória de banda estreita. Os 181 MB do jogo não pesam: o que
pesa é o que a placa desenha e prepara a cada quadro. Tudo abaixo foi feito
para essa placa.

**Som saindo antes da tela, parando e voltando** (`scripts/TransiaoGlobal.gd`).
A tela nova começava a música no `_ready`, ainda debaixo do preto; aí a
troca de tela a parava (para os quadros escondidos) e soltava de novo. Agora
a tela nova entra na árvore já parada e muda: o que ela manda tocar fica
pausado no começo e sai junto com a imagem, do zero.

**Carregamentos.**
- Nos quadros pesados da troca (montar a tela, preparar a placa) o cartão de
  carregamento fica parado em "PRONTO" (sem brilho correndo nem giro) e o
  anel das outras telas some: a demora vira imagem parada, não tranco.
- O fundo vivo do Mar (`mar_vida.gd`) e o sol do Bar (`bar_sol.gd`) eram
  compilados na hora em que a tela montava (~250 ms parados na TV Box); agora
  vêm junto com a cena, na thread do carregamento.
- Telas que não seguram 60 quadros ficam em 30 cravados e a TV Box lembra
  delas (`user://ritmo.cfg`, por versão): da próxima vez já abrem em 30, sem
  os primeiros segundos alternando.

**Sem fácil/difícil.** Só existe o jogo com a mira na tela (saiu também da
configuração). No lugar da escolha de dificuldade, ao escolher o cenário
aparece a **missão** (`scripts/missao.gd`): capa do cenário, objetivo em
letras grandes, o **recorde daquele cenário** (nome e pontos), um alvo
grande **JOGAR** com o anel do tempo (começa sozinho em 9 s) e **TROCAR
CENÁRIO** para voltar à grade.

**COMO JOGAR** (`scripts/como_jogar.gd`) no lugar das imagens antigas
(`info_scenes/` saiu): cada alvo com a figura do próprio jogo e os pontos
que o código dá de verdade, em letras grandes que ocupam a tela:
- Egito: sol de dia, lua de noite +20 a +100; astro errado -20 a -100; dia
  e noite trocam a cada 30 s; 3 acertos seguidos dão combo.
- Mar: água-viva +20, pote +80, baú +100; 3 bombas encerram a partida.
- Bar: gin +20, rum +50, vodka +80, whisky +100, garrafa verde -500.
- Arena: as 5 cores na ordem (+20 a +100), ordem errada -100, fixa completa
  +50, acerto rápido +10.
Embaixo: tempo da partida (da configuração), 30 tiros e recarga no botão.

**Modais decorados por cenário** (`scripts/moldura_tema.gd`, desenhados na
hora, sem imagens novas): Egito com raios de sol girando, asas douradas,
faixas de hieróglifos e brilhos; Mar com feixes de luz, bolhas, peixes,
ondas, algas e corais; Bar com tábuas, pregos, corda, estrelas de xerife,
furos de bala e a luz do lampião; Arena com grade, cantos de mira em neon,
LEDs, laser varrendo e faixa de perigo. Vale para a missão e o COMO JOGAR.

**Maior para ver de longe.** Placar das fases ~30% mais alto (letras junto),
mira de todas as telas 1,7× o desenho original (antes 1,3×) e ranking
refeito: linhas de 116 px, nome e pontos em 52–56 px, pódio em ouro, prata
e bronze, sem a coluna de modo; rola pelos botões ▲▼.

APK 1.13.0 (código 15).

## Rodada 14: fim de partida novo, memória que não cresce e nada que feche o jogo

**Fim de partida** (`scripts/fim_partida.gd`, igual nas quatro fases).
- Botão grande **VOLTAR AOS CENÁRIOS** embaixo do resultado: a mira fica por
  cima do modal e um tiro no botão leva para a escolha de cenário.
- A contagem do resultado, quando acaba, volta sempre para a **abertura**
  (apresentação Lazer & Sport e o vídeo), não mais para o menu.
- **JOGAR DE NOVO** (START) recarrega a fase do zero. Antes a fase se
  "zerava" por dentro e START repetido deixava partidas e laços duplicados
  rodando juntos (travava e podia fechar). Agora START várias vezes = uma
  recarga só, e o START só vale com o resultado na tela há 0,8 s (o START
  que confirma o nome do recorde não recomeça a partida sem querer).
- Embaixo do botão: "RANKING: SÓ ACIMA DE 4.000 PONTOS".

**Ranking só acima de 4.000 pontos** (`scripts/RankingManager.gd`):
partida com 4.000 ou menos não pede nome nem entra; recordes antigos de
4.000 ou menos deixam de aparecer.

**Mar mais devagar** (`scripts/mar.gd`): águas-vivas, potes, baús e bombas
caem ~50% mais devagar, o aumento de velocidade por nível caiu de 12% para
7% e o balanço das águas-vivas ficou mais lento.

**Memória que não cresce — a causa mais provável de o jogo fechar.** No
Godot 4.6 um script carregado nunca sai da memória, e tudo o que ele
pré-carrega (`preload`) fica junto. Cada fase visitada deixava as imagens
dela presas para sempre; depois das quatro fases eram ~200 MB de imagens e
~70 MB de letras que nenhuma tela usava. Na TV Box, quando a memória acaba,
o Android fecha o app sem aviso.
- As imagens grandes das fases (Egito ~50 MB, garrafas do Bar ~35 MB,
  lanternas e fundo da Arena ~40 MB, navio e pedras do Mar) passaram a ser
  carregadas pela própria fase (`load`) e somem quando ela sai; a troca de
  tela continua pedindo tudo numa thread (`scripts/precarga.gd`, gerado de
  novo por `tools/gerar_precarga.py`, que agora segue também os scripts
  pelo caminho).
- `static var` também prende o script para sempre: saiu dos efeitos de
  acerto (Egito, Mar, Bar), do fundo do Egito e das lanternas da Arena.
- As letras de cada tamanho viram imagens guardadas na fonte e isso só
  crescia. Na tela preta de cada troca elas são jogadas fora
  (`clear_size_cache`) e a tela nova desenha as dela debaixo do cartão.
- Medido no PC, 5 min passando pelas 4 fases sem parar com tiros, START e
  RECARGA em rajada: antes o menu chegava a 200 MB + 266 MB de imagens
  (pico 245 + 271); agora fica em 57–84 MB + 48–65 MB em todas as voltas
  (pico 108–165 + 103–139), sem crescer.

**Toques rápidos.**
- START no menu e no ranking: cobrava/trocava de tela mais de uma vez com
  START repetido; agora uma vez só.
- Missão do cenário: escolher rápido logo ao abrir o menu apagava o cartão
  aberto (o pré-aquecimento escondido dele limpava tudo depois de 1,5 s) e
  dava erro a cada quadro; corrigido.
- Bar: uma das trocas de garrafa chamava o ciclo dela sem o número do ciclo
  (a garrafa ficava parada) e a garrafa destruída no meio dava erro.
- Vídeo pelo hardware: preparar e soltar o player não espera mais a thread
  no meio do quadro, e a thread não escreve mais num nó já apagado.
- RECARGA repetida já era ignorada durante a recarga; o botão de recarga da
  arma (VOLTAR do Android) não fecha o jogo (`quit_on_go_back` desligado).
  Nenhum botão do jogo fecha o app.

APK 1.14.0 (código 16).

## Rodada 15: cada cenário com o seu tiro e o sol e a lua com humor

**Som do tiro de cada cenário** (`tools/gerar_sons_efeitos.py`, sintetizados):
- Egito de dia: `tiro_sol.wav` — baque, o raio de sol saindo num acorde
  dourado que sobe, chama e faíscas.
- Egito de noite: `tiro_lua.wav` — baque leve, sino de cristal que desce,
  ar frio e brilhos gelados.
- Mar: `tiro_mar.wav` — arpão debaixo d'água: "tuum" abafado, cavitação e
  rastro de bolhas subindo.
- Abertura e menu de cenários: `tiro_menu.wav` — disparo de laser curto.
- A pistola (`tiro-de-pistola.wav`) ficou só no Bar; a Arena segue com o
  laser dela. O rastro do tiro não toca mais um som por cima (os antigos
  `raio_sol`, `raio_lua` e `bolhas_tiro` viraram parte dos estampidos).
  Os estampidos são curtos e cheios: em rajada não viram um amontoado.
  `python3 tools/gerar_sons_efeitos.py tiro_sol tiro_mar` gera só esses.

**Olho de Rá e Olho de Hórus** (`tools/gerar_astros.py`):
- Rá (sol) é o olho direito: traço e espiral para a direita. Hórus (lua) é
  o esquerdo: o espelho.
- O desenho é de metal maciço: ouro no sol, prata na lua (borda polida em
  relevo e o miolo fosco, granulado), sem o esmalte azul. O astro atrás
  mudou de cor para o desenho aparecer: sol laranja-avermelhado, lua
  cinza-azulada. Os fundos do menu (`deserto_sol.png`, `deserto_lua.png`)
  foram refeitos com o astro novo (`gerar_egito.py --so-fundo`), sem a
  borda da lua antiga que sobrava da foto.

**Olhar tranquilo que reage ao jogo** (`scripts/deserto_vivo.gd`). O olho
ganhou a pálpebra de baixo (a beirada curva para cima: subindo, o olho fica
em meia-lua, sorrindo). Em repouso as pálpebras cortam parte do olho e a
íris desliza devagar, sem o olhar arregalado. O deserto conta o que
aconteceu e o astro muda de humor:
- calmo: o normal (pálpebras meio baixas, piscada calma, às vezes olha
  para a mira do jogador);
- feliz com combo de 3, radiante com combo de 6 (olho sorrindo);
- atento com vários erros seguidos e nos últimos 10 s (olho mais estreito,
  seguindo a mira);
- bravo ao acertar o astro errado; surpreso quando o cristal quebra;
- sonolento no fim da partida;
- apertinho feliz a cada acerto, espiada onde o tiro errou e olhada para a
  arma na recarga.

APK 1.15.0 (código 17).

## Rodada 16: pontas de ouro na própria pedra e o Mar com profundidade (2,5D)

**Pontas das pirâmides** (`shaders/deserto_fundo.gdshader`,
`scripts/deserto_vivo.gd`, `tools/gerar_egito.py`). As pontas de ouro não são
mais uma peça desenhada por cima: o ouro é pintado dentro do próprio shader
do fundo, pixel a pixel na grade da foto. Mesma resolução, mesma luz, sombra
e névoa da pirâmide, e o brilho do cristal e da batida passa por elas igual
passa pela pedra. A máscara segue a ponta que já estava pintada na foto (a
borda de baixo quebrada no lado aceso). O ouro reage ao jogo:
- combo de 3 deixa o ouro mais quente; combo de 6, aceso, com as quinas
  brilhando;
- cada acerto passa um reflexo correndo de uma pirâmide para a outra;
- erros seguidos apagam o ouro; acertar o astro errado dá uma apagada rápida;
- tiro no ouro continua dando clarão, anel e faíscas.
`shaders/egito_pontas.gdshader` saiu (não é mais usado).

**Mar em 2,5D** (`scripts/mar.gd`, `scripts/mar_profundo.gd`,
`scripts/mar_vida.gd`):
- **Alvos que vêm do fundo:** parte das águas-vivas (35%), vasos (35%),
  baús (40%) e bombas (25%) nasce pequenininha na porta do templo, lá no
  fundo, e vem vindo até perto, crescendo e saindo da névoa azul da água
  (perspectiva de verdade: devagar longe, rápido perto). Passa um pouco do
  plano dos outros alvos e some, como quem passou por nós. As bolhas deles
  têm o tamanho deles.
- **Acertar de longe vale o dobro** ("DE LONGE!"). Longe o alvo é pequeno,
  então a mira ganha um mínimo justo em volta dele (a bomba não ganha).
  Quando um alvo está na frente de outro, o tiro pega o da frente.
- **Paralaxe com a mira:** o fundo anda um pouco para o lado da mira e
  balança de leve como debaixo d'água; a frente anda mais e para o outro
  lado. Os alvos ficam parados na tela (a mira continua justa).
- **Camada da frente** (`tools/gerar_mar_frente.py`): touceiras de alga
  escura, fora de foco, nos cantos de baixo, balançando; bolhas grandes
  subindo devagar; e de vez em quando a sombra de um peixe grande passando
  bem perto, meio transparente.
- **Navio atrás do templo:** o navio agora afunda longe, atrás do templo de
  Poseidon e do poneglifo pequeno (menor e tingido pela água, como o
  templo). Esse pedaço do fundo é desenhado de novo por cima dele, recortado
  por uma máscara (`sprites/mar_frente_navio_mascara.png`, gerada por
  `tools/gerar_mar.py` com a forma exata do templo, da estátua e das pedras);
  só os mastros aparecem por cima. A areia, a água e as tábuas da batida
  também ficam atrás, e o tremor da tela é menor (a batida é longe).
  `mar_navio_pouso.png` saiu.
- Custo medido: cerca de 8 chamadas de desenho a mais por quadro na partida
  (51 → 59), sem shader novo pesado e sem aumento de processamento.

APK 1.16.0 (código 18).

## Rodada 17: cenários em 3D de verdade (a imagem decide a profundidade)

A ideia: cada fundo continua sendo uma imagem 2D, mas agora cada pixel sabe a
sua distância. A distância sai da própria imagem (`tools/gerar_profundidade.py`:
o chão em perspectiva até o ponto de fuga, e cada coisa em pé — pedra,
coluna, estátua, obelisco, cristal — com a distância do pé dela, recortada
pelo contorno medido na imagem). Com isso:
- **Câmera 3D:** a câmera anda um pouco com a mira e cada pixel do fundo anda
  conforme a distância dele (paralaxe pixel a pixel no shader do fundo). Longe
  anda com a mira, perto anda contra, o plano dos alvos fica parado.
- **Alvos dentro da cena:** cada alvo tem a sua distância. Tamanho, rapidez
  na tela, névoa e ordem de desenho vêm dela; o mais perto passa na frente,
  o tiro pega o mais perto, e quem está atrás de uma pedra, coluna, estátua,
  obelisco ou do cristal fica escondido de verdade (o tiro pega a coisa da
  frente).

**Mar** (`scripts/mar.gd`, `mar_vida.gd`, `mar_profundo.gd`,
`shaders/fundo_profundo.gdshader`, `sprites/mar_profundidade.png`):
- Alvos entram de jeitos diferentes: do fundo (porta do templo), do alto em
  L, de lado, caindo; tamanhos variados. Para sumir, chegam perto do vidro.
- O que cai bate no chão e espatifa conforme o objeto (vaso em cacos, baú
  com moedas quicando, bomba explode no chão com coluna de areia).
- Explosão nova (`scripts/mar_explosao.gd`): clarão, bola de fogo, anéis de
  choque, bolha de gás que incha e colapsa, fumaça escura espalhando a água,
  jatos, bolhas e estilhaços.
- Água-viva (nuvem de luz e esporos) e vaso (cavalo-marinho de jade subindo)
  com efeitos novos; furos de bala na areia com a poeira que fica pairando
  (`scripts/furos.gd`); pontos saltando do alvo (`scripts/pontos_voando.gd`).
- Mar em movimento: luz cáustica no chão (`shaders/mar_caustica.gdshader`),
  fachos de luz e neve marinha.

**Egito** (`scripts/deserto.gd`, `deserto_vivo.gd`,
`shaders/egito_alvo.gdshader`, `sprites/egito_profundidade.png`):
- Brasões em 3D: nascem lá no horizonte e vêm vindo, caem do alto em L,
  entram de lado ou saem de trás do cristal/obelisco; vão se afastando com a
  idade (era o encolhimento); somem chegando no vidro ou sumindo lá longe.
  Mais brasões ao mesmo tempo (até 11). Acerto lá longe vale "DE LONGE!"
  (+50%).
- Furos de bala na areia e na pedra, com poeira; pontos saltando do brasão.
- Brasões novos em alta definição (`tools/gerar_brasoes.py`): lua de prata
  com as fases no aro e o Olho de Hórus; sol de ouro com o Olho de Rá; os
  dois em prata/ouro com esmalte de lápis-lazúli.
- Sol e lua do céu (`tools/gerar_astros.py`): o olho comprido, de borda a
  borda do astro, desenhado como o Wadjet clássico (a cauda são as duas
  linhas do olho seguindo juntas e fechando na ponta; a lágrima e a espiral
  saem da linha de baixo), íris maior, tudo fundido ao astro; o sol ficou
  dourado (antes avermelhado).

**Leve para a TV Box:** efeitos desenhados em lote (`scripts/triangulos.gd`:
moedas, grãos, fios e estilhaços num desenho só). Medido na partida do Mar:
calmo ~60 chamadas de desenho (igual à 1.16); com efeitos ~82 (pico ~105).
Egito: 59 → 71. Memória estável no teste longo (todas as telas, 7 min).

APK 1.17.0 (código 19).

## Rodada 18: cenários em planos reais, mecânicas novas e demos com robô

Na 1.17 a câmera andava e cada pixel da foto andava pela distância dele, mas
as coisas em pé continuavam pintadas na foto: quando a câmera andava, a borda
delas "entortava" o fundo e dava para ver que era uma imagem só. Agora cada
coisa em pé é um plano de verdade, recortado, e o fundo atrás dela foi
reconstruído (`tools/gerar_camadas.py`): quando a câmera anda, os planos se
deslocam uns dos outros e aparece chão, céu e pedra de verdade atrás deles.

**Egito** (`scripts/deserto_vivo.gd`, `egito_feixes.gd`, `egito_planos.gd`,
`shaders/egito_plano.gdshader`, `egito_feixe.gdshader`):
- Fundo sem as colunas, estátuas de Anúbis, obeliscos e o cristal
  (`sprites/egito_fundo_sol.png` / `_lua.png`), e cada um deles como plano
  recortado na sua distância (`sprites/egito_planos_*.png`). Câmera anda mais
  (30 px) para mostrar a profundidade.
- Os quatro feixes de energia são peças vivas: saem de dentro do cristal
  (passam por trás dele, sem fresta) e chegam nas pontas dos obeliscos, com
  pulsos que correm mais com o grave. O brilho do cristal são ondas suaves
  (sem quadradinhos).
- As pontas de ouro das três pirâmides do fundo seguem os cristais: o da
  ponta esquerda apaga a pirâmide da esquerda, o da direita a da direita, e o
  do meio apaga as três.
- Cristais das pontas dos obeliscos levam tiro: trincam e, com 4 tiros,
  quebram e apagam o lado deles (feixes, ponta e a luz no obelisco); voltam
  sozinhos depois de um tempo. Quebrar o cristal do meio apaga **tudo**:
  feixes, pontas e a luz vermelha/dourada que ele joga no chão, nos degraus,
  no pedestal e nos obeliscos (`sprites/egito_fundo_luz.png` e o G da folha
  `egito_planos_brilho.png` dizem onde essa luz bate).
- Mecânica nova — **descarga do cristal**: cada acerto certo carrega o
  cristal (os feixes engrossam, correm e estalam); com 8 acertos, se o
  cristal estiver inteiro, raios saem das pontas acesas e estouram todos os
  brasões certos da tela ("DESCARGA DO CRISTAL!"). Brasão errado tira carga;
  tiro no cristal zera; tiro numa ponta tira metade.
- Nuvens com o humor do sol/lua: agitadas quando ele está feliz, quase
  paradas quando ele está tenso ou com sono.
- Poeira bem perto da câmera (grãos grandes que passam na frente de tudo).
- Tiro em coisa em pé é pedra e não deixa furo no chão atrás dela; o mapa de
  profundidade (`sprites/egito_profundidade.png`) agora é igual aos recortes.

**Mar** (`scripts/mar.gd`, `mar_vida.gd`, `mar_acerto.gd`,
`mar_cardume_dourado.gd`):
- Fundo sem as duas pedras com escritas (`sprites/atlantis_fundo.png`,
  reconstruído por remendos da própria imagem) e as pedras como planos com o
  contorno de verdade (`sprites/mar_pedra_esq.png` / `_dir.png`).
- Água-viva nada como as de verdade: o sino fecha e ela dá um tranco, depois
  desliza enquanto ele abre; inclina para onde vai; na trajetória clássica
  sobe do fundo. No tiro vira **pó de luz**: a própria imagem se desfaz em
  grãos a partir do ponto do tiro, que brilham, sobem e somem.
- O vaso agora solta um **cavalo-marinho espírito** (`tools/
  gerar_cavalo_espirito.py`): corpo de luz translúcido, borda acesa, anéis de
  luz e chamas escorrendo; sai num clarão, sobe nadando com halo e rastro e
  se desfaz em faíscas.
- Queda no chão refeita: o baú bate inteiro, quica, abre e espirra moedas e
  afunda na areia; o vaso parte em poucos pedaços grandes que tombam,
  assentam em distâncias diferentes e afundam; nuvem de areia rente ao chão.
- Mecânica nova — **cardume dourado**: de tempos em tempos (20 a 30 s) um
  cardume de peixes de ouro atravessa a água; acertar qualquer peixe vale
  +150 e o cardume se espalha num estouro de ouro.
- **Luz do sol de fora em movimento** (`shaders/fundo_profundo.gdshader`): os
  fachos finos que desciam saíram; no lugar, raios de sol largos saem do alto,
  nascem, se juntam, somem e balançam devagar, fortes na água aberta e fracos
  no que está perto; a luz cáustica anda no chão, no templo, nas paredes e nas
  pedras com escritas e acende mais onde passa um facho. Tudo no mesmo desenho
  do fundo: os raios já vêm animados numa textura (`sprites/mar_raios.png`,
  uma leitura por pixel, sem seno), a parte parada fica no alfa da máscara
  (`sprites/mar_profundidade.png`: R distância, G cáustica, A raios) e o que
  só depende do tempo é feito no vértice.
- Saiu a cachoeira que escorria em cima da pedra escura atrás do Poseidon
  (virava riscas na pedra).

**Anunciador de combos com voz** (`scripts/combo_anuncio.gd`, igual nas quatro
telas): o combo aparece grande no meio da tela, entra estourando e assenta
com um quique, com clarão, raios de luz e faíscas nas cores da tela, e sobe
sumindo. Níveis: DOUBLE HIT (2), TRIPLE HIT (3), QUADRA HIT (4), PENTA HIT (5),
MEGA COMBO (6), SUPER COMBO (8), INSANE (10), UNSTOPPABLE (13) e LEGENDARY
(16, e de novo a cada 4); entre um nível e outro aparece o número (x7). Em
cada nível novo a voz da tela anuncia e a música abaixa 7 dB enquanto ela
fala:
- Mar: Poseidon (bem grave, encorpado, eco de caverna; "vuum" de água e
  bolhas antes);
- Egito: o deus do templo (grave, eco longo de templo; gongo antes);
- Bar: locutor de saloon (rápido, voz de rádio antigo; sino de balcão antes);
- Arena: locutora da arena (voz de máquina, eco de estádio; laser subindo antes).
Falas especiais: POWER OF RA! na descarga do cristal, POSEIDON'S TREASURE! no
cardume dourado e PERFECT SEQUENCE! na sequência completa da Arena (que
ganhou contagem de acertos seguidos; erro ou tiro fora zera). As vozes são
`songs/voz/<tela>_<fala>.ogg` (39 falas, 440 KB), feitas pelo
`tools/gerar_vozes.py` (Piper + ffmpeg); os efeitos foram escolhidos para a
fala continuar clara (conferido com um reconhecedor de voz: 36 de 40 falas
reconhecidas, perto do que ele acerta com a voz sem efeito nenhum). A
pré-carga de cada tela já traz as vozes dela (`tools/gerar_precarga.py`).

**Demos do menu:** as prévias dos quatro cenários (`background_video/
teaser_*.mp4` e `.ogv`) foram regravadas com um robô jogando a versão atual
(mira com movimento de mão, só atira com o alvo certo sob a mira), gravadas
pelo Movie Maker do Godot em 1080x1920 e codificadas como antes (mp4 576x1024
30 q/s com AAC; ogv 432x768 24 q/s, 2,4 Mbit/s). Já mostram a luz nova do
Mar, as pontas das pirâmides e o anunciador com as vozes. Para regravar:
`bash tools/demos/gravar_demos.sh <cópia importada do projeto>`.

**Leve para a TV Box:** colunas e estátuas são imagem pura (sem shader); só
o cristal e os obeliscos usam o shader de brilho; os planos leem uma folha só
fora da troca sol/lua; o fundo não lê a máscara vazia e o céu das nuvens vem
pronto numa textura (sem contas por pixel). Medido: ver o relatório da
rodada.

APK 1.18.0 (código 20).

## Rodada 19: recuo, cenário catalogado, bar de cinema, vaso de cerâmica e fundos em alta

**Recuo como nos jogos de tiro** (`scripts/MiraGlobal.gd`, nas quatro telas):
o primeiro tiro vai exatamente na mira; tiros em sequência levantam a arma
(tranco para cima e um pouco para o lado, mais forte quanto mais rápida a
rajada) e a bala seguinte cai onde a arma subiu. Sem atirar, a arma volta
sozinha para a mira em ~0,4 s. A mira na tela dá o tranco junto, então a
bala cai exatamente onde a mira mostra. A pistola do Bar dá o tranco mais
forte, o arpão do Mar um pouco menos (a água segura) e o laser da Arena é
leve.

**Cenário catalogado (onde a bala chega):** cada lugar responde do seu jeito e
o que está longe demais não leva tiro. No Egito o catálogo sai do mapa de
profundidade: céu, **pirâmides** (e as pontas de ouro), colunas do horizonte e
o chão lá no fundo ficam fora do alcance — o tiro some na distância, sem
lasca nem marca (o brilho das pirâmides continua igual); as colunas grandes da
frente lascam pedra também no alto. No Bar: vidro da janela, cartaz, barril e
madeira. No Mar: pedras recortadas, chão perto (furo) e água.

**Recortes invisíveis:** as colunas grandes do Egito e as pedras com escritas
do Mar tinham, atrás delas, um fundo que mostrava o recorte quando a câmera
andava; o fundo atrás delas foi refeito continuando os vizinhos
(`tools/gerar_camadas.py`), e não aparece mais emenda.

**Bar** (`scripts/bar_janela.gd`, `bar_garrafa_fx.gd`, `estilhacos.gd`,
`shaders/bar_sol.gdshader`):
- A **janela** leva tiro: a vidraça racha do furo para fora e estoura; os
  cacos (do próprio vidro) giram, piscam quando pegam a luz, caem na tábua de
  baixo (ou no peitoril), quicam, se partem e ficam deitados um pouco; pó de
  vidro, faíscas de luz e lascas do caixilho. Ficam as pontas presas na
  moldura com as bordas brilhando, a luz de fora entra mais forte no buraco e
  o feixe de sol do bar cresce a cada vidraça quebrada; as vizinhas trincam.
  Som novo de vidro + madeira (`songs/janela_quebra.wav`). Tiro numa vidraça
  já quebrada derruba as pontas que sobraram (no buraco a bala sai lá fora).
- As **garrafas chegam caindo** do alto na tábua e assentam (achatam e voltam
  balançando presas pela base), com pó da madeira, um brilho correndo no
  ombro e o toque do vidro na tábua (`songs/garrafa_pousa.wav`); saem subindo.
- **Profundidade nas prateleiras:** cada garrafa tem sombra na parede de trás
  (luz da janela) e sombra de contato; embaixo de cada tábua a parede fica na
  sombra dela.
- **Garrafa estourando como em filme:** clarão no vidro, a bebida sai numa
  massa da cor dela que se abre e cai em gotas, e os cacos que giram de
  frente para a luz soltam faíscas.
- As listras do feixe de sol ficaram lisas (sem degraus na diagonal).

**Mar:** o vaso do cavalo-marinho quebra como **cerâmica de verdade**
(`scripts/mar_acerto.gd`): a trinca corre pelo vaso inteiro e só então os
cacos se soltam — poucos e grandes, recortados da silhueta real do vaso,
abrindo devagar (a água segura), tombando e mostrando o barro sem verniz de
costas e a espessura da borda, e afundando; o cascalho do pé cai como pedra.
O cavalo-marinho espírito continua saindo do vaso.

**Egito:** os pontos de acerto da lua saem em **prata** (os do sol em ouro).

**Cenários:** cada cartão mostra o nível certo, em 4 estrelas e escrito no
selo: Fundo do Mar FÁCIL, Bar MÉDIO, Deserto DIFÍCIL, Arena EXPERT.

**Fundos em alta (impressão de 4K)** (`scripts/hd.gd`, `tools/gerar_hd.py`,
`tools/gerar_hd.gd`): os fundos grandes foram refeitos por super-resolução
(rede EDSR) e entram na TV em 1,5x, comprimidos em ETC2 (a Mali-G31 lê
direto). O jogo continua vendo o tamanho antigo (todas as coordenadas valem
igual) e a TV desenha com mais detalhe — e a memória cai, porque o ETC2 ocupa
menos que o PNG sem perda de antes. Sem o arquivo em alta, o jogo usa o PNG
de sempre.

APK 1.19.0 (código 21).

## Rodada 20: alvos bônus, pôr do sol no Egito, águias que pousam e tiro que sai da mira

**A bala sai da mira** (`scripts/trajetoria.gd`): o traço do tiro é curto e
em perspectiva, nascendo logo abaixo da mira e afinando até o ponto — não
cruza mais a tela vindo de baixo. O recuo sai dali também.

**Avisos de tiro discretos** (`scripts/aviso_tiro.gd`): o resultado do tiro
aparece pequeno, em cor suave, um pouco acima do ponto (sem cobrir a mira) e
some em 0,8 s; recados do jogo numa pílula discreta logo abaixo do placar; os
pontos saltam do alvo. As faixas antigas do rodapé saíram das quatro telas.
Ao abrir cada tela as letras são montadas uma vez fora da tela e os sons dos
efeitos são preparados (`Maquina.aquecer`): o primeiro tiro não engasga.

**Alvos bônus** (tiro neles não é erro nem quebra o combo):
- **Egito:** quebrar o cristal do meio vale +300; o de um obelisco, +150.
- **Bar:** cada furo no barril vale +40 (até 6): o vinho espirra, jorra em
  arco até o chão, vira um fio que escorre pela madeira e pinga, deixa a
  madeira molhada e uma poça que cresce (`scripts/bar_vinho.gd`).
- **Mar:** cada peixe do cardume dourado vale +40 (estoura em ouro e sai
  girando; o resto nada mais rápido); o cardume inteiro, +200 a mais. Passa
  mais vezes.
- **Arena:** o LED do alto vale +50: estoura (clarão, faíscas, cacos do vidro
  vermelho), fica queimado soltando fumaça 7 s e volta piscando.

**Egito:**
- **Pôr do sol e nascer da lua** (e o contrário): na troca, o astro desce e
  some atrás da pirâmide do meio, o céu passa por um crepúsculo em brasa e a
  terra fica na luz baixa e quente enquanto o dia vira noite; depois o outro
  astro sobe de trás da pirâmide. Tudo muda junto (fundos, planos, ouro e
  prata das pontas, raios, águias). No lugar do disco pintado aparece o céu
  sem ele (`tools/gerar_ceu_astro.py`, `shaders/egito_astro.gdshader`).
- **Águias que pousam:** com o cristal de uma pirâmide quebrado, às vezes
  uma águia vem (direto, em espiral ou num mergulho) e pousa de frente na
  ponta apagada, grita uma vez e fica lá virando a cabeça, olhando para baixo
  e abrindo as asas como o falcão dos hieróglifos, até a energia voltar;
  outras vezes só dá umas voltas por cima; às vezes nada.
- O cristal e as pontas se refazem como energia (fios em espiral), sem os
  quadrados de antes. As pontas acesas brilham mais (metal mais claro,
  energia subindo até o pico e um halo); apagadas ficam ouro velho.
- Os brasões longe ficam nítidos (só um véu leve da distância).

**Mar:** os alvos que vêm do fundo são sempre cheios e nítidos (nada meio
transparente) e nunca miúdos; o navio que afunda tem cor de galeão (casco de
madeira, faixa ocre, velas de linho), um rombo de tiro soltando bolhas e mais
vida na queda (`tools/gerar_navio_cor.py`).

**Fundos em alta:** Mar, Egito (fundos e planos) e Arena também em super-resolução
ETC2, como o Bar.

APK 1.20.0 (código 22).

## Rodada 21: cenário inteiro, tiro em primeira pessoa e anúncios de cada cenário

**Cenário inteiro (Egito e Mar), sem recorte nem remendo aparecendo.** A
causa era a mesma nas duas telas: cada recorte (coluna, Anúbis, pedra com
escritas) andava diferente do fundo quando a câmera seguia a mira e mostrava
o remendo atrás dele; a luz que passava (onda do cristal, raios e cáustica do
mar) acendia só o fundo; e as lascas, a poeira e os clarões do tiro eram
desenhados atrás do recorte, aparecendo só fora do contorno.
- A cena anda inteira junta com a mira (fundo, planos e efeitos); a
  profundidade continua nos alvos e na frente (algas, poeira de perto).
- Debaixo de cada plano volta a pintura original: plano e fundo são os
  mesmos pixels (`tools/gerar_fundo_inteiro.py`, `tools/gerar_mar_inteiro.py`).
- A mesma luz nos planos e no fundo: no Egito a onda do cristal, o pulso da
  música e o crepúsculo (`shaders/egito_plano_simples.gdshader`); no Mar os
  raios e a cáustica do sol de fora numa conta só, usada pelo fundo e pelas
  pedras (`shaders/mar_luz.gdshaderinc`). As pedras do Mar pegam a cor da
  própria textura do fundo e têm contorno liso.
- Lascas, pó e clarões de cada tiro ficam na distância do ponto atingido:
  na frente da coluna ou da pedra atingida, atrás do que está mais perto. A
  luz grande (quebra do cristal) passa por cima de tudo.
- **Mar:** onde era o navio (o preenchimento deixava blocos em escada, um
  vulto cinza e uma rocha chapada atrás do templo) agora é a distância da
  água em névoa, com o templo e o Poseidon nela e o chão continuando para
  trás.

**Tiro em primeira pessoa** (`scripts/trajetoria.gd`): a arma está logo
abaixo da vista e a bala vai para dentro da tela, na linha da mira; então
ela aparece só no ponto da mira, saindo grande e encolhendo (anéis fechando)
enquanto vai para longe, e o clarão da arma acende de leve a beirada de
baixo. No ponto, o impacto de cada cenário: estrela de luz ao sol, anel frio
à lua, ondas e bolhas no mar, faísca e fumaça no bar, clarão de laser na
arena. Nada de risco nascendo no meio da tela.

**Anúncios de combo com a cara de cada cenário** (`scripts/combo_anuncio.gd`):
- **Bar:** placa de madeira de saloon pendurada, letra de ouro velho e
  estouro de pólvora, bem no alto (acima das garrafas de 100).
- **Mar:** letra de espuma, ondas abrindo na água e bolhas subindo, no alto
  da água.
- **Egito:** ouro com raios de sol. **Arena:** neon com linhas de laser.
- Sem o rosa/roxo de antes. Os pontos dos cristais do Egito saem em ouro ao
  sol e prata à lua; dois avisos de tiro no mesmo lugar não se encavalam.

APK 1.21.0 (código 23).

## Rodada 22: acerto só no desenho (Mar) e tudo mais leve para a TV Box

**Mar: o tiro só vale no desenho do alvo.** Antes o acerto era uma caixa ou
um oval em volta do alvo, com um raio mínimo para os de longe, e a água-viva
usava o tamanho do brilho que fica atrás dela (bem maior que ela). Agora vale
só o pixel do desenho que está na tela, no quadro da animação daquele
instante: água-viva (sino e tentáculos), vaso, baú, bomba e cada peixe do
cardume dourado. Errou por um pixel fora do desenho, é erro.
- As máscaras saem das próprias folhas de sprites, uma vez
  (`tools/gerar_mascaras_acerto.gd` → `sprites/acerto/*.res`, de 1 a 37 KB
  cada), e são carregadas ao abrir a fase (`scripts/mascara_acerto.gd`): no
  tiro é só ler um pixel, sem custo para a TV Box.

**Mais leve:**
- **Músicas** de 256 para 128 kbit/s (o Godot guarda o MP3 inteiro na memória
  enquanto toca): metade da memória e do tamanho, sem diferença na caixa de
  som da TV.
- **Texturas** grandes que estavam sem compressão passaram para ETC2 (a
  Mali-G31 lê direto; ocupa 1/4 da memória de vídeo e fica igual na tela):
  lanternas da Arena; olhos, pálpebras e brasões do sol e da lua e as águias
  do Egito. O mapa de brilho dos planos do Egito ficou na metade da
  resolução (é só a luz). As garrafas do Bar continuam sem perda: os cacos
  pegam a cor da própria folha.
- **Prévias do menu** regravadas com o robô jogando a versão atual (tiro em
  primeira pessoa, Mar sem remendo, anúncios novos); o plano B em `.ogv`
  (só toca se o vídeo pelo hardware falhar) com metade do tamanho.

APK 1.22.0 (código 24).

## Rodada 23: abrir na TV Box, carregamento inteligente e cada tela calibrada

**Por que a 1.22.0 não abria.** A última versão que rodou na TV Box foi a da
Rodada 13. Desde a Rodada 12, logo na partida do app (debaixo do preto da
apresentação), o jogo montava na placa **todos** os shaders das quatro fases
no mesmo quadro. Na Rodada 13 eram 11 shaders pequenos e já "nem sempre
abria". Até a 1.22.0 eles viraram 16, alguns bem maiores (o fundo do Egito,
o mar com a luz do sol, os planos 3D). Na Mali-G31 isso segura a placa por
vários segundos antes do primeiro quadro. Com a arma mexendo (ela é um mouse
mandando movimento sem parar), o Android dá o app como travado e o fecha,
antes até da apresentação.

**Carregamento inteligente** (`scripts/aquecedor.gd`,
`scripts/TransiaoGlobal.gd`, `tools/gerar_precarga.py`).
- A apresentação só monta os dois shaders dela. Nada das fases é preparado
  na partida do app.
- Cada tela tem a lista dos shaders que usa (`Precarga.SHADERS`, gerada pelo
  `tools/gerar_precarga.py` lendo os scripts da tela). Na troca de tela,
  depois dos arquivos, eles são montados **um por quadro**, ainda com o
  cartão de carregamento na tela; a barra conta as duas etapas (arquivos e
  shaders). A placa nunca fica segura por muito tempo.
- Um shader já montado não é montado de novo enquanto existir (voltar a uma
  fase é direto).
- A caixa-preta grava cada shader montado (`shader: ...`) e o tempo de cada
  tela. Se algum dia um shader derrubar o app, `queda.txt` diz qual.

**Cada tela calibrada para a TV Box** (`scripts/MiraGlobal.gd`).
- **Ritmo:** Egito e Mar já abrem em 30 quadros por segundo cravados (as
  duas mais pesadas para a placa). Bar, Arena e menus tentam 60 e caem para
  30 sozinhos se não segurarem. Em 30, a física também anda a 30 por segundo
  (eram dois passos por quadro) e um quadro atrasado não vira fila de passos.
- **Calibragem automática:** se mesmo em 30 uma tela não segura (mais de um
  quarto dos quadros de 3 s passando de 45 ms), ela fica **leve**: os
  enfeites marcados como opcionais param e somem (neve e cardumes do fundo
  do Mar, poeira e faíscas do Egito, poeira do sol do Bar). Alvos, cenário,
  luz, mecânicas e efeitos de acerto continuam iguais. A TV Box lembra
  (`user://ritmo.cfg`, por versão) e a tela já abre leve da próxima vez.

**Processador** (medido no PC, `--headless`, média por quadro jogando):
- O COMO JOGAR e a moldura decorada dele continuavam animando e redesenhando
  escondidos a partida inteira (40% do processador do Mar, 60% do Bar).
  Agora param quando somem (`como_jogar.gd`, `moldura_tema.gd`).
- O placar lê e aplica os dados a cada 2 quadros (no do meio só se algo
  estiver animando); o fim de partida escondido confere a cada 4 quadros.
- Resultado: Egito 6,8 → 3,9 ms (pior quadro 21 → 7 ms), Bar 6,9 → 4,8,
  Arena 2,5 → 2,0, menu 3,8 → 2,7.

**Placa de vídeo.** Os shaders dos recortes (pedras do Mar, planos do Egito)
não fazem conta nem leem as outras texturas fora do desenho (boa parte da
caixa de cada recorte); a luz do sol do Mar só lê a textura dos raios onde
há raio. A imagem é a mesma.

APK 1.23.0 (código 25).

## Rodada 24: letras prontas no APK, vídeo sem desistir cedo e abertura protegida

O que a 1.23.0 fez na TV Box: abriu (a partida do app ficou leve), mas a
apresentação não apareceu, o menu demorou e, no Mar, o jogo fechou no
primeiro acerto num vaso. No PC, com o pacote do próprio APK em OpenGL ES,
acertar vaso, água-viva e baú não fecha nem dá erro: a queda é do aparelho.

**Letras vetoriais, prontas dentro do APK** (`fonts/*.ttf.import`).
- Cada tamanho de letra com contorno virava imagens novas na placa, criadas
  na hora em que o texto aparecia, pelo processador. Os números que pulam e
  os anúncios mudam de tamanho na animação: no Mar eram **140 tamanhos, 54
  imagens, 48 MB** só de letras, e o primeiro acerto ("ACERTO! +80", os
  pontos, o anúncio) criava várias de uma vez, no meio do jogo.
- Agora as quatro fontes são MSDF (letra vetorial): um desenho de cada letra
  serve para todos os tamanhos e contornos, e os 180 caracteres do jogo já
  vêm desenhados no APK. **18 MB fixos**, nada é desenhado na TV Box e nada
  cresce. No Mar as texturas caíram de 86 para 58 MB. A troca de tela não
  joga mais esse desenho fora (`TransiaoGlobal._limpar_letras`).
- Contorno até 32% do tamanho da letra (o mais grosso do jogo) sai inteiro.

**Vídeo do menu** (`scripts/video_nativo.gd`). Na primeira vez de cada
vídeo (e em toda versão com vídeos novos) ele é copiado de dentro do APK
para a memória interna; isso levava mais que os 3 s de espera e o vídeo
caía no player do Godot (pesado no processador da TV Box): o menu ficava
lento. Agora os 3 s só contam depois de copiado e preparado (a cópia tem até
25 s).

**Apresentação protegida** (`scripts/caixa_preta.gd`). O contorno pulava a
apresentação para sempre (na mesma versão) depois de uma única queda dentro
dela, e uma primeira abertura lenta ou alguém saindo no meio já contavam.
Agora só pula se cair **duas vezes** ali.

**Primeiro tiro** (`scripts/aquecedor.gd`). Na primeira troca de tela o
material comum e a luz somada (que todos os efeitos de acerto usam) são
montados em todos os jeitos de desenhar (retângulo, polígono, linha,
partículas), debaixo do preto: o primeiro acerto não monta nada na placa.

APK 1.24.0 (código 26).

## Para testar no PC como se fosse a TV Box

```
LAZER_GIRO=1 godot --path . --resolution 1920x1080
```

`LAZER_MIRA_DIRETA=0` testa a mira girada.
