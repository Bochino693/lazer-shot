param(
    # 1 = topo do jogo na esquerda do HDMI, -1 = na direita, 0 = sem giro
    [ValidateSet(1, -1, 0)][int]$Giro = 1,
    # A mira anda de lado quando a arma sobe? Gere de novo com -MiraGirada.
    [switch]$MiraGirada,
    # Qual APK gerar (Rodada 31): as duas versoes (padrao), so a LEVE (TV Box
    # PROSB-3000, a mais fraca) ou so a AVANCADA (TV Box mais forte).
    [ValidateSet("Ambas", "Leve", "Avancada")][string]$Versao = "Ambas",
    # RESERVA (Rodada 32): os APKs sem o Gradle e sem o plugin da webcam, do
    # jeito da 1.30. O jogo funciona inteiro; so a foto antes da partida fica
    # de fora. Serve para testar na TV Box enquanto o Gradle nao funciona
    # neste PC (GERAR_APK_SEM_CAMERA.bat).
    [switch]$SemCamera,
    # Instala na TV Box pelo adb depois de gerar (TV Box ligada no adb).
    # Com -Versao Ambas instala a LEVE.
    [switch]$Instalar,
    # So puxa o registro do Android (logcat) da TV Box pelo adb, sem gerar APK:
    # abre o jogo, espera 60 s e salva em build\android\LOGCAT-TVBOX.txt
    [switch]$Registro,
    # IP da TV Box na rede (adb sem cabo), para -Registro e -Instalar:
    # GERAR_APK_PRO_ULTRA.bat -Registro -Ip 192.168.0.50
    [string]$Ip = ""
)
$ErrorActionPreference = "Stop"
# Com a barra de progresso ligada, o Windows PowerShell baixa e descompacta
# ate dez vezes mais devagar.
$ProgressPreference = "SilentlyContinue"
$Projeto = $PSScriptRoot
$Saida = Join-Path $Projeto "build\android"
New-Item -ItemType Directory -Path $Saida -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Utf8 = New-Object System.Text.UTF8Encoding($false)
# Sem nenhuma linha nova por este tempo, a janela avisa que segue trabalhando.
$SegundosSemSaida = 30
$EstourouTempo = $false
$PresetAndroid = Join-Path $Projeto "export_presets.cfg"
$PresetParaVoltar = $null
$Relogio = [System.Diagnostics.Stopwatch]::StartNew()

# O HISTORICO (Rodada 32). Tudo o que aparece nesta janela vai tambem, na
# hora, para build\android\GERACAO-COMPLETA.log. Ate a 1.31.0 o .bat mandava
# tudo para esse arquivo e so mostrava no fim: a janela parecia parada. Se uma
# geracao antiga ainda segura o arquivo, grava num com a hora no nome.
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
    Add-Type -Namespace LazerShot -Name Console -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@
    $ModoConsole = [uint32]0
    if ([LazerShot.Console]::GetConsoleMode([LazerShot.Console]::GetStdHandle(-10), [ref]$ModoConsole)) {
        $ModoConsoleAntigo = $ModoConsole
        [void][LazerShot.Console]::SetConsoleMode([LazerShot.Console]::GetStdHandle(-10), [uint32](($ModoConsole -band 0xFFFFFFBF) -bor 0x80))
    }
} catch { }

# Escreve na janela e no historico.
function Diz([string]$Texto, [string]$Cor) {
    if ($Cor) { Write-Host $Texto -ForegroundColor $Cor } else { Write-Host $Texto }
    if ($script:Historico) {
        try { $script:Historico.WriteLine($Texto) } catch { }
    }
}

