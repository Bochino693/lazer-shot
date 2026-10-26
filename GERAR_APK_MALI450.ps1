param(
    # 1 = topo do jogo na esquerda do HDMI (padrao), -1 = na direita,
    # 0 = monitor ja em pe. (Tambem da para trocar depois na CONFIGURACAO do
    # jogo: "Giro da tela".)
    [ValidateSet(1, -1, 0)][int]$Giro = 1,
    # A mira anda de lado quando a arma sobe? Gere de novo com -MiraGirada.
    [switch]$MiraGirada,
    # Quem gira a imagem para o monitor em pe. Padrao: o app abre deitado e
    # pede ao ANDROID a tela em pe; se a TV Box girar de verdade, a seta do
    # mouse anda no sentido da arma; se nao girar (ou puser o app numa faixa
    # no meio), o jogo gira por dentro sozinho. Com -JogoGira nem pede.
    # (Tambem da para trocar depois na CONFIGURACAO: "Quem gira a tela".)
    [switch]$JogoGira,
    # Instala na TV Box pelo adb depois de gerar (TV Box ligada no adb).
    [switch]$Instalar,
    # So puxa o registro do Android (logcat) da TV Box pelo adb, sem gerar APK:
    # abre o jogo, espera 60 s e salva em build\android\LOGCAT-TVBOX.txt
    [switch]$Registro,
    # IP da TV Box na rede (adb sem cabo), para -Registro e -Instalar:
    # GERAR_APK_MALI450.bat -Registro -Ip 192.168.0.50
    [string]$Ip = ""
)
# LAZER SHOT 2.0 - TV BOX MALI-450 (S905L/S905W, Android 7.1) - GODOT 3.6.2
#
# A placa de video dessa TV Box (Mali-450) so tem OpenGL ES 2.0: o jogo desta
# pasta e a versao em Godot 3.6.2 (GLES2), sem Gradle e sem plugin. Este
# script acha (ou baixa) o Godot 3.6.2 e os modelos de exportacao, gera o APK
# e ASSINA o APK ele mesmo (assinaturas v1 e v2, conferidas), mostrando tudo
# na hora nesta janela e no historico build\android\GERACAO-COMPLETA.log.
# Termina sozinho.
$ErrorActionPreference = "Stop"
# Com a barra de progresso ligada, o Windows PowerShell baixa e descompacta
# ate dez vezes mais devagar.
$ProgressPreference = "SilentlyContinue"
$Projeto = $PSScriptRoot
$Saida = Join-Path $Projeto "build\android"
New-Item -ItemType Directory -Path $Saida -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$SegundosSemSaida = 30
$EstourouTempo = $false
# Mensagens do Godot que nao sao problema (vao so para o historico, nao para
# a janela): o PC sem placa de som (WASAPI) e, na primeira importacao, os
# sons que ainda nao foram importados.
$RuidoGodot = 'HRESULT\)0x00000000|WASAPI|audio_driver_wasapi|All audio drivers failed|audio_server\.cpp|Cannot open file .res://\.import/|resource_format_binary\.cpp|^\s*\d+ param: --'
$Ignoradas = 0
# O Godot 3 no Windows escreve em Latin-1 (o "c" cedilha de "lancamento")
$Latin1 = [System.Text.Encoding]::GetEncoding(1252)
$Relogio = [System.Diagnostics.Stopwatch]::StartNew()
$VersaoGodot = "3.6.2"
$VersaoModelos = "3.6.2.stable"
$UrlBase = "https://github.com/godotengine/godot/releases/download/3.6.2-stable"
$Pacote = "com.lazersport.lazershot.mali"
$NomeApk = "LazerShot-Mali450.apk"
$PresetAndroid = Join-Path $Projeto "export_presets.cfg"
$ProjectGodot = Join-Path $Projeto "project.godot"
$PresetParaVoltar = $null
$ProjetoParaVoltar = $null

