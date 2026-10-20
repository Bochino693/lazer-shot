param(
    # 1 = topo do jogo na esquerda do HDMI, -1 = na direita, 0 = sem giro
    [ValidateSet(1, -1, 0)][int]$Giro = 1,
    # A mira anda de lado quando a arma sobe? Gere de novo com -MiraGirada.
    [switch]$MiraGirada,
    # Qual APK gerar (Rodada 31): as duas versoes (padrao), so a LEVE (TV Box
    # PROSB-3000, a mais fraca) ou so a AVANCADA (TV Box mais forte).
    [ValidateSet("Ambas", "Leve", "Avancada")][string]$Versao = "Ambas",
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
$Projeto = $PSScriptRoot
$Saida = Join-Path $Projeto "build\android"

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
    Write-Host "Conectando na TV Box em $Ip ..."
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
    Write-Host "Jogo aberto na TV Box. Aguardando 60 s (nao mexa na TV Box)..."
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
    Write-Host "Registro salvo em $Arquivo e caixa-preta em $Caixa . Envie os dois." -ForegroundColor Green
}

if ($Registro) {
    $SdkR = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } elseif (Test-Path "C:\AndroidSdk") { "C:\AndroidSdk" } else { Join-Path $env:LOCALAPPDATA "Android\Sdk" }
    $AdbR = Join-Path $SdkR "platform-tools\adb.exe"
    if (-not (Test-Path $AdbR)) { throw "adb nao encontrado em $AdbR." }
    Conectar-TvBox $AdbR
    if (-not ((& $AdbR devices) -match "\tdevice$")) { throw "Nenhuma TV Box no adb. Ligue a depuracao (ADB) na TV Box e rode de novo com -Ip IP-DA-TVBOX" }
    Puxar-Registro $AdbR
    exit 0
}
$PastaApk = Join-Path $Projeto "APK-Pronto"
$VersaoGodot = "4.6.1"
$PastaTemplates = Join-Path $env:APPDATA "Godot\export_templates\4.6.1.stable"

Write-Host "LAZER SHOT - APK ANDROID 10 (versao: $Versao)" -ForegroundColor Cyan