# Sai do script: devolve o export_presets.cfg do modo reserva e fecha o
# historico.
function Encerrar([int]$Codigo) {
    if ($script:PresetParaVoltar) {
        try { [IO.File]::WriteAllText($script:PresetAndroid, $script:PresetParaVoltar, $script:Utf8) } catch { }
        $script:PresetParaVoltar = $null
    }
    if ($null -ne $script:ModoConsoleAntigo) {
        try { [void][LazerShot.Console]::SetConsoleMode([LazerShot.Console]::GetStdHandle(-10), [uint32]($script:ModoConsoleAntigo -bor 0x80)) } catch { }
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

# Encerra um programa e tudo o que ele abriu (o Gradle, por exemplo).
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
# $Log) e devolve o codigo de saida dele.
# Espera SO o proprio programa. Ate a 1.31.0 o Start-Process -Wait esperava
# tambem o processo que o Gradle deixa rodando depois de compilar (ele fica
# ate 3 horas): a janela ficava parada e a geracao nunca terminava.
# Sem linha nova por um tempo, avisa que segue trabalhando ($Aviso: texto ou
# bloco que devolve o texto). Passou de $LimiteMinutos, encerra o programa e
# tudo o que ele abriu ($script:EstourouTempo fica $true).
function Rodar {
    param([string]$Exe, [string]$Argumentos, [string]$Log, [double]$LimiteMinutos, $Aviso, [int]$Silencio = 0)
    if ($Silencio -le 0) { $Silencio = $script:SegundosSemSaida }
    $script:EstourouTempo = $false
    if (-not (Test-Path -LiteralPath $Exe)) { throw "Nao encontrei $Exe" }
    $Inicio = New-Object System.Diagnostics.ProcessStartInfo
    $Inicio.FileName = $Exe
    $Inicio.Arguments = $Argumentos
    $Inicio.WorkingDirectory = $script:Projeto
    $Inicio.UseShellExecute = $false
    $Inicio.RedirectStandardOutput = $true
    $Inicio.RedirectStandardError = $true
    $Inicio.StandardOutputEncoding = $script:Utf8
    $Inicio.StandardErrorEncoding = $script:Utf8
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
                if ($i -eq 1) { Diz $Linha "DarkYellow" } else { Diz $Linha }
                $UltimaLinha = $Agora
            }
            if (-not $Abertas[0] -and -not $Abertas[1]) { break }
            if ($Processo.HasExited) {
                # Terminou. Se a saida dele continua aberta, e porque um
                # processo que ele deixou (o Gradle) ficou com ela: nao espera.
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

# O que o Gradle (ou o Godot) disse, traduzido em uma dica.
function Dar-Dica([string]$Texto) {
    if ($Texto -match "Could not resolve|Could not GET|Could not HEAD|Could not download|UnknownHost|No such host|Connection refused|Connect timed out|Read timed out") {
        Diz "DICA: o Gradle nao conseguiu baixar uma biblioteca. Confira a internet deste PC (e se o antivirus ou o firewall bloqueia o Java) e rode de novo." "Yellow"
    }
    if ($Texto -match "licen[cs]es? .{0,40}not (been )?accepted|not accepted the license|License for package") {
        $Gerente = Get-ChildItem -LiteralPath $script:Sdk -Recurse -Filter "sdkmanager.bat" -ErrorAction SilentlyContinue | Select-Object -First 1
        $Comando = if ($Gerente) { "`"$($Gerente.FullName)`" --licenses" } else { "sdkmanager --licenses (pasta cmdline-tools do Android SDK)" }
        Diz "DICA: falta aceitar as licencas do Android SDK. Num Prompt de Comando, rode $Comando e responda y em todas." "Yellow"
    }
    if ($Texto -match "Filename too long|path too long|exceeds the maximum path|MAX_PATH") {
        Diz "DICA: o caminho desta pasta e comprido demais para o Gradle. Mova o projeto para uma pasta curta, como C:\LazerShot, e rode de novo." "Yellow"
    }
    if ($Texto -match "not enough space|No space left|There is not enough space") {
        Diz "DICA: falta espaco em disco. Libere alguns GB (o Gradle guarda as bibliotecas na pasta .gradle do usuario) e rode de novo." "Yellow"
    }
    if ($Texto -match "requires Java 17|Unsupported class file major version|invalid source release") {
        Diz "DICA: o Gradle precisa do JDK 17. Confira a linha JDK 17 no inicio desta janela." "Yellow"
    }
}

# AS DUAS VERSOES DO APK (export_presets.cfg). O mesmo jogo; muda a qualidade
# de fabrica (scripts/Maquina.gd, versao_do_apk):
#   LEVE      TV Box PROSB-3000 (H313, Mali-G31, 2 GB): qualidade leve
#   AVANCADA  TV Box mais forte: qualidade completa
$TodasAsVersoes = @(
    @{ Nome = "Leve"; Preset = "Lazer Shot Leve"; Arquivo = "LazerShot-Leve-PROSB3000.apk"; Rotulo = "LEVE (TV Box PROSB-3000)" },
    @{ Nome = "Avancada"; Preset = "Lazer Shot Avancada"; Arquivo = "LazerShot-Avancada.apk"; Rotulo = "AVANCADA (TV Box mais forte)" }
)
$Versoes = @($TodasAsVersoes | Where-Object { $Versao -eq "Ambas" -or $_.Nome -eq $Versao })

# adb sem cabo: conecta na TV Box pelo IP (a depuracao precisa estar ligada).
function Conectar-TvBox([string]$Adb) {
    if ($Ip -eq "") { return }
    Diz "Conectando na TV Box em $Ip ..."
    & $Adb connect $Ip
    Start-Sleep -Seconds 2
}

# Registro do Android: o que a TV Box diz quando o jogo abre (ou fecha).
function Puxar-Registro([string]$Adb) {
    $Arquivo = Join-Path $Saida "LOGCAT-TVBOX.txt"
    New-Item -ItemType Directory -Path $Saida -Force | Out-Null
    & $Adb logcat -c
    & $Adb shell am force-stop com.lazersport.lazershot
    & $Adb shell monkey -p com.lazersport.lazershot -c android.intent.category.LAUNCHER 1
    Diz "Jogo aberto na TV Box. Aguardando 60 s (nao mexa na TV Box)..."
    Start-Sleep -Seconds 60
    & $Adb logcat -d -v time -b main -b system -b crash > $Arquivo
    & $Adb shell getprop ro.product.model >> $Arquivo
    & $Adb shell getprop ro.board.platform >> $Arquivo
    & $Adb shell getprop ro.build.version.release >> $Arquivo
    & $Adb shell cat /proc/meminfo >> $Arquivo
    # caixa-preta do jogo (o que ele fazia quando parou)
    $Caixa = Join-Path $Saida "caixa_preta"
    New-Item -ItemType Directory -Path $Caixa -Force | Out-Null
    & $Adb pull /sdcard/Android/data/com.lazersport.lazershot/files/caixa_preta/. $Caixa
    Diz "Registro salvo em $Arquivo e caixa-preta em $Caixa . Envie os dois." "Green"
}

if ($Registro) {
    $SdkR = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } elseif (Test-Path "C:\AndroidSdk") { "C:\AndroidSdk" } else { Join-Path $env:LOCALAPPDATA "Android\Sdk" }
    $AdbR = Join-Path $SdkR "platform-tools\adb.exe"
    if (-not (Test-Path $AdbR)) { throw "adb nao encontrado em $AdbR." }
    Conectar-TvBox $AdbR
    if (-not ((& $AdbR devices) -match "\tdevice$")) { throw "Nenhuma TV Box no adb. Ligue a depuracao (ADB) na TV Box e rode de novo com -Ip IP-DA-TVBOX" }
    Puxar-Registro $AdbR
    Encerrar 0
}
$PastaApk = Join-Path $Projeto "APK-Pronto"
$VersaoGodot = "4.6.1"
$PastaTemplates = Join-Path $env:APPDATA "Godot\export_templates\4.6.1.stable"

Diz "LAZER SHOT - APK ANDROID 10 (versao: $Versao)" "Cyan"
Diz "Historico desta geracao: $LogCompleto"
if ($SemCamera) {
    Diz "MODO RESERVA (-SemCamera): sem o Gradle e sem o plugin da webcam." "Yellow"
    Diz "O jogo funciona inteiro, mas estes APKs NAO tiram a foto antes da partida." "Yellow"
}

# Corrige automaticamente referencias antigas que dependiam do cache UID
# da maquina onde o projeto foi criado.
$ProjectGodot = Join-Path $Projeto "project.godot"
if (-not (Test-Path $ProjectGodot)) { throw "project.godot nao encontrado nesta pasta." }
if (-not (Test-Path $PresetAndroid)) { throw "export_presets.cfg nao encontrado nesta pasta." }
$PresetTexto = [IO.File]::ReadAllText($PresetAndroid)
foreach ($V in $Versoes) {
    if ($PresetTexto -notmatch [Regex]::Escape("name=`"$($V.Preset)`"")) {
        throw "export_presets.cfg sem a versao '$($V.Preset)'. Baixe o projeto de novo (branch tvbox-ultra-pro)."
    }
}
# A WEBCAM (foto antes da partida) vem num plugin Android, e plugin so entra
# no APK pela compilacao com Gradle (Rodada 31): aqui o Gradle fica ligado.
# No modo reserva ele fica desligado so durante esta geracao (o arquivo volta
# como estava no fim).
if ($SemCamera) {
    $PresetParaVoltar = $PresetTexto
    $PresetTexto = [Regex]::Replace($PresetTexto, '(?m)^gradle_build/use_gradle_build=.*$', 'gradle_build/use_gradle_build=false')
} else {
    $PresetTexto = [Regex]::Replace($PresetTexto, '(?m)^gradle_build/use_gradle_build=.*$', 'gradle_build/use_gradle_build=true')
}
$PresetTexto = [Regex]::Replace($PresetTexto, '(?m)^gradle_build/min_sdk=.*$', 'gradle_build/min_sdk=""')
$PresetTexto = [Regex]::Replace($PresetTexto, '(?m)^gradle_build/target_sdk=.*$', 'gradle_build/target_sdk=""')
$PresetTexto = [Regex]::Replace($PresetTexto, '(?m)^package/show_in_android_tv=.*$', 'package/show_in_android_tv=false')
$PresetTexto = [Regex]::Replace($PresetTexto, '(?m)^permissions/camera=.*$', 'permissions/camera=true')
[IO.File]::WriteAllText($PresetAndroid, $PresetTexto, $Utf8)
$Config = [IO.File]::ReadAllText($ProjectGodot)
$Config = $Config.Replace('run/main_scene="uid://cnp5qquolmpd5"', 'run/main_scene="res://scenes/main.tscn"')
$Config = $Config.Replace('RankingManager="*uid://oo6ta7ci88jb"', 'RankingManager="*res://scripts/RankingManager.gd"')
$Config = $Config.Replace('TransicaoGlobal="*uid://tp1td1y7p13d"', 'TransicaoGlobal="*res://scripts/TransiaoGlobal.gd"')
$Config = $Config.Replace('MiraGlobal="*uid://bp7dd0c721pie"', 'MiraGlobal="*res://scripts/MiraGlobal.gd"')
$Config = [Regex]::Replace($Config, '(?m)^tela/giro=.*$', "tela/giro=$Giro")
# Mira da arma no sentido do monitor em pe (padrao) ou girada com o HDMI.
$Config = [Regex]::Replace($Config, '(?m)^tela/mira_direta=.*$', "tela/mira_direta=$(if ($MiraGirada) { 'false' } else { 'true' })")
[IO.File]::WriteAllText($ProjectGodot, $Config, $Utf8)
Diz "Giro da tela: $Giro"
Diz "Mira: $(if ($MiraGirada) { 'girada com o HDMI' } else { 'direta (monitor em pe)' })"

$PluginWebcam = Join-Path $Projeto "tools\webcam_android\PunchUsbSerial-release.aar"
if (-not $SemCamera -and -not (Test-Path $PluginWebcam)) {
    throw "Falta o plugin da webcam em tools\webcam_android. Baixe o projeto de novo (branch tvbox-ultra-pro)."
}

$NomesGodot = @(
    "Godot_v4.6.1-stable_win64_console.exe",
    "Godot_v4.6.1-stable_win64.exe"
)
$PastasBusca = @($Projeto, "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop")
Diz "Procurando o Godot 4.6.1 (pasta do projeto, Downloads e Area de Trabalho)..."
$Godot = $null
foreach ($Pasta in $PastasBusca) {
    if (-not (Test-Path $Pasta)) { continue }
    foreach ($Nome in $NomesGodot) {
        $Godot = Get-ChildItem $Pasta -Recurse -File -Filter $Nome -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($Godot) { break }
    }
    if ($Godot) { break }
}
if (-not $Godot) {
    throw "Godot 4.6.1 nao encontrado. Extraia o ZIP completo do Godot 4.6.1 em Downloads."
}
Diz "Godot: $($Godot.FullName)"

$Sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } elseif (Test-Path "C:\AndroidSdk") { "C:\AndroidSdk" } elseif (Test-Path (Join-Path $env:LOCALAPPDATA "Android\Sdk")) { Join-Path $env:LOCALAPPDATA "Android\Sdk" } else { $null }
if (-not $Sdk -or -not (Test-Path (Join-Path $Sdk "platform-tools\adb.exe"))) {
    throw "Android SDK nao encontrado. Instale-o em C:\AndroidSdk ou defina ANDROID_HOME."
}
$env:ANDROID_HOME = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk

# O editor Godot le Java e Android SDK de editor_settings-4.6.tres.
# JAVA_HOME sozinho nao corrige uma configuracao antiga/corrompida.
$Jdks = New-Object System.Collections.Generic.List[string]
if ($env:JAVA_HOME) { $Jdks.Add($env:JAVA_HOME) }
$Javac = Get-Command javac.exe -ErrorAction SilentlyContinue
if ($Javac) { $Jdks.Add((Split-Path (Split-Path $Javac.Source -Parent) -Parent)) }
foreach ($Base in @("$env:ProgramFiles\Eclipse Adoptium", "$env:ProgramFiles\Java", "$env:ProgramFiles\Microsoft", "$env:ProgramFiles\Amazon Corretto", "C:\Program Files\Eclipse Adoptium")) {
    if (Test-Path $Base) {
        Get-ChildItem -LiteralPath $Base -Directory -ErrorAction SilentlyContinue | ForEach-Object { $Jdks.Add($_.FullName) }
    }
}
$JavaSdk = $null
foreach ($Candidato in ($Jdks | Select-Object -Unique)) {
    $JavaExe = Join-Path $Candidato "bin\java.exe"
    $JavacExe = Join-Path $Candidato "bin\javac.exe"
    if (-not (Test-Path $JavaExe) -or -not (Test-Path $JavacExe)) { continue }
    $InicioJava = New-Object System.Diagnostics.ProcessStartInfo
    $InicioJava.FileName = $JavaExe
    $InicioJava.Arguments = '-version'
    $InicioJava.UseShellExecute = $false
    $InicioJava.RedirectStandardError = $true
    $InicioJava.RedirectStandardOutput = $true
    try {
        $ProcessoJava = [System.Diagnostics.Process]::Start($InicioJava)
        $VersaoJava = $ProcessoJava.StandardError.ReadToEnd() + "`n" + $ProcessoJava.StandardOutput.ReadToEnd()
        $ProcessoJava.WaitForExit()
    } catch { continue }
    if ($VersaoJava -match '(?:version\s+|openjdk\s+)"?17(?:[.\s"]|$)') {
        $JavaSdk = (Resolve-Path -LiteralPath $Candidato).Path
        break
    }
}
if (-not $JavaSdk) {
    throw "JDK 17 nao encontrado. Instale OpenJDK 17 (com javac.exe), defina JAVA_HOME para a pasta do JDK e execute o BAT novamente."
}
$env:JAVA_HOME = $JavaSdk
Diz "JDK 17: $JavaSdk"
Diz "Android SDK: $Sdk"

$ConfiguracoesEditor = Join-Path $env:APPDATA "Godot\editor_settings-4.6.tres"
New-Item -ItemType Directory -Path (Split-Path $ConfiguracoesEditor -Parent) -Force | Out-Null
$ConfigEditor = if (Test-Path $ConfiguracoesEditor) { [IO.File]::ReadAllText($ConfiguracoesEditor) } else { "" }
if ($ConfigEditor -and -not $ConfigEditor.TrimStart().StartsWith('[gd_resource type="EditorSettings"')) {
    $BackupEditor = "$ConfiguracoesEditor.backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item -LiteralPath $ConfiguracoesEditor -Destination $BackupEditor
    Diz "Configuracao Godot invalida preservada em $BackupEditor"
    $ConfigEditor = ""
}
if (-not $ConfigEditor) { $ConfigEditor = "[gd_resource type=`"EditorSettings`" format=3]`r`n`r`n[resource]`r`n" }
$EntradasAndroid = @{
    'export/android/java_sdk_path' = $JavaSdk.Replace('\', '/')
    'export/android/android_sdk_path' = $Sdk.Replace('\', '/')
}
foreach ($Chave in $EntradasAndroid.Keys) {
    $Valor = $EntradasAndroid[$Chave].Replace('"', '\"')
    $Linha = "$Chave = `"$Valor`""
    if ($ConfigEditor -match "(?m)^$Chave\s*=") {
        $ConfigEditor = [Regex]::Replace($ConfigEditor, "(?m)^$Chave\s*=.*$", $Linha)
    } else {
        $ConfigEditor = [Regex]::Replace($ConfigEditor, '(?m)^\[resource\]\s*$', "[resource]`r`n$Linha")
    }
}
[IO.File]::WriteAllText($ConfiguracoesEditor, $ConfigEditor, $Utf8)

# Os Export Templates, agora com o modelo Android (android_source.zip): a
# compilacao com Gradle parte dele.
if (-not (Test-Path (Join-Path $PastaTemplates "android_release.apk")) -or
    -not (Test-Path (Join-Path $PastaTemplates "android_source.zip"))) {
    Diz "[1/4] Baixando e instalando Export Templates 4.6.1 (primeira vez: cerca de 1,2 GB)..." "Cyan"
    $Temporaria = Join-Path $env:TEMP "lazer-shot-godot-templates"
    New-Item -ItemType Directory -Path $Temporaria -Force | Out-Null
    $Zip = Join-Path $Temporaria "templates.zip"
    $Extraido = Join-Path $Temporaria "extraido"
    $Url = "https://github.com/godotengine/godot-builds/releases/download/4.6.1-stable/Godot_v4.6.1-stable_export_templates.tpz"
    if (Test-Path $Zip) { Remove-Item -LiteralPath $Zip -Force }
    $Curl = if ($env:SystemRoot) { Join-Path $env:SystemRoot "System32\curl.exe" } else { "" }
    if ($Curl -and (Test-Path -LiteralPath $Curl)) {
        $AvisoDownload = { if (Test-Path -LiteralPath $Zip) { "{0:N0} MB baixados." -f ((Get-Item -LiteralPath $Zip).Length / 1MB) } else { "Conectando..." } }
        $Codigo = Rodar $Curl ("-L -sS --fail --retry 3 --output " + (Aspas $Zip) + " " + (Aspas $Url)) "" 90 $AvisoDownload 15
        if ($Codigo -ne 0) { throw "Nao consegui baixar os Export Templates (curl, codigo $Codigo). Confira a internet e rode de novo." }
    } else {
        Diz "      (baixando sem barra de andamento; aguarde)"
        Invoke-WebRequest -Uri $Url -OutFile $Zip -UseBasicParsing
    }
    Diz "      Descompactando..."
    if (Test-Path $Extraido) { Remove-Item -LiteralPath $Extraido -Recurse -Force }
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Zip, $Extraido)
    $Origem = Join-Path $Extraido "templates"
    if (-not (Test-Path (Join-Path $Origem "android_release.apk")) -or -not (Test-Path (Join-Path $Origem "android_source.zip"))) {
        throw "Pacote de Export Templates invalido ou incompleto."
    }
    New-Item -ItemType Directory -Path $PastaTemplates -Force | Out-Null
    Copy-Item -Path (Join-Path $Origem "*") -Destination $PastaTemplates -Recurse -Force
    # o pacote baixado (mais de 1 GB) nao precisa ficar ocupando o disco
    Remove-Item -LiteralPath $Temporaria -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Diz "[1/4] Export Templates 4.6.1 confirmados." "Cyan"
}

# O MODELO ANDROID DO PROJETO (android\build): o que o botao "Instalar modelo
# de compilacao Android" do editor faz, sem abrir o editor. Refeito quando
# falta ou e de outra versao do Godot. (O modo reserva nao usa.)
$PastaAndroid = Join-Path $Projeto "android"
$PastaModelo = Join-Path $PastaAndroid "build"
if ($SemCamera) {
    Diz "[2/4] Modelo Android: nao precisa no modo reserva." "Cyan"
} else {
    $VersaoModelo = ([IO.File]::ReadAllText((Join-Path $PastaTemplates "version.txt"))).Trim()
    $ArquivoVersaoModelo = Join-Path $PastaAndroid ".build_version"
    $VersaoInstalada = if (Test-Path $ArquivoVersaoModelo) { ([IO.File]::ReadAllText($ArquivoVersaoModelo)).Trim() } else { "" }
    $BuildGradle = Join-Path $PastaModelo "build.gradle"
    if (($VersaoInstalada -ne $VersaoModelo) -or -not (Test-Path $BuildGradle)) {
        Diz "[2/4] Instalando o modelo Android $VersaoModelo em android\build..." "Cyan"
        if (Test-Path $PastaModelo) { Remove-Item -LiteralPath $PastaModelo -Recurse -Force }
        New-Item -ItemType Directory -Path $PastaModelo -Force | Out-Null
        [System.IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $PastaTemplates "android_source.zip"), $PastaModelo)
        if (-not (Test-Path $BuildGradle)) { throw "android_source.zip foi extraido, mas android\build\build.gradle nao apareceu." }
        [IO.File]::WriteAllText($ArquivoVersaoModelo, $VersaoModelo, $Utf8)
        # o Godot nao deve importar nada desta pasta (e o que o editor tambem faz)
        [IO.File]::WriteAllText((Join-Path $PastaModelo ".gdignore"), "", $Utf8)
    } else {
        Diz "[2/4] Modelo Android $VersaoModelo confirmado." "Cyan"
    }

    # A WEBCAM ENTRA NO APK POR AQUI, e nao pelo project.godot: o plugin
    # PunchUsbSerial (o mesmo do Super Boxing, em tools\webcam_android) e as
    # bibliotecas dele vao no build.gradle do modelo. O POM antigo do AUSBC
    # aponta para dois artefatos opcionais do JCenter (que nao existe mais) e
    # que a captura da webcam nao usa: ficam de fora.
    $MarcadorWebcam = "LAZER_SHOT_WEBCAM_V1"
    $GradleTexto = [IO.File]::ReadAllText($BuildGradle)
    if ($GradleTexto -notmatch $MarcadorWebcam) {
        $BlocoWebcam = @'

// LAZER_SHOT_WEBCAM_V1 (posto pelo GERAR_APK_PRO_ULTRA.ps1)
// A webcam da foto antes da partida: o plugin PunchUsbSerial
// (tools/webcam_android) e as bibliotecas dele.
repositories {
    maven { url "https://jitpack.io" }
}
dependencies {
    implementation files("../../tools/webcam_android/PunchUsbSerial-release.aar")
    implementation "com.github.mik3y:usb-serial-for-android:3.11.0"
    implementation "com.github.jiangdongguo.AndroidUSBCamera:libausbc:3.2.7"
    implementation "com.github.jiangdongguo.AndroidUSBCamera:libuvc:3.2.7"
}
configurations.configureEach {
    exclude group: "com.gyf.immersionbar", module: "immersionbar"
    exclude group: "com.zlc.glide", module: "webpdecoder"
}
subprojects {
    configurations.configureEach {
        exclude group: "com.gyf.immersionbar", module: "immersionbar"
        exclude group: "com.zlc.glide", module: "webpdecoder"
    }
}
'@
        [IO.File]::WriteAllText($BuildGradle, $GradleTexto.TrimEnd() + "`r`n" + $BlocoWebcam.Replace("`r`n", "`n").Replace("`n", "`r`n"), $Utf8)
        Diz "      Webcam (plugin PunchUsbSerial) ligada no modelo Android."
    }
}

# APK RELEASE assinado com a chave debug local do Godot (a mesma de antes:
# o APK novo instala por cima do antigo sem apagar ranking e configuracao).
$Keystore = Join-Path $env:APPDATA "Godot\keystores\debug.keystore"
if (-not (Test-Path $Keystore)) {
    $Keytool = $null
    if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME "bin\keytool.exe"))) { $Keytool = Join-Path $env:JAVA_HOME "bin\keytool.exe" }
    elseif (Get-Command keytool -ErrorAction SilentlyContinue) { $Keytool = (Get-Command keytool).Source }
    if (-not $Keytool) { throw "Chave debug.keystore nao encontrada. Abra o Godot 4.6.1 uma vez (ele cria a chave) ou instale o JDK 17." }
    New-Item -ItemType Directory -Path (Split-Path $Keystore) -Force | Out-Null
    $Codigo = Rodar $Keytool ("-genkeypair -v -keystore " + (Aspas $Keystore) + " -storepass android -keypass android -alias androiddebugkey -dname " + (Aspas "CN=Android Debug,O=Android,C=US") + " -keyalg RSA -keysize 2048 -validity 9999") "" 5 ""
    if ($Codigo -ne 0 -or -not (Test-Path $Keystore)) { throw "Nao consegui criar a chave debug.keystore (keytool, codigo $Codigo)." }
}
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $Keystore
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "androiddebugkey"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = "android"

