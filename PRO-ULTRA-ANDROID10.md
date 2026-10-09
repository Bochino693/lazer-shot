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

## Para testar no PC como se fosse a TV Box

```
LAZER_GIRO=1 godot --path . --resolution 1920x1080
```

`LAZER_MIRA_DIRETA=0` testa a mira girada.