# O HISTORICO: tudo o que aparece nesta janela vai tambem, na hora, para
# build\android\GERACAO-COMPLETA.log. Se uma geracao antiga ainda segura o
# arquivo, grava num com a hora no nome.
$Historico = $null
$LogCompleto = Join-Path $Saida "GERACAO-COMPLETA.log"
foreach ($NomeLog in @("GERACAO-COMPLETA.log", ("GERACAO-COMPLETA-" + (Get-Date -Format "HHmmss") + ".log"))) {
    try {
        $CaminhoLog = Join-Path $Saida $NomeLog
        $FluxoLog = New-Object System.IO.FileStream($CaminhoLog, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
        $Historico = New-Object System.IO.StreamWriter($FluxoLog, $Utf8)
        $Historico.AutoFlush = $true
        $LogCompleto = $CaminhoLog
        break
    } catch { }
}

# Um clique dentro da janela (a selecao rapida do Windows) congela tudo o que
# ela mostra ate apertar uma tecla, e parece que travou: a selecao rapida fica
# desligada enquanto o gerador roda (volta no fim).
$ModoConsoleAntigo = $null
try {
    Add-Type -Namespace LazerShotMali -Name Console -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@
    $ModoConsole = [uint32]0
    if ([LazerShotMali.Console]::GetConsoleMode([LazerShotMali.Console]::GetStdHandle(-10), [ref]$ModoConsole)) {
        $ModoConsoleAntigo = $ModoConsole
        [void][LazerShotMali.Console]::SetConsoleMode([LazerShotMali.Console]::GetStdHandle(-10), [uint32](($ModoConsole -band 0xFFFFFFBF) -bor 0x80))
    }
} catch { }

# Escreve na janela e no historico.
function Diz([string]$Texto, [string]$Cor) {
    if ($Cor) { Write-Host $Texto -ForegroundColor $Cor } else { Write-Host $Texto }
    if ($script:Historico) {
        try { $script:Historico.WriteLine($Texto) } catch { }
    }
}

# Sai do script: devolve o export_presets.cfg e o project.godot como estavam
# e fecha o historico.
function Encerrar([int]$Codigo) {
    if ($script:PresetParaVoltar) {
        try { [IO.File]::WriteAllText($script:PresetAndroid, $script:PresetParaVoltar, $script:Utf8) } catch { }
        $script:PresetParaVoltar = $null
    }
    if ($script:ProjetoParaVoltar) {
        try { [IO.File]::WriteAllText($script:ProjectGodot, $script:ProjetoParaVoltar, $script:Utf8) } catch { }
        $script:ProjetoParaVoltar = $null
    }
    if ($null -ne $script:ModoConsoleAntigo) {
        try { [void][LazerShotMali.Console]::SetConsoleMode([LazerShotMali.Console]::GetStdHandle(-10), [uint32]($script:ModoConsoleAntigo -bor 0x80)) } catch { }
        $script:ModoConsoleAntigo = $null
    }
    if ($script:Historico) {
        try { $script:Historico.Close() } catch { }
        $script:Historico = $null
    }
    exit $Codigo
}

# Qualquer falha sai uma vez so, em portugues, com o caminho do historico.
trap {
    Diz ""
    Diz ("ERRO: " + $_.Exception.Message) "Red"
    Diz "Historico completo: $LogCompleto"
    Encerrar 1
}

function Tempo([double]$Segundos) {
    $S = [int][Math]::Floor($Segundos)
    if ($S -lt 60) { return "$S s" }
    return ("{0} min {1:D2} s" -f [int][Math]::Floor($S / 60), ($S % 60))
}

# Um argumento na linha de comando do Windows (aspas so quando precisa).
function Aspas([string]$Texto) {
    if ($Texto -ne "" -and $Texto -notmatch '[\s"]') { return $Texto }
    $Texto = [Regex]::Replace($Texto, '(\\*)"', '$1$1\"')
    $Texto = [Regex]::Replace($Texto, '(\\+)$', '$1$1')
    return '"' + $Texto + '"'
}

# Encerra um programa e tudo o que ele abriu.
function Parar-Arvore($Processo) {
    try {
        if ($env:SystemRoot) {
            $Taskkill = Join-Path $env:SystemRoot "System32\taskkill.exe"
            if (Test-Path -LiteralPath $Taskkill) {
                $InicioKill = New-Object System.Diagnostics.ProcessStartInfo
                $InicioKill.FileName = $Taskkill
                $InicioKill.Arguments = "/PID $($Processo.Id) /T /F"
                $InicioKill.UseShellExecute = $false
                $InicioKill.CreateNoWindow = $true
                $Kill = [System.Diagnostics.Process]::Start($InicioKill)
                [void]$Kill.WaitForExit(15000)
            }
        }
        if (-not $Processo.HasExited) { $Processo.Kill() }
    } catch { }
}

# RODA UM PROGRAMA MOSTRANDO CADA LINHA NA HORA (na janela, no historico e em
# $Log) e devolve o codigo de saida dele. Espera SO o proprio programa. Sem
# linha nova por um tempo, avisa que segue trabalhando ($Aviso: texto ou bloco
# que devolve o texto). Passou de $LimiteMinutos, encerra o programa e tudo o
# que ele abriu ($script:EstourouTempo fica $true). -SoHistorico: as linhas
# vao so para $Log e o historico (a janela mostra o resumo).
function Rodar {
    param([string]$Exe, [string]$Argumentos, [string]$Log, [double]$LimiteMinutos, $Aviso, [int]$Silencio = 0,
        [System.Text.Encoding]$Codificacao = $null, [string]$Ruido = "", [switch]$SoHistorico)
    if ($Silencio -le 0) { $Silencio = $script:SegundosSemSaida }
    if ($null -eq $Codificacao) { $Codificacao = $script:Utf8 }
    $script:EstourouTempo = $false
    if (-not (Test-Path -LiteralPath $Exe)) { throw "Nao encontrei $Exe" }
    $Inicio = New-Object System.Diagnostics.ProcessStartInfo
    $Inicio.FileName = $Exe
    $Inicio.Arguments = $Argumentos
    $Inicio.WorkingDirectory = $script:Projeto
    $Inicio.UseShellExecute = $false
    $Inicio.RedirectStandardOutput = $true
    $Inicio.RedirectStandardError = $true
    $Inicio.StandardOutputEncoding = $Codificacao
    $Inicio.StandardErrorEncoding = $Codificacao
    $Gravador = $null
    if ($Log) {
        $Gravador = New-Object System.IO.StreamWriter($Log, $false, $script:Utf8)
        $Gravador.AutoFlush = $true
    }
    try {
        $Processo = [System.Diagnostics.Process]::Start($Inicio)
        $Leitores = @($Processo.StandardOutput, $Processo.StandardError)
        $Tarefas = @($null, $null)
        $Abertas = @($true, $true)
        $PularAt = @($false, $false)
        $Cronometro = [System.Diagnostics.Stopwatch]::StartNew()
        $UltimaLinha = 0.0
        $UltimoAviso = 0.0
        $TerminouEm = -1.0
        while ($true) {
            $Pendentes = [System.Collections.Generic.List[System.Threading.Tasks.Task]]::new()
            for ($i = 0; $i -lt 2; $i++) {
                if (-not $Abertas[$i]) { continue }
                if ($null -eq $Tarefas[$i]) { $Tarefas[$i] = $Leitores[$i].ReadLineAsync() }
                $Pendentes.Add($Tarefas[$i])
            }
            if ($Pendentes.Count -gt 0) {
                [void][System.Threading.Tasks.Task]::WaitAny($Pendentes.ToArray(), 500)
            } else {
                Start-Sleep -Milliseconds 200
            }
            $Agora = $Cronometro.Elapsed.TotalSeconds
            for ($i = 0; $i -lt 2; $i++) {
                $Tarefa = $Tarefas[$i]
                if ($null -eq $Tarefa -or -not $Tarefa.IsCompleted) { continue }
                $Tarefas[$i] = $null
                $Linha = $null
                if ($Tarefa.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion) { $Linha = $Tarefa.Result }
                if ($null -eq $Linha) { $Abertas[$i] = $false; continue }
                # sem as cores do terminal (viram lixo na janela e no arquivo)
                $Linha = [Regex]::Replace($Linha, '\x1b\[[0-9;?]*[A-Za-z]', '')
                if ($Gravador) { $Gravador.WriteLine($Linha) }
                if ($SoHistorico) {
                    if ($script:Historico) { try { $script:Historico.WriteLine($Linha) } catch { } }
                    $UltimaLinha = $Agora
                    continue
                }
                # o Godot escreve uma linha por arquivo empacotado: na janela
                # so as que dizem alguma coisa (no arquivo vai tudo)
                if ($Linha -match '^\s*(ADDING|STORING|savepack):') { $UltimaLinha = $Agora; continue }
                # mensagem sem importancia (e a linha "at:" que vem com ela):
                # so no historico
                if ($Ruido -and $Linha -match $Ruido) {
                    $script:Ignoradas++
                    $PularAt[$i] = $true
                    if ($script:Historico) { try { $script:Historico.WriteLine($Linha) } catch { } }
                    $UltimaLinha = $Agora
                    continue
                }
                if ($PularAt[$i] -and $Linha -match '^\s+at: ') {
                    if ($script:Historico) { try { $script:Historico.WriteLine($Linha) } catch { } }
                    $UltimaLinha = $Agora
                    continue
                }
                $PularAt[$i] = $false
                if ($i -eq 1) { Diz $Linha "DarkYellow" } else { Diz $Linha }
                $UltimaLinha = $Agora
            }
            if (-not $Abertas[0] -and -not $Abertas[1]) { break }
            if ($Processo.HasExited) {
                # Terminou. Se a saida dele continua aberta, e porque um
                # processo que ele deixou ficou com ela: nao espera.
                if ($TerminouEm -lt 0) { $TerminouEm = $Agora }
                elseif ($Agora - $TerminouEm -ge 3) { break }
                continue
            }
            if ($LimiteMinutos -gt 0 -and $Agora -ge $LimiteMinutos * 60) {
                $script:EstourouTempo = $true
                Diz ("Passou de {0}: encerrando o programa e o que ele abriu." -f (Tempo ($LimiteMinutos * 60))) "Red"
                Parar-Arvore $Processo
                break
            }
            if ($Aviso -and ($Agora - $UltimaLinha) -ge $Silencio -and ($Agora - $UltimoAviso) -ge $Silencio) {
                $UltimoAviso = $Agora
                $TextoAviso = if ($Aviso -is [scriptblock]) { & $Aviso } else { $Aviso }
                Diz ("      ... ainda trabalhando ({0}). {1}" -f (Tempo $Agora), $TextoAviso) "DarkGray"
            }
        }
    } finally {
        if ($Gravador) { $Gravador.Close() }
    }
    if ($script:EstourouTempo) { return -1 }
    if (-not $Processo.HasExited) { [void]$Processo.WaitForExit(10000) }
    if (-not $Processo.HasExited) { return -1 }
    return $Processo.ExitCode
}

# O Godot saiu derrubado pelo driver de video? 0x6E76.... ("nv") e o driver
# da NVIDIA fechando o programa ("Error code 7" e parecidos); negativo
# (0xC0000005 e outros) e o Godot caindo sozinho.
function Saida-Do-Driver([int]$Codigo) {
    return ((($Codigo -shr 16) -band 0xFFFF) -eq 0x6E76) -or ($Codigo -lt -1)
}
function Motivo-Da-Saida([int]$Codigo) {
    if ((($Codigo -shr 16) -band 0xFFFF) -eq 0x6E76) { return (", 0x{0:X8}: o driver da placa de video NVIDIA fechou o Godot" -f $Codigo) }
    if ($Codigo -lt -1) { return (", 0x{0:X8}: o Godot caiu" -f $Codigo) }
    return ""
}

# Baixa um arquivo mostrando quanto ja veio.
function Baixar([string]$Url, [string]$Destino, [double]$LimiteMinutos) {
    if (Test-Path -LiteralPath $Destino) { Remove-Item -LiteralPath $Destino -Force }
    $Curl = if ($env:SystemRoot) { Join-Path $env:SystemRoot "System32\curl.exe" } else { "" }
    if ($Curl -and (Test-Path -LiteralPath $Curl)) {
        $AvisoDownload = { if (Test-Path -LiteralPath $Destino) { "{0:N0} MB baixados." -f ((Get-Item -LiteralPath $Destino).Length / 1MB) } else { "Conectando..." } }
        $Codigo = Rodar $Curl ("-L -sS --fail --retry 3 --output " + (Aspas $Destino) + " " + (Aspas $Url)) "" $LimiteMinutos $AvisoDownload 15
        if ($Codigo -ne 0) { throw "Nao consegui baixar $Url (curl, codigo $Codigo). Confira a internet e rode de novo." }
    } else {
        Diz "      (baixando sem barra de andamento; aguarde)"
        Invoke-WebRequest -Uri $Url -OutFile $Destino -UseBasicParsing
    }
    if (-not (Test-Path -LiteralPath $Destino)) { throw "O download de $Url nao deixou o arquivo." }
}

# O SDK do Android: C:\AndroidSdk, ANDROID_HOME, ANDROID_SDK_ROOT ou o do
# Android Studio.
function Achar-Sdk {
    foreach ($Candidato in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, "C:\AndroidSdk", (Join-Path $env:LOCALAPPDATA "Android\Sdk"))) {
        if ($Candidato -and (Test-Path (Join-Path $Candidato "platform-tools\adb.exe"))) { return $Candidato }
    }
    return $null
}