if (-not $SemCamera) {
    # SEM O GRADLE EM SEGUNDO PLANO (daemon): cada APK usa um Gradle so dele,
    # que termina junto com a compilacao, devolve a memoria e nao prende
    # arquivos desta pasta.
    if ("$env:GRADLE_OPTS" -notmatch 'org\.gradle\.daemon=') {
        $env:GRADLE_OPTS = ("$env:GRADLE_OPTS -Dorg.gradle.daemon=false").Trim()
    }
    # O Gradle que as geracoes da 1.31.0 deixaram rodando (ate 3 horas) ainda
    # pode estar segurando arquivos: encerra antes de comecar.
    $Gradlew = Join-Path $PastaModelo "gradlew.bat"
    $PropriedadesGradle = Join-Path $PastaModelo "gradle\wrapper\gradle-wrapper.properties"
    if ($env:ComSpec -and (Test-Path $Gradlew) -and (Test-Path $PropriedadesGradle)) {
        $CasaGradle = if ($env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME } else { Join-Path $env:USERPROFILE ".gradle" }
        if ([IO.File]::ReadAllText($PropriedadesGradle) -match 'distributionUrl=.*/(gradle-[^/]+?)\.zip') {
            if (Test-Path (Join-Path $CasaGradle ("wrapper\dists\" + $Matches[1]))) {
                Diz "      Encerrando o Gradle que ficou rodando de geracoes anteriores..."
                [void](Rodar $env:ComSpec ('/d /s /c "' + (Aspas $Gradlew) + ' --stop"') "" 2 "")
            }
        }
    }
}

Diz "[3/4] Preparando pasta de saida..." "Cyan"
New-Item -ItemType Directory -Path $PastaApk -Force | Out-Null
# APK-Pronto fica vazia antes de cada geracao: no fim ela tem so os APKs.
Get-ChildItem -LiteralPath $PastaApk -Force | Remove-Item -Recurse -Force
Get-ChildItem -LiteralPath $Saida -File -Filter "*.apk*" -ErrorAction SilentlyContinue | Remove-Item -Force

$Gerados = @()
foreach ($V in $Versoes) {
    $Arquivo = if ($SemCamera) { $V.Arquivo.Replace(".apk", "-SEM-CAMERA.apk") } else { $V.Arquivo }
    $Aviso = if ($SemCamera) { "O Godot esta montando o APK." } else { "O Gradle compila sem mostrar nada; na primeira vez ele baixa as bibliotecas do Android e demora mais." }
    Diz ""
    Diz "[4/4] Exportando a versao $($V.Rotulo)$(if ($SemCamera) { ' SEM CAMERA' })..." "Cyan"
    # Nao cria uma sessao --editor --import separada: no Windows do usuario
    # essa sessao termina em 0xC0000005 durante a importacao de fontes.
    # O proprio exportador do Godot prepara os recursos necessarios.
    $ApkExportado = Join-Path $Saida $Arquivo
    $Log = Join-Path $Saida ("exportacao-godot-" + $V.Nome + ".log")
    $ErrosAntigo = Join-Path $Saida ("exportacao-godot-" + $V.Nome + "-erros.log")
    if (Test-Path $ErrosAntigo) { Remove-Item -LiteralPath $ErrosAntigo -Force -ErrorAction SilentlyContinue }
    try { if (Test-Path $Log) { Remove-Item -LiteralPath $Log -Force } } catch {
        $Log = Join-Path $Saida ("exportacao-godot-" + $V.Nome + "-" + (Get-Date -Format "HHmmss") + ".log")
    }
    $Argumentos = (@("--headless", "--path", $Projeto, "--export-release", $V.Preset, $ApkExportado) | ForEach-Object { Aspas $_ }) -join " "
    $InicioVersao = $Relogio.Elapsed.TotalSeconds
    $Tentativa = 0
    while ($true) {
        $Tentativa++
        if (Test-Path $ApkExportado) { Remove-Item -LiteralPath $ApkExportado -Force }
        $Codigo = Rodar $Godot.FullName $Argumentos $Log 60 $Aviso
        if ($EstourouTempo) {
            throw "A exportacao da versao $($V.Nome) passou de 60 minutos e foi encerrada. Envie o historico."
        }
        # 0xC0000005 e parecidos: o Godot fechou sozinho (no Windows do
        # usuario ja aconteceu na importacao). Uma segunda vez costuma passar.
        $Caiu = ($Codigo -lt 0 -or $Codigo -gt 255)
        if ($Caiu -and -not (Test-Path $ApkExportado) -and $Tentativa -lt 2) {
            Diz ("O Godot fechou sozinho no meio (codigo {0}). Tentando mais uma vez..." -f $Codigo) "Yellow"
            continue
        }
        break
    }

    $TextoLog = if (Test-Path $Log) { [IO.File]::ReadAllText($Log) } else { "" }
    if ($TextoLog -match "SCRIPT ERROR: Parse Error|Failed to load script|Failed to create an autoload") {
        throw "Existe erro de sintaxe em um script Godot. Consulte $Log."
    }
    if ($Codigo -ne 0 -or -not (Test-Path $ApkExportado)) {
        Dar-Dica $TextoLog
        if ($Caiu) {
            Diz ("DICA: o Godot fechou sozinho duas vezes (codigo {0}). Feche os programas pesados deste PC e rode de novo." -f $Codigo) "Yellow"
        }
        if (-not $SemCamera) {
            Diz "Para testar o jogo agora, sem a foto antes da partida: GERAR_APK_SEM_CAMERA.bat" "Yellow"
        }
        if ($Codigo -ne 0) { throw "Falha na exportacao da versao $($V.Nome) (codigo $Codigo). A causa esta nas linhas acima (e em $Log)." }
        throw "O APK da versao $($V.Nome) nao foi criado. A causa esta nas linhas acima (e em $Log)."
    }
    $Apk = Join-Path $PastaApk $Arquivo
    Copy-Item -LiteralPath $ApkExportado -Destination $Apk -Force
    $Tamanho = (Get-Item $Apk).Length
    if ($Tamanho -lt 1MB) { throw "O APK da versao $($V.Nome) foi criado incompleto (menos de 1 MB)." }

    # CONFERE O QUE VAI PARA A TV BOX: o motor (ARM 32 e 64 bits) e o plugin
    # da webcam dentro do APK.
    $ZipApk = [System.IO.Compression.ZipFile]::OpenRead($Apk)
    try {
        $Nomes = $ZipApk.Entries | ForEach-Object { $_.FullName }
        foreach ($Lib in @("lib/armeabi-v7a/libgodot_android.so", "lib/arm64-v8a/libgodot_android.so")) {
            if ($Nomes -notcontains $Lib) { throw "O APK da versao $($V.Nome) saiu sem $Lib." }
        }
        if (-not $SemCamera) {
            $Dexes = ""
            foreach ($Dex in ($ZipApk.Entries | Where-Object { $_.FullName -match '^classes\d*\.dex$' })) {
                $Leitor = New-Object System.IO.StreamReader($Dex.Open(), [System.Text.Encoding]::GetEncoding(28591))
                $Dexes += $Leitor.ReadToEnd()
                $Leitor.Close()
            }
            if (-not $Dexes.Contains("Lcom/lazersport/punch/usbserial/GodotAndroidPlugin;")) {
                throw "O APK da versao $($V.Nome) saiu SEM o plugin da webcam (a foto antes da partida nao funcionaria)."
            }
        }
    } finally {
        $ZipApk.Dispose()
    }
    $Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Apk).Hash
    Diz ("Versao {0}: {1} ({2:N2} MB) em {3}" -f $V.Rotulo, $Apk, ($Tamanho / 1MB), (Tempo ($Relogio.Elapsed.TotalSeconds - $InicioVersao))) "Green"
    Diz "SHA256: $Hash"
    $Gerados += $Apk
}
# Garante: nada alem dos APKs na pasta de entrega.
Get-ChildItem -LiteralPath $PastaApk -Force | Where-Object { $Gerados -notcontains $_.FullName } | Remove-Item -Recurse -Force

Diz ""
Diz ("APK GERADO COM SUCESSO em {0}" -f (Tempo $Relogio.Elapsed.TotalSeconds)) "Green"
foreach ($A in $Gerados) { Diz "  $A" }
Diz "LEVE: TV Box PROSB-3000. AVANCADA: TV Box mais forte. As duas instalam por cima da versao anterior."
if ($SemCamera) {
    Diz "MODO RESERVA: estes APKs NAO tiram a foto antes da partida. Para a foto, gere com GERAR_APK_PRO_ULTRA.bat." "Yellow"
}
Diz "O jogo gira internamente; mantenha o HDMI em landscape."

if ($Instalar) {
    $Adb = Join-Path $Sdk "platform-tools\adb.exe"
    Conectar-TvBox $Adb
    & $Adb install -r $Gerados[0]
    Puxar-Registro $Adb
}
Encerrar 0