# Corrige automaticamente referencias antigas que dependiam do cache UID
# da maquina onde o projeto foi criado.
$ProjectGodot = Join-Path $Projeto "project.godot"
if (-not (Test-Path $ProjectGodot)) { throw "project.godot nao encontrado nesta pasta." }
$PresetAndroid = Join-Path $Projeto "export_presets.cfg"
if (-not (Test-Path $PresetAndroid)) { throw "export_presets.cfg nao encontrado nesta pasta." }
$PresetTexto = [IO.File]::ReadAllText($PresetAndroid)
foreach ($V in $Versoes) {
    if ($PresetTexto -notmatch [Regex]::Escape("name=`"$($V.Preset)`"")) {
        throw "export_presets.cfg sem a versao '$($V.Preset)'. Baixe o projeto de novo (branch tvbox-ultra-pro)."
    }
}
# A WEBCAM (foto antes da partida) vem num plugin Android, e plugin so entra
# no APK pela compilacao com Gradle (Rodada 31). Antes esta parte desligava o
# Gradle; agora ela garante que ele esta ligado.
$PresetTexto = [Regex]::Replace($PresetTexto, '(?m)^gradle_build/use_gradle_build=.*$', 'gradle_build/use_gradle_build=true')
$PresetTexto = [Regex]::Replace($PresetTexto, '(?m)^gradle_build/min_sdk=.*$', 'gradle_build/min_sdk=""')
$PresetTexto = [Regex]::Replace($PresetTexto, '(?m)^gradle_build/target_sdk=.*$', 'gradle_build/target_sdk=""')
$PresetTexto = [Regex]::Replace($PresetTexto, '(?m)^package/show_in_android_tv=.*$', 'package/show_in_android_tv=false')
$PresetTexto = [Regex]::Replace($PresetTexto, '(?m)^permissions/camera=.*$', 'permissions/camera=true')
[IO.File]::WriteAllText($PresetAndroid, $PresetTexto, [Text.UTF8Encoding]::new($false))
$Config = [IO.File]::ReadAllText($ProjectGodot)
$Config = $Config.Replace('run/main_scene="uid://cnp5qquolmpd5"', 'run/main_scene="res://scenes/main.tscn"')
$Config = $Config.Replace('RankingManager="*uid://oo6ta7ci88jb"', 'RankingManager="*res://scripts/RankingManager.gd"')
$Config = $Config.Replace('TransicaoGlobal="*uid://tp1td1y7p13d"', 'TransicaoGlobal="*res://scripts/TransiaoGlobal.gd"')
$Config = $Config.Replace('MiraGlobal="*uid://bp7dd0c721pie"', 'MiraGlobal="*res://scripts/MiraGlobal.gd"')
$Config = [Regex]::Replace($Config, '(?m)^tela/giro=.*$', "tela/giro=$Giro")
# Mira da arma no sentido do monitor em pe (padrao) ou girada com o HDMI.
$Config = [Regex]::Replace($Config, '(?m)^tela/mira_direta=.*$', "tela/mira_direta=$(if ($MiraGirada) { 'false' } else { 'true' })")
[IO.File]::WriteAllText($ProjectGodot, $Config, [Text.UTF8Encoding]::new($false))
Write-Host "Giro da tela: $Giro"
Write-Host "Mira: $(if ($MiraGirada) { 'girada com o HDMI' } else { 'direta (monitor em pe)' })"

$PluginWebcam = Join-Path $Projeto "tools\webcam_android\PunchUsbSerial-release.aar"
if (-not (Test-Path $PluginWebcam)) {
    throw "Falta o plugin da webcam em tools\webcam_android. Baixe o projeto de novo (branch tvbox-ultra-pro)."
}

$NomesGodot = @(
    "Godot_v4.6.1-stable_win64_console.exe",
    "Godot_v4.6.1-stable_win64.exe"
)
$PastasBusca = @($Projeto, "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop")
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
Write-Host "JDK 17: $JavaSdk"
Write-Host "Android SDK: $Sdk"

$ConfiguracoesEditor = Join-Path $env:APPDATA "Godot\editor_settings-4.6.tres"
New-Item -ItemType Directory -Path (Split-Path $ConfiguracoesEditor -Parent) -Force | Out-Null
$ConfigEditor = if (Test-Path $ConfiguracoesEditor) { [IO.File]::ReadAllText($ConfiguracoesEditor) } else { "" }
if ($ConfigEditor -and -not $ConfigEditor.TrimStart().StartsWith('[gd_resource type="EditorSettings"')) {
    $BackupEditor = "$ConfiguracoesEditor.backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item -LiteralPath $ConfiguracoesEditor -Destination $BackupEditor
    Write-Host "Configuracao Godot invalida preservada em $BackupEditor"
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
[IO.File]::WriteAllText($ConfiguracoesEditor, $ConfigEditor, [Text.UTF8Encoding]::new($false))

# Os Export Templates, agora com o modelo Android (android_source.zip): a
# compilacao com Gradle parte dele.
if (-not (Test-Path (Join-Path $PastaTemplates "android_release.apk")) -or
    -not (Test-Path (Join-Path $PastaTemplates "android_source.zip"))) {
    Write-Host "[1/4] Baixando e instalando Export Templates 4.6.1 (primeira vez: download grande)..."
    $Temporaria = Join-Path $env:TEMP "lazer-shot-godot-templates"
    New-Item -ItemType Directory -Path $Temporaria -Force | Out-Null
    $Zip = Join-Path $Temporaria "templates.zip"
    $Extraido = Join-Path $Temporaria "extraido"
    $Url = "https://github.com/godotengine/godot-builds/releases/download/4.6.1-stable/Godot_v4.6.1-stable_export_templates.tpz"
    Invoke-WebRequest -Uri $Url -OutFile $Zip -UseBasicParsing
    if (Test-Path $Extraido) { Remove-Item -LiteralPath $Extraido -Recurse -Force }
    Expand-Archive -LiteralPath $Zip -DestinationPath $Extraido -Force
    $Origem = Join-Path $Extraido "templates"
    if (-not (Test-Path (Join-Path $Origem "android_release.apk")) -or -not (Test-Path (Join-Path $Origem "android_source.zip"))) {
        throw "Pacote de Export Templates invalido ou incompleto."
    }
    New-Item -ItemType Directory -Path $PastaTemplates -Force | Out-Null
    Copy-Item -Path (Join-Path $Origem "*") -Destination $PastaTemplates -Recurse -Force
    # o pacote baixado (mais de 1 GB) nao precisa ficar ocupando o disco
    Remove-Item -LiteralPath $Temporaria -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "[1/4] Export Templates 4.6.1 confirmados."
}

# O MODELO ANDROID DO PROJETO (android\build): o que o botao "Instalar modelo
# de compilacao Android" do editor faz, sem abrir o editor. Refeito quando
# falta ou e de outra versao do Godot.
$PastaAndroid = Join-Path $Projeto "android"
$PastaModelo = Join-Path $PastaAndroid "build"
$VersaoModelo = ([IO.File]::ReadAllText((Join-Path $PastaTemplates "version.txt"))).Trim()
$ArquivoVersaoModelo = Join-Path $PastaAndroid ".build_version"
$VersaoInstalada = if (Test-Path $ArquivoVersaoModelo) { ([IO.File]::ReadAllText($ArquivoVersaoModelo)).Trim() } else { "" }
$BuildGradle = Join-Path $PastaModelo "build.gradle"
if (($VersaoInstalada -ne $VersaoModelo) -or -not (Test-Path $BuildGradle)) {
    Write-Host "[2/4] Instalando o modelo Android $VersaoModelo em android\build..."
    if (Test-Path $PastaModelo) { Remove-Item -LiteralPath $PastaModelo -Recurse -Force }
    New-Item -ItemType Directory -Path $PastaModelo -Force | Out-Null
    Expand-Archive -LiteralPath (Join-Path $PastaTemplates "android_source.zip") -DestinationPath $PastaModelo -Force
    if (-not (Test-Path $BuildGradle)) { throw "android_source.zip foi extraido, mas android\build\build.gradle nao apareceu." }
    [IO.File]::WriteAllText($ArquivoVersaoModelo, $VersaoModelo, [Text.UTF8Encoding]::new($false))
    # o Godot nao deve importar nada desta pasta (e o que o editor tambem faz)
    [IO.File]::WriteAllText((Join-Path $PastaModelo ".gdignore"), "", [Text.UTF8Encoding]::new($false))
} else {
    Write-Host "[2/4] Modelo Android $VersaoModelo confirmado."
}

# A WEBCAM ENTRA NO APK POR AQUI, e nao pelo project.godot: o plugin
# PunchUsbSerial (o mesmo do Super Boxing, em tools\webcam_android) e as
# bibliotecas dele vao no build.gradle do modelo. O POM antigo do AUSBC aponta
# para dois artefatos opcionais do JCenter (que nao existe mais) e que a
# captura da webcam nao usa: ficam de fora.
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
    [IO.File]::WriteAllText($BuildGradle, $GradleTexto.TrimEnd() + "`r`n" + $BlocoWebcam.Replace("`r`n", "`n").Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
    Write-Host "      Webcam (plugin PunchUsbSerial) ligada no modelo Android."
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
    & $Keytool -genkeypair -v -keystore $Keystore -storepass android -keypass android -alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" -keyalg RSA -keysize 2048 -validity 9999
}
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $Keystore
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "androiddebugkey"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = "android"

Write-Host "[3/4] Preparando pasta de saida..."
New-Item -ItemType Directory -Path $Saida -Force | Out-Null
New-Item -ItemType Directory -Path $PastaApk -Force | Out-Null
# APK-Pronto fica vazia antes de cada geracao: no fim ela tem so os APKs.
Get-ChildItem -LiteralPath $PastaApk -Force | Remove-Item -Recurse -Force
Get-ChildItem -LiteralPath $Saida -File -Filter "*.apk*" -ErrorAction SilentlyContinue | Remove-Item -Force

Add-Type -AssemblyName System.IO.Compression.FileSystem
$Gerados = @()
foreach ($V in $Versoes) {
    Write-Host "[4/4] Exportando a versao $($V.Rotulo) (Gradle: alguns minutos)..." -ForegroundColor Cyan
    # Nao cria uma sessao --editor --import separada: no Windows do usuario
    # essa sessao termina em 0xC0000005 durante a importacao de fontes.
    # O proprio exportador do Godot prepara os recursos necessarios.
    $ApkExportado = Join-Path $Saida $V.Arquivo
    $Log = Join-Path $Saida ("exportacao-godot-" + $V.Nome + ".log")
    $ErrosLog = Join-Path $Saida ("exportacao-godot-" + $V.Nome + "-erros.log")
    if (Test-Path $Log) { Remove-Item -LiteralPath $Log -Force }
    if (Test-Path $ErrosLog) { Remove-Item -LiteralPath $ErrosLog -Force }

    $Argumentos = "--headless --path `"$Projeto`" --export-release `"$($V.Preset)`" `"$ApkExportado`""
    $Processo = Start-Process -FilePath $Godot.FullName -ArgumentList $Argumentos -NoNewWindow -Wait -PassThru -RedirectStandardOutput $Log -RedirectStandardError $ErrosLog

    if (Test-Path $Log) { Get-Content -LiteralPath $Log -Encoding UTF8 }
    if (Test-Path $ErrosLog) { Get-Content -LiteralPath $ErrosLog -Encoding UTF8 }

    $TextoLog = ""
    if (Test-Path $Log) { $TextoLog += [IO.File]::ReadAllText($Log) }
    if (Test-Path $ErrosLog) { $TextoLog += "`n" + [IO.File]::ReadAllText($ErrosLog) }
    if ($TextoLog -match "SCRIPT ERROR: Parse Error|Failed to load script|Failed to create an autoload") {
        throw "Existe erro de sintaxe em um script Godot. Consulte $Log."
    }
    if ($TextoLog -match "Could not resolve|Could not GET|Could not HEAD|UnknownHost|Connection refused|timed out") {
        Write-Host "O Gradle nao conseguiu baixar uma biblioteca: confira a internet deste PC e rode de novo." -ForegroundColor Yellow
    }
    if ($Processo.ExitCode -ne 0) { throw "Falha na exportacao da versao $($V.Nome); consulte $Log e $ErrosLog. Codigo: $($Processo.ExitCode)" }
    if (-not (Test-Path $ApkExportado)) {
        throw "O APK da versao $($V.Nome) nao foi criado. Consulte $Log. Codigo do Godot: $($Processo.ExitCode)"
    }
    $Apk = Join-Path $PastaApk $V.Arquivo
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
        $Dexes = ""
        foreach ($Dex in ($ZipApk.Entries | Where-Object { $_.FullName -match '^classes\d*\.dex$' })) {
            $Leitor = New-Object System.IO.StreamReader($Dex.Open(), [System.Text.Encoding]::GetEncoding(28591))
            $Dexes += $Leitor.ReadToEnd()
            $Leitor.Close()
        }
        if (-not $Dexes.Contains("Lcom/lazersport/punch/usbserial/GodotAndroidPlugin;")) {
            throw "O APK da versao $($V.Nome) saiu SEM o plugin da webcam (a foto antes da partida nao funcionaria)."
        }
    } finally {
        $ZipApk.Dispose()
    }
    $Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Apk).Hash
    Write-Host ("Versao {0}: {1} ({2:N2} MB)" -f $V.Rotulo, $Apk, ($Tamanho / 1MB)) -ForegroundColor Green
    Write-Host "SHA256: $Hash"
    $Gerados += $Apk
}
# Garante: nada alem dos APKs na pasta de entrega.
Get-ChildItem -LiteralPath $PastaApk -Force | Where-Object { $Gerados -notcontains $_.FullName } | Remove-Item -Recurse -Force

Write-Host "`nAPK GERADO COM SUCESSO" -ForegroundColor Green
foreach ($A in $Gerados) { Write-Host "  $A" }
Write-Host "LEVE: TV Box PROSB-3000. AVANCADA: TV Box mais forte. As duas instalam por cima da versao anterior."
Write-Host "O jogo gira internamente; mantenha o HDMI em landscape."

if ($Instalar) {
    $Adb = Join-Path $Sdk "platform-tools\adb.exe"
    Conectar-TvBox $Adb
    & $Adb install -r $Gerados[0]
    Puxar-Registro $Adb
}