# adb sem cabo: conecta na TV Box pelo IP (a depuracao precisa estar ligada).
function Conectar-TvBox([string]$Adb) {
    if ($Ip -eq "") { return }
    Diz "Conectando na TV Box em $Ip ..."
    & $Adb connect $Ip
    Start-Sleep -Seconds 2
}

# Registro do Android: o que a TV Box diz quando o jogo abre (ou fecha). A
# caixa-preta do jogo aparece na CONFIGURACAO dele (botao VER).
function Puxar-Registro([string]$Adb) {
    $Arquivo = Join-Path $Saida "LOGCAT-TVBOX.txt"
    & $Adb logcat -c
    & $Adb shell am force-stop $Pacote
    & $Adb shell monkey -p $Pacote -c android.intent.category.LAUNCHER 1
    Diz "Jogo aberto na TV Box. Aguardando 60 s (nao mexa na TV Box)..."
    Start-Sleep -Seconds 60
    & $Adb logcat -d -v time -b main -b system -b crash > $Arquivo
    & $Adb shell getprop ro.product.model >> $Arquivo
    & $Adb shell getprop ro.board.platform >> $Arquivo
    & $Adb shell getprop ro.build.version.release >> $Arquivo
    & $Adb shell cat /proc/meminfo >> $Arquivo
    & $Adb shell dumpsys meminfo $Pacote >> $Arquivo
    Diz "Registro salvo em $Arquivo . Envie esse arquivo." "Green"
}

if ($Registro) {
    $SdkR = Achar-Sdk
    if (-not $SdkR) { throw "adb nao encontrado (Android SDK em C:\AndroidSdk)." }
    $AdbR = Join-Path $SdkR "platform-tools\adb.exe"
    Conectar-TvBox $AdbR
    if (-not ((& $AdbR devices) -match "\tdevice$")) { throw "Nenhuma TV Box no adb. Ligue a depuracao (ADB) na TV Box e rode de novo com -Ip IP-DA-TVBOX" }
    Puxar-Registro $AdbR
    Encerrar 0
}

Diz "LAZER SHOT 2.0 - APK DA TV BOX MALI-450 (Android 7.1, Godot $VersaoGodot)" "Cyan"
Diz "Historico desta geracao: $LogCompleto"

# ------------------------------------------------------------------
# ESTA PASTA E A VERSAO MALI-450 (Godot 3.6), INTEIRA E SEM MISTURA.
# A versao 4.6 (Pro Ultra / TX9) e outro projeto: extraida por cima desta, o
# Godot 3 tentaria ler os scripts do Godot 4 e a exportacao falharia.
if (-not (Test-Path -LiteralPath $ProjectGodot)) { throw "project.godot nao encontrado nesta pasta." }
if (-not (Test-Path -LiteralPath $PresetAndroid)) { throw "export_presets.cfg nao encontrado nesta pasta." }
$ConfigTexto = [IO.File]::ReadAllText($ProjectGodot)
if ($ConfigTexto -notmatch '(?m)^config_version=4\s*$' -or -not (Test-Path -LiteralPath (Join-Path $Projeto "scripts\fase.gd"))) {
    throw "Esta pasta nao e a versao Mali-450 (Godot 3.6) do Lazer Shot. Baixe a branch tvbox-mali450 numa pasta NOVA (ex.: C:\LazerShotMali)."
}
# (So arquivos que a Mali-450 nao tem nem com outra caixa de letra: no
# Windows, scripts\Maquina.gd da 4.6 e scripts\maquina.gd daqui sao o mesmo.)
$Misturados = @()
foreach ($Velho in @("scripts\pincel.gd", "scripts\webcam.gd", "scripts\video_nativo.gd", "scripts\hd.gd", "scenes\main.tscn", "scenes\admin.tscn", ".godot")) {
    if (Test-Path -LiteralPath (Join-Path $Projeto $Velho)) { $Misturados += $Velho }
}
$Uids = @(Get-ChildItem -LiteralPath $Projeto -Recurse -File -Filter "*.uid" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "*\build\*" })
if ($Uids.Count -gt 0) { $Misturados += ("{0} arquivos .uid (do Godot 4)" -f $Uids.Count) }
if ($Misturados.Count -gt 0) {
    throw ("Esta pasta mistura a versao 4.6 com a Mali-450:`n  " + ($Misturados -join "`n  ") +
        "`nBaixe a branch tvbox-mali450 numa pasta NOVA e vazia (ex.: C:\LazerShotMali) e rode o gerador de la.")
}
# O caminho comprido demais atrapalha o Godot no Windows.
if ($Projeto.Length -gt 120) {
    Diz "AVISO: o caminho desta pasta e comprido ($($Projeto.Length) letras). Se der erro, mova para C:\LazerShotMali." "Yellow"
}

# O giro da tela, quem gira e a mira (project.godot): vale para este APK; o
# arquivo volta como estava no fim. O app sempre abre deitado (muitas TV Box
# Amlogic poem app em pe numa faixa no meio da tela, sem girar) e a tela de
# quando o app abre (a marca Lazer & Sport, no lugar do simbolo do Godot) sai
# ja girada para o lado do giro. Depois o jogo pede ao Android a tela em pe e
# confere; com -JogoGira nem pede.
$ConfigNovo = [Regex]::Replace($ConfigTexto, '(?m)^tela/giro=.*$', "tela/giro=$Giro")
$ConfigNovo = [Regex]::Replace($ConfigNovo, '(?m)^tela/mira_direta=.*$', "tela/mira_direta=$(if ($MiraGirada) { 'false' } else { 'true' })")
$Rotacao = if ($JogoGira) { "jogo" } else { "android" }
$ConfigNovo = [Regex]::Replace($ConfigNovo, '(?m)^tela/rotacao=.*$', "tela/rotacao=`"$Rotacao`"")
$ConfigNovo = [Regex]::Replace($ConfigNovo, '(?m)^window/handheld/orientation=.*$', 'window/handheld/orientation="landscape"')
$Splash = @{ 1 = "splash_giro_1.png"; -1 = "splash_giro_m1.png"; 0 = "splash_giro_0.png" }[$Giro]
if (-not (Test-Path -LiteralPath (Join-Path $Projeto "splash\$Splash"))) {
    throw "Falta splash\$Splash (a tela de abertura do app). Baixe a branch tvbox-mali450 de novo, inteira."
}
$ConfigNovo = [Regex]::Replace($ConfigNovo, '(?m)^boot_splash/image=.*$', "boot_splash/image=`"res://splash/$Splash`"")
if ($ConfigNovo -ne $ConfigTexto) {
    $ProjetoParaVoltar = $ConfigTexto
    [IO.File]::WriteAllText($ProjectGodot, $ConfigNovo, $Utf8)
}
Diz "Giro da tela: $Giro  (tambem se troca na CONFIGURACAO do jogo)"
Diz "Quem gira a tela: $(if ($JogoGira) { 'o JOGO (nem pede ao Android)' } else { 'o ANDROID se a TV Box girar de verdade; senao o JOGO, sozinho' })"
Diz "Mira: $(if ($MiraGirada) { 'girada com o HDMI' } else { 'direta (monitor em pe)' })"

# ------------------------------------------------------------------
# [1/4] O GODOT 3.6.2 E OS MODELOS DE EXPORTACAO.
$PastaGodotPropria = Join-Path $env:LOCALAPPDATA "LazerSport\Godot_v$VersaoGodot"
$Godot = $null
foreach ($Pasta in @($Projeto, "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Documents", $PastaGodotPropria)) {
    if (-not (Test-Path -LiteralPath $Pasta)) { continue }
    $Achado = Get-ChildItem -LiteralPath $Pasta -Recurse -File -Filter "Godot_v$VersaoGodot-stable_win64*.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike "*\build\*" } | Select-Object -First 1
    if ($Achado) { $Godot = $Achado.FullName; break }
}
if (-not $Godot) {
    Diz "[1/4] Baixando o Godot $VersaoGodot (primeira vez, ~40 MB)..." "Cyan"
    New-Item -ItemType Directory -Path $PastaGodotPropria -Force | Out-Null
    $Zip = Join-Path $PastaGodotPropria "godot.zip"
    Baixar "$UrlBase/Godot_v$VersaoGodot-stable_win64.exe.zip" $Zip 30
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Zip, $PastaGodotPropria)
    Remove-Item -LiteralPath $Zip -Force -ErrorAction SilentlyContinue
    $Achado = Get-ChildItem -LiteralPath $PastaGodotPropria -Recurse -File -Filter "Godot_v$VersaoGodot-stable_win64*.exe" | Select-Object -First 1
    if (-not $Achado) { throw "O Godot $VersaoGodot foi baixado, mas o executavel nao apareceu em $PastaGodotPropria." }
    $Godot = $Achado.FullName
}
Diz "[1/4] Godot: $Godot" "Cyan"

# Os modelos de exportacao do Godot 3 moram em %APPDATA%\Godot\templates.
$PastaModelos = Join-Path $env:APPDATA "Godot\templates\$VersaoModelos"
if (-not (Test-Path (Join-Path $PastaModelos "android_release.apk"))) {
    Diz "      Baixando os modelos de exportacao do Godot $VersaoGodot (primeira vez: ~600 MB, demora)..." "Cyan"
    $Temporaria = Join-Path $env:TEMP "lazer-shot-mali-modelos"
    New-Item -ItemType Directory -Path $Temporaria -Force | Out-Null
    $Tpz = Join-Path $Temporaria "modelos.zip"
    $Extraido = Join-Path $Temporaria "extraido"
    Baixar "$UrlBase/Godot_v$VersaoGodot-stable_export_templates.tpz" $Tpz 90
    Diz "      Descompactando..."
    if (Test-Path $Extraido) { Remove-Item -LiteralPath $Extraido -Recurse -Force }
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Tpz, $Extraido)
    $Origem = Join-Path $Extraido "templates"
    if (-not (Test-Path (Join-Path $Origem "android_release.apk"))) { throw "Pacote de modelos invalido ou incompleto (sem android_release.apk)." }
    New-Item -ItemType Directory -Path $PastaModelos -Force | Out-Null
    Copy-Item -Path (Join-Path $Origem "*") -Destination $PastaModelos -Recurse -Force
    Remove-Item -LiteralPath $Temporaria -Recurse -Force -ErrorAction SilentlyContinue
    Diz "      Modelos $VersaoModelos instalados." "Green"
} else {
    Diz "      Modelos de exportacao $VersaoModelos confirmados." "Green"
}

# A SETA DO ANDROID. No Android 7 o Godot 3.6 nao esconde a seta do mouse e
# muitas TV Box nao aceitam a seta transparente: a seta ficava junto com a
# mira (andando ao contrario com a tela girada). Este gerador faz uma copia
# dos modelos (build\android\modelos) em que todos os formatos de seta do
# Godot viram o "nenhum" do Android (o mesmo que os outros jogos de tiro
# usam), e o jogo pede esse formato. Os modelos originais nao mudam; a copia
# so e refeita quando os originais mudam.
function Modelo-Sem-Seta([string]$Origem, [string]$Destino) {
    $Latin = [System.Text.Encoding]::GetEncoding(28591)
    $Valores = @(1000, 1008, 1002, 1007, 1004, 1004, 1021, 1021, 1000, 1015, 1014, 1017, 1016, 1020, 1015, 1014, 1003)
    $Tabela = New-Object byte[] ($Valores.Count * 4)
    for ($i = 0; $i -lt $Valores.Count; $i++) { [BitConverter]::GetBytes([int]$Valores[$i]).CopyTo($Tabela, $i * 4) }
    $Procura = $Latin.GetString($Tabela)
    Copy-Item -LiteralPath $Origem -Destination $Destino -Force
    $Certo = $true
    $Zip = [System.IO.Compression.ZipFile]::Open($Destino, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        foreach ($Nome in @("lib/armeabi-v7a/libgodot_android.so", "lib/arm64-v8a/libgodot_android.so")) {
            $Entrada = $Zip.GetEntry($Nome)
            if (-not $Entrada) { $Certo = $false; break }
            $Memoria = New-Object System.IO.MemoryStream
            $Fluxo = $Entrada.Open()
            try { $Fluxo.CopyTo($Memoria) } finally { $Fluxo.Dispose() }
            $Bytes = $Memoria.ToArray()
            $Memoria.Dispose()
            $Texto = $Latin.GetString($Bytes)
            $Pos = $Texto.IndexOf($Procura, [StringComparison]::Ordinal)
            # a tabela tem de estar la uma vez so; senao a copia nao vale
            if ($Pos -lt 0 -or $Texto.IndexOf($Procura, $Pos + 1, [StringComparison]::Ordinal) -ge 0) { $Certo = $false; break }
            $Texto = $null
            [Array]::Clear($Bytes, $Pos, $Tabela.Length)
            $Entrada.Delete()
            $Nova = $Zip.CreateEntry($Nome, [System.IO.Compression.CompressionLevel]::Optimal)
            $Fluxo = $Nova.Open()
            try { $Fluxo.Write($Bytes, 0, $Bytes.Length) } finally { $Fluxo.Dispose() }
        }
    } finally {
        $Zip.Dispose()
    }
    if (-not $Certo) { Remove-Item -LiteralPath $Destino -Force -ErrorAction SilentlyContinue }
    return $Certo
}

$PastaSemSeta = Join-Path $Saida "modelos"
$ModeloRelease = Join-Path $PastaSemSeta "android_release.apk"
$ModeloDebug = Join-Path $PastaSemSeta "android_debug.apk"
$SetaNula = $false
try {
    $Originais = @(Get-Item -LiteralPath (Join-Path $PastaModelos "android_release.apk"), (Join-Path $PastaModelos "android_debug.apk"))
    $Assinatura = ($Originais | ForEach-Object { "{0} {1} {2}" -f $_.Name, $_.Length, $_.LastWriteTimeUtc.Ticks }) -join "`n"
    $MarcaSemSeta = Join-Path $PastaSemSeta "sem_seta.txt"
    if ((Test-Path -LiteralPath $MarcaSemSeta) -and (Test-Path -LiteralPath $ModeloRelease) -and (Test-Path -LiteralPath $ModeloDebug) -and
        ([IO.File]::ReadAllText($MarcaSemSeta).Trim() -eq $Assinatura)) {
        $SetaNula = $true
    } else {
        Diz "      Preparando os modelos sem a seta do mouse (primeira vez: ~1 min)..." "Cyan"
        New-Item -ItemType Directory -Path $PastaSemSeta -Force | Out-Null
        Remove-Item -LiteralPath $MarcaSemSeta -Force -ErrorAction SilentlyContinue
        if ((Modelo-Sem-Seta $Originais[0].FullName $ModeloRelease) -and (Modelo-Sem-Seta $Originais[1].FullName $ModeloDebug)) {
            [IO.File]::WriteAllText($MarcaSemSeta, $Assinatura, $Utf8)
            $SetaNula = $true
        }
    }
} catch {
    Diz ("      (modelos sem a seta: {0})" -f $_.Exception.Message)
    $SetaNula = $false
}
if ($SetaNula) {
    Diz "      Seta do mouse: escondida pelo Android (formato 'nenhum')." "Green"
    $ProjetoAgora = [IO.File]::ReadAllText($ProjectGodot)
    $ProjetoSemSeta = [Regex]::Replace($ProjetoAgora, '(?m)^tela/seta_nula=.*$', 'tela/seta_nula=true')
    if ($ProjetoSemSeta -ne $ProjetoAgora) {
        if (-not $ProjetoParaVoltar) { $ProjetoParaVoltar = $ProjetoAgora }
        [IO.File]::WriteAllText($ProjectGodot, $ProjetoSemSeta, $Utf8)
    }
} else {
    Diz "      AVISO: nao deu para preparar os modelos sem a seta; o APK sai com a seta transparente do jogo." "Yellow"
}

# ------------------------------------------------------------------
# [2/4] ANDROID SDK, JAVA E A CHAVE. Quem assina o APK e este gerador (veja
# "A ASSINATURA", mais abaixo), com o apksigner.jar do build-tools mais novo.
$Sdk = Achar-Sdk
if (-not $Sdk) { throw "Android SDK nao encontrado. Instale-o em C:\AndroidSdk (com platform-tools e build-tools) ou defina ANDROID_HOME." }
# (O Godot 3 so exporta se achar um apksigner.bat no build-tools, mesmo sem
# usa-lo.)
$AssinadorBat = Get-ChildItem -LiteralPath (Join-Path $Sdk "build-tools") -Recurse -File -Filter "apksigner.bat" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $AssinadorBat) { throw "Falta o build-tools no Android SDK ($Sdk\build-tools\...\apksigner.bat). Instale um build-tools pelo sdkmanager e rode de novo." }
$ApksignerJar = $null
$Zipalign = $null
$VersaoBuildTools = [version]"0.0"
foreach ($PastaBt in (Get-ChildItem -LiteralPath (Join-Path $Sdk "build-tools") -Directory -ErrorAction SilentlyContinue)) {
    $Numero = [Regex]::Match($PastaBt.Name, '^\d+(\.\d+){0,3}').Value
    $Versao = [version]"0.0"
    if ($Numero) { try { $Versao = [version]$(if ($Numero.Contains('.')) { $Numero } else { "$Numero.0" }) } catch { } }
    $Jar = Join-Path $PastaBt.FullName "lib\apksigner.jar"
    if ((Test-Path -LiteralPath $Jar) -and (-not $ApksignerJar -or $Versao -gt $VersaoBuildTools)) {
        $ApksignerJar = $Jar
        $VersaoBuildTools = $Versao
        $Alinhador = Join-Path $PastaBt.FullName "zipalign.exe"
        if (Test-Path -LiteralPath $Alinhador) { $Zipalign = $Alinhador }
    }
    if (-not $Zipalign -and (Test-Path -LiteralPath (Join-Path $PastaBt.FullName "zipalign.exe"))) { $Zipalign = Join-Path $PastaBt.FullName "zipalign.exe" }
}
$env:ANDROID_HOME = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk

# Java: o apksigner precisa dele. De preferencia o 17 (o mesmo dos outros jogos).
$Jdks = New-Object System.Collections.Generic.List[string]
if ($env:JAVA_HOME) { $Jdks.Add($env:JAVA_HOME) }
$JavaNoCaminho = Get-Command java.exe -ErrorAction SilentlyContinue
if ($JavaNoCaminho) { $Jdks.Add((Split-Path (Split-Path $JavaNoCaminho.Source -Parent) -Parent)) }
foreach ($Base in @("$env:ProgramFiles\Eclipse Adoptium", "$env:ProgramFiles\Java", "$env:ProgramFiles\Microsoft", "$env:ProgramFiles\Amazon Corretto", "$env:ProgramFiles\Zulu", "C:\Program Files\Android\Android Studio")) {
    if (Test-Path $Base) {
        Get-ChildItem -LiteralPath $Base -Directory -ErrorAction SilentlyContinue | ForEach-Object { $Jdks.Add($_.FullName) }
        $Jdks.Add($Base)
    }
}
$Java = $null
foreach ($Candidato in ($Jdks | Select-Object -Unique)) {
    if ($Candidato -and (Test-Path -LiteralPath (Join-Path $Candidato "bin\java.exe"))) {
        if (-not $Java) { $Java = $Candidato }
        if ($Candidato -match '17') { $Java = $Candidato; break }
    }
}
if (-not $Java) { throw "Java nao encontrado neste PC. Instale o Java 17 (Eclipse Temurin 17) e rode de novo." }
$Java = (Resolve-Path -LiteralPath $Java).Path
$env:JAVA_HOME = $Java
$env:Path = (Join-Path $Java "bin") + ";" + $env:Path
$JavaExe = Join-Path $Java "bin\java.exe"
$Jarsigner = Join-Path $Java "bin\jarsigner.exe"
if (-not (Test-Path -LiteralPath $Jarsigner)) { $Jarsigner = $null }
Diz "[2/4] Android SDK: $Sdk" "Cyan"
if ($ApksignerJar) {
    Diz "      Assinador: $ApksignerJar (build-tools $VersaoBuildTools)"
} elseif ($Jarsigner) {
    Diz "      Assinador: $Jarsigner (o build-tools nao tem o apksigner.jar)" "Yellow"
} else {
    throw "Nao achei com o que assinar o APK: falta o lib\apksigner.jar no build-tools ($Sdk\build-tools) e o jarsigner no Java ($Java). Instale um build-tools pelo sdkmanager e rode de novo."
}
Diz "      Java: $Java"

# A CHAVE: a de depuracao do Godot (%APPDATA%\Godot\keystores), a mesma dos
# outros jogos. O APK novo instala POR CIMA do anterior sem apagar ranking e
# configuracao. Se este PC nunca gerou APK, a chave e criada.
$Chave = Join-Path $env:APPDATA "Godot\keystores\debug.keystore"
if (-not (Test-Path -LiteralPath $Chave)) {
    Diz "      Criando a chave de assinatura (primeira vez neste PC)..." "Yellow"
    New-Item -ItemType Directory -Path (Split-Path $Chave) -Force | Out-Null
    $Keytool = Join-Path $Java "bin\keytool.exe"
    $Codigo = Rodar $Keytool ("-genkeypair -v -keystore " + (Aspas $Chave) + " -storepass android -keypass android -alias androiddebugkey -dname " + (Aspas "CN=Android Debug,O=Android,C=US") + " -keyalg RSA -keysize 2048 -validity 10000") "" 5 ""
    if ($Codigo -ne 0 -or -not (Test-Path -LiteralPath $Chave)) { throw "Nao consegui criar a chave de assinatura em $Chave (keytool, codigo $Codigo)." }
}
$ChaveGodot = $Chave -replace '\\', '/'

# A configuracao do editor do Godot 3 (o SDK e a chave de depuracao).
$ConfigEditor = Join-Path $env:APPDATA "Godot\editor_settings-3.tres"
$TextoEditor = if (Test-Path -LiteralPath $ConfigEditor) { [IO.File]::ReadAllText($ConfigEditor) } else { "" }
if ($TextoEditor -and -not $TextoEditor.TrimStart([char]0xFEFF, ' ', "`r", "`n", "`t").StartsWith("[gd_resource")) {
    $Copia = "$ConfigEditor.backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item -LiteralPath $ConfigEditor -Destination $Copia
    Diz "      Configuracao do Godot 3 estragada guardada em $Copia" "Yellow"
    $TextoEditor = ""
}
if (-not $TextoEditor) {
    New-Item -ItemType Directory -Path (Split-Path $ConfigEditor) -Force | Out-Null
    $TextoEditor = "[gd_resource type=`"EditorSettings`" format=2]`n`n[resource]`n"
}
foreach ($Par in @(
        @("export/android/android_sdk_path", ($Sdk -replace '\\', '/')),
        @("export/android/debug_keystore", $ChaveGodot),
        @("export/android/debug_keystore_user", "androiddebugkey"),
        @("export/android/debug_keystore_pass", "android"))) {
    $Linha = "$($Par[0]) = `"$($Par[1])`""
    $Padrao = '(?m)^' + [Regex]::Escape($Par[0]) + '\s*=.*$'
    if ($TextoEditor -match $Padrao) {
        $TextoEditor = [Regex]::Replace($TextoEditor, $Padrao, $Linha.Replace('$', '$$'))
    } else {
        $TextoEditor = $TextoEditor.TrimEnd() + "`n" + $Linha + "`n"
    }
}
[IO.File]::WriteAllText($ConfigEditor, $TextoEditor, $Utf8)

# O Godot entrega o APK de RELEASE SEM assinatura: quem assina e este gerador
# (logo depois da exportacao). No preset, "signed" desligado e as tres linhas
# da chave de release vazias (o Godot 3 quer as tres ou nenhuma). Um preset de
# versao antiga e acertado so durante a geracao (volta como estava no fim).
$PresetTexto = [IO.File]::ReadAllText($PresetAndroid)
if ($PresetTexto -notmatch 'name="Android"') { throw "export_presets.cfg sem o preset Android. Baixe a branch tvbox-mali450 de novo." }
$PresetNovo = [Regex]::Replace($PresetTexto, '(?m)^package/signed=.*$', 'package/signed=false')
foreach ($Campo in @("keystore/release", "keystore/release_user", "keystore/release_password")) {
    $PresetNovo = [Regex]::Replace($PresetNovo, '(?m)^' + [Regex]::Escape($Campo) + '=.*$', "$Campo=`"`"")
}
# Os modelos sem a seta do mouse (veja "A SETA DO ANDROID"), so nesta geracao.
if ($SetaNula) {
    $PresetNovo = [Regex]::Replace($PresetNovo, '(?m)^custom_template/release=.*$', "custom_template/release=`"$($ModeloRelease.Replace('\', '/'))`"")
    $PresetNovo = [Regex]::Replace($PresetNovo, '(?m)^custom_template/debug=.*$', "custom_template/debug=`"$($ModeloDebug.Replace('\', '/'))`"")
}
if ($PresetNovo -ne $PresetTexto) {
    $PresetParaVoltar = $PresetTexto
    [IO.File]::WriteAllText($PresetAndroid, $PresetNovo, $Utf8)
}

# ------------------------------------------------------------------
# A IMPORTACAO LIMPA. Na primeira geracao de cada versao o cache de
# importacao (.import) e refeito do zero: os arquivos .import voltam ao estado
# de fabrica (sem os caminhos do cache de outro PC) e o Godot importa tudo de
# novo, sem procurar arquivos que ainda nao existem. O carimbo e o
# version/code do export_presets.cfg.
$Cache = Join-Path $Projeto ".import"
$MarcaCache = Join-Path $Cache ".lazer_mali"
$Carimbo = ([Regex]::Match($PresetTexto, '(?m)^version/code=(\d+)')).Groups[1].Value
$CacheDestaVersao = (Test-Path -LiteralPath $MarcaCache) -and (([IO.File]::ReadAllText($MarcaCache)).Trim() -eq $Carimbo)
if (-not $CacheDestaVersao) {
    Diz ""
    Diz "      Preparando a importacao do zero (primeira geracao desta versao)..." "Cyan"
    if (Test-Path -LiteralPath $Cache) { Remove-Item -LiteralPath $Cache -Recurse -Force }
    $Limpos = 0
    foreach ($Arq in (Get-ChildItem -LiteralPath $Projeto -Recurse -File -Filter "*.import" -ErrorAction SilentlyContinue)) {
        if ($Arq.FullName -like "*\build\*" -or $Arq.FullName -like "*\arte_original\*" -or $Arq.FullName -like "*\sobras_de_versoes_antigas\*") { continue }
        $T = [IO.File]::ReadAllText($Arq.FullName)
        $N = [Regex]::Replace($T, '(?m)^(path(\.\w+)?|dest_files)=.*\r?\n', '')
        $N = [Regex]::Replace($N, '(?ms)^metadata=\{.*?^\}\r?\n', '')
        if ($N -ne $T) {
            [IO.File]::WriteAllText($Arq.FullName, $N, $Utf8)
            $Limpos++
        }
    }
    Diz "      $Limpos arquivos de importacao prontos para importar de novo."
}

# ------------------------------------------------------------------
# [3/4] A IMPORTACAO (imagens em ETC1 para a Mali-450, sons em ADPCM). Numa
# pasta nova o Godot 3 le os scripts ANTES de importar sons e imagens: montar
# so o pacote (.pck) primeiro importa tudo com calma. O .pck vai fora depois.
$LogImportacao = Join-Path $Saida "importacao.log"
$Pck = Join-Path $Saida "importacao.pck"
Diz ""
Diz "[3/4] Importando imagens e sons (primeira vez: alguns minutos)..." "Cyan"
# --disable-render-loop: o editor do Godot nem desenha. A placa de video so
# abre o OpenGL e fica parada (placa antiga com driver fraco, como a NVIDIA
# GeForce 8400GS, caia no meio da montagem com "Error code 7"). O resultado
# e o mesmo: APK conferido igual, arquivo por arquivo.
$SemDesenhar = @("--no-window", "--disable-render-loop", "--resolution", "64x64")
$Argumentos = (@($SemDesenhar + @("--path", $Projeto, "--export-pack", "Android", $Pck)) | ForEach-Object { Aspas $_ }) -join " "
$Codigo = Rodar $Godot $Argumentos $LogImportacao 30 "O Godot esta importando as imagens e os sons." 0 $Latin1 $RuidoGodot
if ($EstourouTempo) { throw "A importacao passou de 30 minutos e foi encerrada. Envie o historico." }
if (Test-Path -LiteralPath $Pck) { Remove-Item -LiteralPath $Pck -Force }
$TextoImportacao = if (Test-Path -LiteralPath $LogImportacao) { [IO.File]::ReadAllText($LogImportacao) } else { "" }
if ($TextoImportacao -match "SCRIPT ERROR: Parse Error|Failed to load script|Failed to create an autoload") {
    throw "Existe erro em um script do jogo (o Godot nao conseguiu ler). Detalhes em $LogImportacao"
}

# ------------------------------------------------------------------
# [4/4] O APK.
$PastaApk = Join-Path $Projeto "APK-Pronto"
New-Item -ItemType Directory -Path $PastaApk -Force | Out-Null
Get-ChildItem -LiteralPath $PastaApk -Force | Remove-Item -Recurse -Force
# o Godot monta o APK sem assinatura; o assinado e o $ApkAssinado
$ApkExportado = Join-Path $Saida "LazerShot-Mali450-sem-assinatura.apk"
$ApkAssinado = Join-Path $Saida $NomeApk
if (Test-Path -LiteralPath $ApkAssinado) { Remove-Item -LiteralPath $ApkAssinado -Force }
$LogApk = Join-Path $Saida "exportacao.log"
Diz ""
Diz "[4/4] Montando o APK..." "Cyan"
$Argumentos = (@($SemDesenhar + @("--path", $Projeto, "--export", "Android", $ApkExportado)) | ForEach-Object { Aspas $_ }) -join " "
$Tentativa = 0
while ($true) {
    $Tentativa++
    if (Test-Path -LiteralPath $ApkExportado) { Remove-Item -LiteralPath $ApkExportado -Force }
    $Codigo = Rodar $Godot $Argumentos $LogApk 20 "O Godot esta montando o APK." 0 $Latin1 $RuidoGodot
    if ($EstourouTempo) { throw "A exportacao passou de 20 minutos e foi encerrada. Envie o historico." }
    # Sem APK (o Godot fechou sozinho, 0xC0000005 e parecidos): uma segunda
    # vez costuma passar.
    if (-not (Test-Path -LiteralPath $ApkExportado) -and $Tentativa -lt 2) {
        Diz ("O APK nao saiu (codigo {0}{1}). Tentando mais uma vez..." -f $Codigo, (Motivo-Da-Saida $Codigo)) "Yellow"
        continue
    }
    break
}
$TextoApk = if (Test-Path -LiteralPath $LogApk) { [IO.File]::ReadAllText($LogApk) } else { "" }
if (-not (Test-Path -LiteralPath $ApkExportado)) {
    # as ultimas linhas do Godot (a janela nao mostra a lista de arquivos)
    $Ultimas = @(Get-Content -LiteralPath $LogApk -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -and $_ -notmatch '^\s*(ADDING|STORING|savepack):' }) | Select-Object -Last 15
    if ($Ultimas.Count -gt 0) {
        Diz "Ultimas linhas do Godot (exportacao.log):" "Yellow"
        foreach ($L in $Ultimas) { Diz ("   " + $L) }
    }
    if (Saida-Do-Driver $Codigo) {
        Diz "DICA: quem fechou o Godot foi o driver da placa de video (NVIDIA). Reinicie o PC, feche jogos e navegadores e rode de novo. Se continuar, reinstale o driver da placa (GeForce 8400GS: o ultimo e o 342.01) ou gere o APK em outro PC." "Yellow"
    }
    if ($TextoApk -match "keystore|Keystore") { Diz "DICA: problema com a chave de depuracao ($Chave)." "Yellow" }
    if ($TextoApk -match "apksigner|adb|SDK") { Diz "DICA: o Godot confere o Android SDK ($Sdk): platform-tools (adb) e build-tools (apksigner)." "Yellow" }
    if ($TextoApk -match "template|Template") { Diz "DICA: apague a pasta $PastaModelos e rode de novo (os modelos baixam de novo)." "Yellow" }
    throw "O APK nao foi criado (codigo $Codigo). A causa esta nas linhas acima (e em $LogApk)."
}

# CONFERE O QUE VAI PARA A TV BOX: o motor (ARM 32 e 64 bits), o jogo e as
# imagens comprimidas para a Mali-450 (ETC1).
$Tamanho = (Get-Item -LiteralPath $ApkExportado).Length
if ($Tamanho -lt 10MB) { throw "O APK saiu incompleto ($([math]::Round($Tamanho / 1MB, 1)) MB)." }
$ZipApk = [System.IO.Compression.ZipFile]::OpenRead($ApkExportado)
try {
    $Nomes = $ZipApk.Entries | ForEach-Object { $_.FullName }
    foreach ($Lib in @("lib/armeabi-v7a/libgodot_android.so", "lib/arm64-v8a/libgodot_android.so")) {
        if ($Nomes -notcontains $Lib) { throw "O APK saiu sem $Lib." }
    }
    if (-not ($Nomes | Where-Object { $_ -like "assets/.import/fundo_menu.jpg-*.etc.stex" })) {
        throw "O APK saiu sem as imagens em ETC1 (a Mali-450 precisa delas). Apague a pasta .import e rode de novo."
    }
    if (-not ($Nomes | Where-Object { $_ -like "assets/scripts/fase.gdc" })) {
        throw "O APK saiu sem os scripts do jogo."
    }
} finally {
    $ZipApk.Dispose()
}

# ------------------------------------------------------------------
# A ASSINATURA. Sem ela o Android recusa o APK com "o pacote parece estar
# corrompido". O gerador assina sozinho, com a chave de sempre, e confere:
#  1. pelo apksigner.jar do build-tools, rodando direto no Java: assinaturas
#     v1 (vale em qualquer Android) e v2 (Android 7 em diante);
#  2. se o apksigner falhar, pelo jarsigner do proprio Java (so a v1, que a
#     TV Box tambem aceita), com o zipalign do build-tools.
# O apksigner.bat nao e usado: em SDK sem o pacote antigo "tools" ele termina
# sem fazer nada e sem dar erro, e o APK saia sem assinatura.
# O Java 17 nao deixa os apksigner antigos usarem partes internas dele; a
# JDK_JAVA_OPTIONS libera essas partes (o Java 8 nem le essa variavel).
function Rodar-Java([string]$Exe, [string[]]$Opcoes, [string]$Log) {
    $Antes = $env:JDK_JAVA_OPTIONS
    $env:JDK_JAVA_OPTIONS = "--add-exports=java.base/sun.security.x509=ALL-UNNAMED --add-exports=java.base/sun.security.pkcs=ALL-UNNAMED --add-exports=java.base/sun.security.util=ALL-UNNAMED"
    try {
        return (Rodar $Exe (($Opcoes | ForEach-Object { Aspas $_ }) -join " ") $Log 10 "" 0 $null "" -SoHistorico)
    } finally {
        $env:JDK_JAVA_OPTIONS = $Antes
    }
}
function Texto-Do([string]$Log) {
    if (Test-Path -LiteralPath $Log) { return [IO.File]::ReadAllText($Log) }
    return ""
}
function Assinar-Apksigner([string]$Entrada, [string]$Destino) {
    if (-not $script:ApksignerJar) { return $false }
    if (Test-Path -LiteralPath $Destino) { Remove-Item -LiteralPath $Destino -Force }
    $Opcoes = @("-Xmx1024M", "-Duser.language=en", "-cp", $script:ApksignerJar, "com.android.apksigner.ApkSignerTool", "sign",
        "--ks", $script:Chave, "--ks-key-alias", "androiddebugkey", "--ks-pass", "pass:android", "--key-pass", "pass:android",
        "--min-sdk-version", "21", "--v1-signing-enabled", "true", "--v2-signing-enabled", "true")
    if ($script:VersaoBuildTools -ge [version]"28.0") { $Opcoes += @("--v3-signing-enabled", "false") }
    if ($script:VersaoBuildTools -ge [version]"30.0") { $Opcoes += @("--v4-signing-enabled", "false") }
    $Opcoes += @("--out", $Destino, $Entrada)
    $Codigo = Rodar-Java $script:JavaExe $Opcoes (Join-Path $script:Saida "assinatura.log")
    if ($Codigo -ne 0 -or -not (Test-Path -LiteralPath $Destino)) { return $false }
    # a conferencia: o proprio apksigner, exigindo a v1 E a v2
    $Log = Join-Path $script:Saida "assinatura-conferida.log"
    $Codigo = Rodar-Java $script:JavaExe @("-Xmx1024M", "-Duser.language=en", "-cp", $script:ApksignerJar, "com.android.apksigner.ApkSignerTool",
        "verify", "--verbose", "--min-sdk-version", "21", $Destino) $Log
    $Texto = Texto-Do $Log
    return ($Codigo -eq 0 -and $Texto -match '(?m)^Verifies' -and
        $Texto -match 'v1 scheme \(JAR signing\): true' -and $Texto -match 'v2 scheme \(APK Signature Scheme v2\): true')
}
function Assinar-Jarsigner([string]$Entrada, [string]$Destino) {
    if (-not $script:Jarsigner) { return $false }
    $SoV1 = "$Destino.v1"
    foreach ($Velho in @($Destino, $SoV1)) { if (Test-Path -LiteralPath $Velho) { Remove-Item -LiteralPath $Velho -Force } }
    $Codigo = Rodar-Java $script:Jarsigner @("-J-Duser.language=en", "-keystore", $script:Chave, "-storepass", "android", "-keypass", "android",
        "-sigalg", "SHA256withRSA", "-digestalg", "SHA-256", "-signedjar", $SoV1, $Entrada, "androiddebugkey") (Join-Path $script:Saida "assinatura-jarsigner.log")
    if ($Codigo -ne 0 -or -not (Test-Path -LiteralPath $SoV1)) { return $false }
    # o jarsigner desalinha o APK por dentro: o zipalign alinha de novo (a
    # assinatura v1 continua valendo)
    $Alinhado = $false
    if ($script:Zipalign) {
        $Codigo = Rodar $script:Zipalign ((@("-f", "-p", "4", $SoV1, $Destino) | ForEach-Object { Aspas $_ }) -join " ") (Join-Path $script:Saida "zipalign.log") 10 "" 0 $null "" -SoHistorico
        $Alinhado = ($Codigo -eq 0 -and (Test-Path -LiteralPath $Destino))
    }
    if ($Alinhado) { Remove-Item -LiteralPath $SoV1 -Force } else { Move-Item -LiteralPath $SoV1 -Destination $Destino -Force }
    $Log = Join-Path $script:Saida "assinatura-conferida.log"
    $Codigo = Rodar-Java $script:Jarsigner @("-J-Duser.language=en", "-verify", $Destino) $Log
    return ($Codigo -eq 0 -and (Texto-Do $Log) -match 'jar verified')
}

$LogAssinatura = Join-Path $Saida "assinatura.log"
Diz ""
Diz "      Assinando o APK (chave $Chave)..."
$Assinatura = ""
$AssinouApksigner = $false
try { $AssinouApksigner = Assinar-Apksigner $ApkExportado $ApkAssinado } catch { Diz "      apksigner: $($_.Exception.Message)" "Yellow" }
if ($AssinouApksigner) {
    $Assinatura = "v1 + v2 (apksigner do build-tools $VersaoBuildTools)"
} else {
    if ($ApksignerJar) {
        Diz "      O apksigner nao assinou (detalhes em $LogAssinatura). Assinando pelo jarsigner do Java..." "Yellow"
    }
    try {
        if (Assinar-Jarsigner $ApkExportado $ApkAssinado) { $Assinatura = "v1 (jarsigner do Java)" }
    } catch { Diz "      jarsigner: $($_.Exception.Message)" "Yellow" }
}
if (-not $Assinatura) {
    $Ultimas = (Texto-Do $LogAssinatura) + (Texto-Do (Join-Path $Saida "assinatura-jarsigner.log")) + (Texto-Do (Join-Path $Saida "assinatura-conferida.log"))
    $Ultimas -split "`r?`n" | Where-Object { $_ -match '\S' -and $_ -notmatch 'JDK_JAVA_OPTIONS' } | Select-Object -Last 12 | ForEach-Object { Diz "      $_" "DarkYellow" }
    if ((Texto-Do $LogAssinatura) + (Texto-Do (Join-Path $Saida "assinatura-jarsigner.log")) -match 'password|Keystore was tampered|alias') {
        Diz "DICA: a chave $Chave nao abriu com a senha android e o nome androiddebugkey. Renomeie esse arquivo e rode de novo (o gerador cria outra)." "Yellow"
    }
    throw "Nao consegui assinar o APK. Sem assinatura a TV Box recusa ('pacote corrompido'). Envie o historico."
}
# O APK assinado tem a assinatura dentro (META-INF), alem da conferencia.
$ZipApk = [System.IO.Compression.ZipFile]::OpenRead($ApkAssinado)
try {
    $Nomes = $ZipApk.Entries | ForEach-Object { $_.FullName }
    if ($Nomes -notcontains "META-INF/MANIFEST.MF" -or -not ($Nomes | Where-Object { $_ -match '^META-INF/[^/]+\.(RSA|EC|DSA)$' })) {
        throw "O APK assinado saiu sem a assinatura v1 (META-INF). Envie o historico."
    }
    if ($Nomes -notcontains "lib/armeabi-v7a/libgodot_android.so") { throw "O APK assinado saiu sem o motor ARM." }
} finally {
    $ZipApk.Dispose()
}
Diz "      Assinatura conferida: $Assinatura." "Green"
$Tamanho = (Get-Item -LiteralPath $ApkAssinado).Length
# a versao vai no nome do arquivo: no pendrive, o APK novo nao se confunde
# com um antigo
$VersaoNome = ([Regex]::Match($PresetTexto, '(?m)^version/name="([0-9A-Za-z.\-]+)"')).Groups[1].Value
$Apk = Join-Path $PastaApk $(if ($VersaoNome) { "LazerShot-Mali450-$VersaoNome.apk" } else { $NomeApk })
Copy-Item -LiteralPath $ApkAssinado -Destination $Apk -Force
Remove-Item -LiteralPath $ApkExportado -Force -ErrorAction SilentlyContinue
$Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Apk).Hash
# o cache agora e desta versao: as proximas geracoes nao importam tudo de novo
if ((Test-Path -LiteralPath $Cache) -and $Carimbo) { [IO.File]::WriteAllText($MarcaCache, $Carimbo) }

Diz ""
if ($Ignoradas -gt 0) {
    Diz "($Ignoradas mensagens tecnicas do Godot sem importancia ficaram so no historico.)" "DarkGray"
}
Diz "============================================================" "Green"
Diz ("  APK PRONTO E CONFERIDO em {0}" -f (Tempo $Relogio.Elapsed.TotalSeconds)) "Green"
Diz "============================================================" "Green"
Diz "Arquivo: $Apk"
Diz ("Tamanho: {0:N1} MB" -f ($Tamanho / 1MB))
Diz "SHA256: $Hash"
Diz "Pacote: $Pacote (versao Mali-450; fica ao lado da versao 4.6, nao por cima)."
Diz "Assinatura: $Assinatura, com a chave de sempre."
Diz "Conferido: motor ARM 32 e 64 bits, scripts e imagens em ETC1 dentro do APK."
Diz "O jogo gira por dentro: mantenha o HDMI deitado (1920x1080)."
Diz "No pendrive: copie o APK e use 'Ejetar' no Windows antes de tirar o pendrive."

if ($Instalar) {
    $Adb = Join-Path $Sdk "platform-tools\adb.exe"
    Conectar-TvBox $Adb
    & $Adb install -r $Apk
    Puxar-Registro $Adb
}
Encerrar 0
