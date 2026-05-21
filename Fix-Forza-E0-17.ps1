<#
================================================================================
  Fix-Forza-E0-17.ps1
  Диагностика и пошаговое исправление ошибки Forza Horizon 6  E:0-17.
  Diagnose and step-by-step fix for Forza Horizon 6 error E:0-17.

  Язык выбирается при запуске; дальше весь текст — на выбранном языке.
  Language is chosen at startup; afterwards all text is in that language.

  ВАЖНО / IMPORTANT:
   - Запускать в Windows PowerShell ОТ ИМЕНИ АДМИНИСТРАТОРА.
     Run in Windows PowerShell AS ADMINISTRATOR.
   - Перед каждым изменением делается бэкап; у каждого пункта есть откат.
     Every change is backed up first; every item has a rollback option.
   - После каждого фикса запускай игру и проверяй, двигаясь сверху вниз.
     After each fix, launch the game and check, moving top-down.

  Разблокировка запуска на сессию / Allow run for this session:
     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
================================================================================
#>

$ErrorActionPreference = 'SilentlyContinue'

# ---------- Язык / Language ---------------------------------------------------
$script:Lang = 'ru'
function T { param($ru,$en) if ($script:Lang -eq 'en') { $en } else { $ru } }

# ---------- Пути и бэкапы / Paths and backups --------------------------------
$Desktop     = [Environment]::GetFolderPath('Desktop')
$LogFile     = Join-Path $Desktop 'Forza_E0-17_Diagnostics.txt'
$BackupDir   = Join-Path $Desktop 'Forza_E0-17_Backups'
$RecordsFile = Join-Path $BackupDir 'manifest.json'
if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir | Out-Null }

$script:Records = @()
function Load-Records { if (Test-Path $RecordsFile) { $script:Records = @(Get-Content $RecordsFile -Raw | ConvertFrom-Json) } }
function Save-Records { $script:Records | ConvertTo-Json -Depth 6 | Set-Content $RecordsFile -Encoding UTF8 }
function Add-Record   { param($rec) $script:Records += [pscustomobject]$rec; Save-Records }
Load-Records

# Общий паттерн доменов Microsoft/Xbox / shared Microsoft/Xbox domain pattern
$MsPattern = 'microsoft|xboxlive|xbox\.com|live\.com|windows\.com|msftncsi|telemetry|vortex|watson|smartscreen|wns\.windows|data\.microsoft'

# ---------- Вывод / Output ----------------------------------------------------
function Log  { param($t) Add-Content -Path $LogFile -Value $t }
# Line: принимает RU и EN, печатает только выбранный язык.
# Line: takes RU and EN, prints only the chosen language.
function Line { param($ru,$en,$c='Gray') $t = (T $ru $en); Write-Host $t -ForegroundColor $c; Log $t }
# Raw: язык-нейтральный текст (рамки, версии, числа).
# Raw: language-neutral text (bars, versions, numbers).
function Raw  { param($t,$c='Gray') Write-Host $t -ForegroundColor $c; Log $t }
function Bar  { Raw ('=' * 78) 'Cyan' }

function Is-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------- Хелперы бэкапа/изменений / backup+change helpers -----------------
function Set-RegValueWithBackup {
    param($FixId,$Path,$Name,$Value)
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    $existed = $false; $prev = $null
    try { $prev = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name; $existed = $true } catch {}
    Add-Record @{ FixId=$FixId; Kind='RegValue'; Path=$Path; Name=$Name; Existed=$existed; Value=$prev }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
}
function Export-RegKeyBackup {
    param($FixId,$RegPath,$Tag)   # RegPath: 'HKLM\SOFTWARE\...'
    $file = Join-Path $BackupDir "$Tag.reg"
    & reg.exe export $RegPath $file /y *> $null
    Add-Record @{ FixId=$FixId; Kind='RegKeyExport'; File=$file }
}
function Backup-File {
    param($FixId,$Original,$Tag)
    $bak = Join-Path $BackupDir $Tag
    Copy-Item $Original $bak -Force
    Add-Record @{ FixId=$FixId; Kind='File'; Original=$Original; Backup=$bak }
}

# Версия Appx через Windows PowerShell 5.1 (в PS7 модуль Appx часто не грузится)
# Appx version via Windows PowerShell 5.1 (Appx module often missing in PS7)
function Get-PkgVersion {
    param($Name,[switch]$AllUsers)
    $au  = if ($AllUsers) { '-AllUsers' } else { '' }
    $cmd = "(Get-AppxPackage $au $Name | Select-Object -First 1).Version"
    $o = & "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -Command $cmd 2>$null
    ($o | Select-Object -First 1)
}

# ============================================================================
#  ДИАГНОСТИКА / DIAGNOSTICS
# ============================================================================
function Run-Diagnostics {
    "" | Out-File $LogFile  # очистить лог / reset log
    Bar
    Line "ДИАГНОСТИКА Forza E:0-17 — $(Get-Date)" "DIAGNOSTICS for Forza E:0-17 — $(Get-Date)" 'Cyan'
    $os = Get-CimInstance Win32_OperatingSystem
    Raw ("{0} (build {1})  PC: {2}" -f $os.Caption,$os.BuildNumber,$env:COMPUTERNAME)
    if (-not (Is-Admin)) { Line "Внимание: без прав администратора часть проверок не могут быть выполнены полностью." "Warning: without admin some checks are incomplete." 'Yellow' }
    Bar

    # 1. Телеметрия + OneSettings
    Line "[1] Телеметрия и OneSettings (главная причина E:0-17)" "[1] Telemetry & OneSettings (top cause of E:0-17)" 'White'
    $dcp = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
    $dcc = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'
    $one = (Get-ItemProperty $dcp).DisableOneSettingsDownloads
    if ($one -eq 1) { Line "    [ПРОБЛЕМА] DisableOneSettingsDownloads = 1 (блокирует загрузку конфига сейвов)" "    [PROBLEM] DisableOneSettingsDownloads = 1 (blocks the save-config download)" 'Red' }
    else            { Line "    [OK] DisableOneSettingsDownloads не задан / = 0" "    [OK] DisableOneSettingsDownloads not set / = 0" 'Green' }
    foreach ($p in @(@{n='Policies';v=(Get-ItemProperty $dcp).AllowTelemetry},@{n='CurrentVersion';v=(Get-ItemProperty $dcc).AllowTelemetry})) {
        if ($p.v -ne $null -and $p.v -le 0) { Line "    [ПРОБЛЕМА] AllowTelemetry = 0 ($($p.n)) — телеметрия выключена" "    [PROBLEM] AllowTelemetry = 0 ($($p.n)) — telemetry is off" 'Red' }
        elseif ($p.v)                       { Line "    [OK] AllowTelemetry = $($p.v) ($($p.n))" "    [OK] AllowTelemetry = $($p.v) ($($p.n))" 'Green' }
    }

    # 2. DiagTrack
    Line "[2] Служба DiagTrack (скачивает OneSettings)" "[2] DiagTrack service (downloads OneSettings)" 'White'
    $diag = Get-CimInstance Win32_Service -Filter "Name='DiagTrack'"
    if (-not $diag)                                                     { Line "    [ПРОБЛЕМА] Служба DiagTrack отсутствует (ошибка 1060)" "    [PROBLEM] DiagTrack service is missing (error 1060)" 'Red' }
    elseif ($diag.StartMode -eq 'Disabled' -or $diag.State -ne 'Running') { Line "    [ВНИМАНИЕ] DiagTrack: StartMode=$($diag.StartMode), State=$($diag.State)" "    [WARNING] DiagTrack: StartMode=$($diag.StartMode), State=$($diag.State)" 'Yellow' }
    else                                                                { Line "    [OK] DiagTrack: $($diag.StartMode)/$($diag.State)" "    [OK] DiagTrack: $($diag.StartMode)/$($diag.State)" 'Green' }

    # 3. Gaming Services
    Line "[3] Gaming Services (создаёт папку сохранений)" "[3] Gaming Services (provisions the save folder)" 'White'
    $gs = Get-CimInstance Win32_Service -Filter "Name='GamingServices'"
    $gsVer = Get-PkgVersion 'Microsoft.GamingServices'
    if (-not $gs)                    { Line "    [ПРОБЛЕМА] Служба GamingServices отсутствует" "    [PROBLEM] GamingServices service is missing" 'Red' }
    elseif ($gs.State -ne 'Running') { Line "    [ВНИМАНИЕ] GamingServices: $($gs.State)" "    [WARNING] GamingServices: $($gs.State)" 'Yellow' }
    else                             { Line "    [OK] GamingServices: Running" "    [OK] GamingServices: Running" 'Green' }
    if ($gsVer) { Line "    [OK] Пакет Gaming Services установлен (v$gsVer)" "    [OK] Gaming Services package installed (v$gsVer)" 'Green' }
    else        { Line "    [ПРОБЛЕМА] Пакет Gaming Services не установлен" "    [PROBLEM] Gaming Services package not installed" 'Red' }

    # 4. Политики Store
    Line "[4] Политики Microsoft Store" "[4] Microsoft Store policies" 'White'
    $ws = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'
    $sBad = $false
    foreach ($n in 'RemoveWindowsStore','DisableStoreApps','AutoDownload') {
        $v = (Get-ItemProperty $ws).$n
        if ($null -ne $v) { Line "    [ВНИМАНИЕ] $n = $v" "    [WARNING] $n = $v" 'Yellow'; $sBad = $true }
    }
    if (-not $sBad) { Line "    [OK] Блокирующих политик Store нет" "    [OK] No blocking Store policies" 'Green' }

    # 5. Xbox-службы
    Line "[5] Сопутствующие службы Xbox" "[5] Related Xbox services" 'White'
    foreach ($s in 'XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc','GamingServicesNet') {
        $c = Get-CimInstance Win32_Service -Filter "Name='$s'"
        if (-not $c)                         { Line "    [ВНИМАНИЕ] $s отсутствует" "    [WARNING] $s is missing" 'Yellow' }
        elseif ($c.StartMode -eq 'Disabled') { Line "    [ПРОБЛЕМА] $s ОТКЛЮЧЕНА" "    [PROBLEM] $s is DISABLED" 'Red' }
        else                                 { Line "    [OK] ${s}: $($c.StartMode)/$($c.State)" "    [OK] ${s}: $($c.StartMode)/$($c.State)" 'Green' }
    }

    # 6. Hosts
    Line "[6] Файл hosts" "[6] hosts file" 'White'
    $hosts = "$env:windir\System32\drivers\etc\hosts"
    $blocked = (Get-Content $hosts) | Where-Object { $_ -match $MsPattern -and $_ -notmatch '^\s*#' -and ($_ -match '0\.0\.0\.0' -or $_ -match '127\.0\.0\.1') }
    if ($blocked) { Line "    [ПРОБЛЕМА] В hosts заблокировано доменов Microsoft/Xbox: $($blocked.Count)" "    [PROBLEM] Microsoft/Xbox domains blocked in hosts: $($blocked.Count)" 'Red' }
    else          { Line "    [OK] Подозрительных записей в hosts нет" "    [OK] No suspicious hosts entries" 'Green' }

    # 7. Firewall
    Line "[7] Брандмауэр (исходящие блокировки)" "[7] Firewall (outbound block rules)" 'White'
    $fw = Get-NetFirewallRule -Action Block -Enabled True -Direction Outbound | Where-Object DisplayName -match $MsPattern
    if ($fw) { Line "    [ПРОБЛЕМА] Block-правил по доменам Microsoft/Xbox: $(($fw|Measure-Object).Count)" "    [PROBLEM] Microsoft/Xbox outbound block rules: $(($fw|Measure-Object).Count)" 'Red' }
    else     { Line "    [OK] Block-правил по Microsoft/Xbox нет" "    [OK] No Microsoft/Xbox block rules" 'Green' }

    # 8. Metered
    Line "[8] Лимитное подключение" "[8] Metered connection" 'White'
    Line "    [i] Проверь вручную в Параметрах сети (per-сеть)" "    [i] Check manually in Network settings (per-network)" 'DarkGray'

    # 9. Windows Update
    Line "[9] Политики паузы Windows Update" "[9] Windows Update pause policies" 'White'
    if (Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate') { Line "    [ВНИМАНИЕ] Заданы политики Windows Update (обновления могут быть приостановлены)" "    [WARNING] Windows Update policies set (updates may be paused)" 'Yellow' }
    else { Line "    [OK] Политики Windows Update не заданы" "    [OK] No Windows Update policies" 'Green' }

    Bar
    Line "Диагностика завершена. Лог: $LogFile" "Diagnostics complete. Log: $LogFile" 'Cyan'
    Line "Перейдите в меню фиксов и пробуйте применять каждый один за другим, идя сверху вниз, и пробуя запускать игру после каждого (или примените все разом)." "Next, open the fixes menu and go top-down, testing the game after each." 'Cyan'
}

# ============================================================================
#  ОПРЕДЕЛЕНИЕ ФИКСОВ / FIX DEFINITIONS  (порядок = приоритет / order = priority)
# ============================================================================
$Fixes = @(
 @{
   Id=1
   TitleRu='Включить телеметрию и загрузку OneSettings (ОСНОВНАЯ ПРОБЛЕМА)'
   TitleEn='Enable telemetry & OneSettings downloads (ROOT CAUSE)'
   DescRu='Debloat-скрипты выключают телеметрию и ставят DisableOneSettingsDownloads=1. Без OneSettings Windows не может выдать лицензию/конфиг, и Gaming Services не создаёт папку сохранений — отсюда E:0-17.'
   DescEn='Debloat scripts turn telemetry off and set DisableOneSettingsDownloads=1. Without OneSettings, Windows cannot fetch the license/config, so Gaming Services never provisions the save folder — hence E:0-17.'
   ChangesRu='Ставит AllowTelemetry=1 (Basic) в двух ветках и DisableOneSettingsDownloads=0.'
   ChangesEn='Sets AllowTelemetry=1 (Basic) in two keys and DisableOneSettingsDownloads=0.'
   RollbackRu='Возвращает прежние значения (или удаляет их, если их не было) из бэкапа.'
   RollbackEn='Restores previous values (or removes them if absent) from backup.'
   Apply={
     $dcp='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
     $dcc='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'
     Set-RegValueWithBackup 1 $dcp 'DisableOneSettingsDownloads' 0
     Set-RegValueWithBackup 1 $dcp 'AllowTelemetry' 1
     Set-RegValueWithBackup 1 $dcc 'AllowTelemetry' 1
     Line "Готово. Телеметрия и OneSettings разблокированы." "Done. Telemetry and OneSettings unblocked." 'Green'
   }
 },
 @{
   Id=2
   TitleRu='Восстановить и запустить DiagTrack + обновить OneSettings'
   TitleEn='Restore & start DiagTrack + refresh OneSettings'
   DescRu='Именно служба DiagTrack скачивает OneSettings. Если её отключили или удалили, конфиг сейвов не приходит. Фикс создаёт службу (если её нет), запускает её, чистит кэш и заставляет скачать свежий конфиг.'
   DescEn='DiagTrack is the service that downloads OneSettings. If it was disabled/removed, the save config never arrives. This fix (re)creates it, starts it, clears the cache and forces a fresh download.'
   ChangesRu='Создаёт службу DiagTrack (svchost/utcsvc) при отсутствии, ставит автозапуск, очищает C:\ProgramData\Microsoft\Diagnosis\DownloadedSettings и запускает службу. ВАЖНО: после этого запусти игру В ЭТОМ ЖЕ СЕАНСЕ, не перезагружаясь.'
   ChangesEn='Creates the DiagTrack service (svchost/utcsvc) if missing, sets it to Automatic, clears C:\ProgramData\Microsoft\Diagnosis\DownloadedSettings and starts it. NOTE: then launch the game IN THE SAME SESSION, without rebooting.'
   RollbackRu='Если служба была создана этим скриптом — удаляет её. Если существовала — возвращает прежний тип запуска и состояние.'
   RollbackEn='If the service was created by this script, deletes it. If it existed before, restores its previous startup type and state.'
   Apply={
     $svc = Get-CimInstance Win32_Service -Filter "Name='DiagTrack'"
     if (-not $svc) {
       & sc.exe create DiagTrack binPath= "C:\Windows\System32\svchost.exe -k utcsvc -p" type= share start= auto DisplayName= "Connected User Experiences and Telemetry" *> $null
       & reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\DiagTrack\Parameters" /v ServiceDll /t REG_EXPAND_SZ /d "C:\Windows\System32\diagtrack.dll" /f *> $null
       Add-Record @{ FixId=2; Kind='Service'; Name='DiagTrack'; Created=$true }
       Line "Служба DiagTrack создана." "DiagTrack service created." 'Green'
     } else {
       Add-Record @{ FixId=2; Kind='Service'; Name='DiagTrack'; Created=$false; PrevStartMode=$svc.StartMode; PrevState=$svc.State }
       Set-Service DiagTrack -StartupType Automatic
     }
     Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue
     Remove-Item "C:\ProgramData\Microsoft\Diagnosis\DownloadedSettings\*" -Recurse -Force -ErrorAction SilentlyContinue
     Start-Service DiagTrack -ErrorAction SilentlyContinue
     Start-Sleep -Seconds 5
     $st = (Get-Service DiagTrack).Status
     Line "DiagTrack запущена (статус: $st). Дай минуту и запускай игру без перезагрузки." "DiagTrack started (status: $st). Wait a minute, then launch the game without rebooting." 'Green'
   }
 },
 @{
   Id=3
   TitleRu='Переустановить Gaming Services'
   TitleEn='Reinstall Gaming Services'
   DescRu='Если пакет Gaming Services повреждён или не зарегистрирован для пользователя, сейвы не создаются. Фикс удаляет пакет и открывает его страницу в Store для чистой установки.'
   DescEn='If Gaming Services is broken or not registered for your user, saves are not provisioned. This fix removes the package and opens its Store page for a clean install.'
   ChangesRu='Удаляет пакеты Microsoft.GamingServices для всех пользователей и открывает Microsoft Store. ПОСЛЕ открытия нажми «Получить/Установить» и дождись завершения, затем перезагрузись.'
   ChangesEn='Removes Microsoft.GamingServices for all users and opens Microsoft Store. After it opens, click Get/Install and wait, then reboot.'
   RollbackRu='Откат не предусмотрен: переустановка и есть восстановление. Чтобы убрать — удали Gaming Services через Параметры.'
   RollbackEn='No rollback: reinstalling is the restorative action. To remove, uninstall Gaming Services via Settings.'
   Apply={
     Get-AppxPackage -AllUsers *GamingServices* | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
     Start-Process "ms-windows-store://pdp/?productid=9MWPM2CQNLHN"
     Line "Открыт Store. Нажми «Установить», дождись и перезагрузись." "Store opened. Click Install, wait, then reboot." 'Yellow'
   }
 },
 @{
   Id=4
   TitleRu='Снять блокирующие политики Microsoft Store'
   TitleEn='Remove blocking Microsoft Store policies'
   DescRu='Политики RemoveWindowsStore/DisableStoreApps/AutoDownload мешают Store устанавливать и обновлять Gaming Services.'
   DescEn='Policies RemoveWindowsStore/DisableStoreApps/AutoDownload prevent Store from installing/updating Gaming Services.'
   ChangesRu='Удаляет эти значения из HKLM\...\Policies\Microsoft\WindowsStore (с бэкапом всей ветки).'
   ChangesEn='Removes these values from HKLM\...\Policies\Microsoft\WindowsStore (whole key backed up first).'
   RollbackRu='Импортирует .reg-бэкап ветки WindowsStore.'
   RollbackEn='Imports the .reg backup of the WindowsStore key.'
   Apply={
     $ws='HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'
     if (Test-Path $ws) {
       Export-RegKeyBackup 4 'HKLM\SOFTWARE\Policies\Microsoft\WindowsStore' 'WindowsStore_policy'
       foreach ($n in 'RemoveWindowsStore','DisableStoreApps','AutoDownload') { Remove-ItemProperty -Path $ws -Name $n -ErrorAction SilentlyContinue }
       Line "Блокирующие политики Store удалены." "Store blocking policies removed." 'Green'
     } else { Line "Политики Store не заданы — менять нечего." "No Store policies set — nothing to change." 'Green' }
   }
 },
 @{
   Id=5
   TitleRu='Включить отключённые службы Xbox'
   TitleEn='Enable disabled Xbox services'
   DescRu='Если службы Xbox (авторизация, сохранения, сеть) отключены, проверка профиля и сейвов не проходит.'
   DescEn='If Xbox services (auth, save, networking) are Disabled, profile/save checks fail.'
   ChangesRu='Те из служб XblAuthManager, XblGameSave, XboxNetApiSvc, XboxGipSvc, GamingServicesNet, что в статусе Disabled, переводит в Manual (с запоминанием прежнего состояния).'
   ChangesEn='Any of XblAuthManager, XblGameSave, XboxNetApiSvc, XboxGipSvc, GamingServicesNet that are Disabled are set to Manual (previous state remembered).'
   RollbackRu='Возвращает прежний тип запуска для затронутых служб.'
   RollbackEn='Restores the previous startup type for affected services.'
   Apply={
     foreach ($s in 'XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc','GamingServicesNet') {
       $c = Get-CimInstance Win32_Service -Filter "Name='$s'"
       if ($c -and $c.StartMode -eq 'Disabled') {
         Add-Record @{ FixId=5; Kind='Service'; Name=$s; Created=$false; PrevStartMode='Disabled'; PrevState=$c.State }
         Set-Service -Name $s -StartupType Manual
         Line "Служба $s включена (Manual)." "Service $s enabled (Manual)." 'Green'
       }
     }
     Line "Готово." "Done." 'Green'
   }
 },
 @{
   Id=6
   TitleRu='Очистить hosts от блокировок Microsoft/Xbox'
   TitleEn='Clean Microsoft/Xbox blocks from hosts'
   DescRu='Анти-телеметрия скрипты вписывают домены Microsoft/Xbox в hosts на 0.0.0.0/127.0.0.1, что рвёт связь с сервисами.'
   DescEn='Anti-telemetry scripts map Microsoft/Xbox domains to 0.0.0.0/127.0.0.1 in hosts, cutting off the services.'
   ChangesRu='Удаляет из hosts только строки, заворачивающие домены Microsoft/Xbox в null-адрес (с бэкапом файла). Комментарии и прочее не трогает.'
   ChangesEn='Removes only the hosts lines that point Microsoft/Xbox domains to a null address (file backed up first). Comments and other entries are left intact.'
   RollbackRu='Восстанавливает hosts из резервной копии.'
   RollbackEn='Restores hosts from the backup copy.'
   Apply={
     $hosts="$env:windir\System32\drivers\etc\hosts"
     Backup-File 6 $hosts 'hosts.bak'
     $kept = (Get-Content $hosts) | Where-Object { -not ($_ -match $MsPattern -and $_ -notmatch '^\s*#' -and ($_ -match '0\.0\.0\.0' -or $_ -match '127\.0\.0\.1')) }
     $kept | Set-Content $hosts -Encoding ASCII
     Line "Файл hosts очищен (бэкап сохранён)." "hosts cleaned (backup saved)." 'Green'
   }
 },
 @{
   Id=7
   TitleRu='Отключить block-правила брандмауэра по Microsoft/Xbox'
   TitleEn='Disable Microsoft/Xbox firewall block rules'
   DescRu='Debloat-инструменты создают исходящие block-правила, режущие телеметрию и заодно сервисы Xbox.'
   DescEn='Debloat tools add outbound block rules that cut telemetry and Xbox services alike.'
   ChangesRu='Отключает (НЕ удаляет) включённые исходящие block-правила, чьё имя содержит домены Microsoft/Xbox.'
   ChangesEn='Disables (does NOT delete) enabled outbound block rules whose name matches Microsoft/Xbox.'
   RollbackRu='Снова включает ранее отключённые правила.'
   RollbackEn='Re-enables the previously disabled rules.'
   Apply={
     $fw = Get-NetFirewallRule -Action Block -Enabled True -Direction Outbound | Where-Object DisplayName -match $MsPattern
     if ($fw) {
       foreach ($r in $fw) { Add-Record @{ FixId=7; Kind='FirewallDisabled'; Name=$r.Name }; Set-NetFirewallRule -Name $r.Name -Enabled False }
       Line "Отключено правил: $(($fw|Measure-Object).Count)." "Rules disabled: $(($fw|Measure-Object).Count)." 'Green'
     } else { Line "Подходящих block-правил не найдено." "No matching block rules found." 'Green' }
   }
 },
 @{
   Id=8
   TitleRu='Лимитное подключение (инструкция)'
   TitleEn='Metered connection (guide)'
   DescRu='Частая причина E:0-17 — активное «лимитное подключение», которое режёт фоновые загрузки/синхронизацию.'
   DescEn='A common E:0-17 cause is an active "metered connection" that throttles background downloads/sync.'
   ChangesRu='Ничего не меняет автоматически — открывает Параметры сети. Per-сеть лимит надёжнее выключать вручную: Параметры > Сеть и Интернет > свойства подключения > Лимитное подключение = Откл.'
   ChangesEn='Changes nothing automatically — opens Network settings. Per-network metered is best toggled manually: Settings > Network & Internet > connection properties > Metered connection = Off.'
   RollbackRu='Не требуется (изменения вносятся тобой вручную).'
   RollbackEn='Not needed (you make the change manually).'
   Apply={
     Start-Process 'ms-settings:network'
     Line "Открыты Параметры сети. Выключи «Лимитное подключение» для активной сети." "Network settings opened. Turn off 'Metered connection' for the active network." 'Yellow'
   }
 },
 @{
   Id=9
   TitleRu='Снять паузу/отсрочку Windows Update (гигиена)'
   TitleEn='Un-pause/undefer Windows Update (hygiene)'
   DescRu='Долго приостановленные обновления оставляют Store и Gaming Services устаревшими (их апдейты приходят вместе с обновлениями Windows). Прямой причиной E:0-17 это обычно не является, но мешает остальным фиксам встать.'
   DescEn='Long-paused updates leave Store and Gaming Services outdated (their updates ride along with Windows updates). Usually not the direct cause of E:0-17, but it hinders the other fixes.'
   ChangesRu='Удаляет ветку HKLM\...\Policies\Microsoft\Windows\WindowsUpdate (с бэкапом) и делает gpupdate.'
   ChangesEn='Removes HKLM\...\Policies\Microsoft\Windows\WindowsUpdate (backed up first) and runs gpupdate.'
   RollbackRu='Импортирует .reg-бэкап ветки WindowsUpdate.'
   RollbackEn='Imports the .reg backup of the WindowsUpdate key.'
   Apply={
     $wu='HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
     if (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate") {
       Export-RegKeyBackup 9 $wu 'WindowsUpdate_policy'
       & reg.exe delete $wu /f *> $null
       & gpupdate /force *> $null
       Line "Политики Windows Update сняты." "Windows Update policies removed." 'Green'
     } else { Line "Политик Windows Update нет — менять нечего." "No Windows Update policies — nothing to change." 'Green' }
   }
 }
)

# ---------- Откат / Rollback --------------------------------------------------
function Rollback-Fix {
    param($FixId)
    Load-Records
    $recs = @($script:Records | Where-Object { $_.FixId -eq $FixId })
    if (-not $recs) { Line "Для пункта $FixId нет записей бэкапа — откатывать нечего." "No backup records for item $FixId — nothing to roll back." 'Yellow'; return }
    [array]::Reverse($recs)
    foreach ($r in $recs) {
        switch ($r.Kind) {
            'RegValue' {
                if ($r.Existed) { New-ItemProperty -Path $r.Path -Name $r.Name -Value $r.Value -PropertyType DWord -Force | Out-Null }
                else { Remove-ItemProperty -Path $r.Path -Name $r.Name -ErrorAction SilentlyContinue }
            }
            'RegKeyExport' { if (Test-Path $r.File) { & reg.exe import $r.File *> $null } }
            'File'         { if (Test-Path $r.Backup) { Copy-Item $r.Backup $r.Original -Force } }
            'FirewallDisabled' { Set-NetFirewallRule -Name $r.Name -Enabled True -ErrorAction SilentlyContinue }
            'Service' {
                if ($r.Created) { & sc.exe stop $r.Name *> $null; & sc.exe delete $r.Name *> $null }
                else {
                    $map = @{ Auto='Automatic'; Manual='Manual'; Disabled='Disabled' }
                    if ($map[$r.PrevStartMode]) { Set-Service -Name $r.Name -StartupType $map[$r.PrevStartMode] -ErrorAction SilentlyContinue }
                    if ($r.PrevState -eq 'Stopped') { Stop-Service -Name $r.Name -Force -ErrorAction SilentlyContinue }
                }
            }
        }
    }
    $script:Records = @($script:Records | Where-Object { $_.FixId -ne $FixId }); Save-Records
    Line "Откат пункта $FixId выполнен." "Rollback of item $FixId complete." 'Green'
}

# ============================================================================
#  МЕНЮ / MENU
# ============================================================================
function Show-FixDetail {
    param($fix)
    Bar
    Raw ("[{0}] {1}" -f $fix.Id, (T $fix.TitleRu $fix.TitleEn)) 'White'
    Raw ''
    Line ("Что это:  " + $fix.DescRu)     ("What:     " + $fix.DescEn)
    Raw ''
    Line ("Изменит:  " + $fix.ChangesRu)  ("Changes:  " + $fix.ChangesEn) 'Yellow'
    Raw ''
    Line ("Откат:    " + $fix.RollbackRu) ("Rollback: " + $fix.RollbackEn) 'DarkCyan'
    Bar
}

function Fixes-Menu {
    while ($true) {
        Bar
        Line "СПИСОК ФИКСОВ — выбирай по порядку сверху вниз" "FIXES MENU — go top-down" 'Cyan'
        Line "После каждого применённого фикса запусти игру и проверь E:0-17." "After each applied fix, launch the game and check E:0-17." 'Cyan'
        Bar
        foreach ($f in $Fixes) {
            Write-Host ("  [{0}] " -f $f.Id) -ForegroundColor White -NoNewline
            Write-Host (T $f.TitleRu $f.TitleEn) -ForegroundColor Gray
        }
        Raw ''
        Line "Введи номер фикса, или: D — диагностика, Q — выход" "Enter a fix number, or: D — diagnostics, Q — quit" 'Cyan'
        $sel = (Read-Host "> ").Trim()
        if ($sel -match '^[Qq]') { break }
        if ($sel -match '^[Dd]') { Run-Diagnostics; continue }
        if ($sel -match '^\d+$' -and ($fix = $Fixes | Where-Object Id -eq [int]$sel)) {
            Show-FixDetail $fix
            Line "Действие: A — применить, U — откатить, B — назад" "Action: A — apply, U — undo(rollback), B — back" 'Cyan'
            $act = (Read-Host "> ").Trim()
            if (-not (Is-Admin) -and $act -match '^[AaUu]') {
                Line "Нужны права администратора. Перезапусти PowerShell от имени админа." "Administrator rights required. Restart PowerShell as admin." 'Red'; continue
            }
            switch -regex ($act) {
                '^[Aa]' { & $fix.Apply
                          Line ">>> Теперь запусти Forza и проверь, ушла ли E:0-17." ">>> Now launch Forza and check whether E:0-17 is gone." 'Magenta' }
                '^[Uu]' { Rollback-Fix $fix.Id }
                default { }
            }
        } else { Line "Не понял ввод." "Did not understand the input." 'Yellow' }
    }
}

# ============================================================================
#  СТАРТ / START
# ============================================================================
Clear-Host
# Выбор языка (единственное двуязычное место) / Language choice (the only bilingual prompt)
Write-Host ('=' * 78) -ForegroundColor Cyan
Write-Host "Выбери язык / Choose language:" -ForegroundColor Cyan
Write-Host "  [1] Русский"
Write-Host "  [2] English"
Write-Host ('=' * 78) -ForegroundColor Cyan
$lsel = (Read-Host "> ").Trim()
$script:Lang = if ($lsel -eq '2') { 'en' } else { 'ru' }

Clear-Host
Bar
Line "Forza Horizon 6  E:0-17 — диагностика и исправление" "Forza Horizon 6  E:0-17 — diagnose & fix" 'Cyan'
Bar
if (-not (Is-Admin)) {
    Line "ВНИМАНИЕ: скрипт запущен без прав администратора. Диагностика доступна, но исправления могут не работать." "WARNING: The script was run without administrator rights. Diagnostics are available, but fixes may not work." 'Red'
    Line "Закройте и перезапустите PowerShell «От имени администратора»." "Close and relaunch PowerShell 'As administrator'." 'Yellow'
}
Raw ''
Line "Выберите действие" "Select an action" 'Cyan'
Line "  [1] Диагностика проблем" "  [1] Full diagnostics" 'White'
Line "  [2] Меню исправлений" "  [2] Fixes menu" 'White'
Line "  [Q] Выход" "  [Q] Quit" 'White'
$start = (Read-Host "> ").Trim()
switch -regex ($start) {
    '^1' { Run-Diagnostics; Fixes-Menu }
    '^2' { Fixes-Menu }
    default { }
}
Line "Готово. Лог: $LogFile  Бэкапы: $BackupDir" "Done. Log: $LogFile  Backups: $BackupDir" 'Cyan'
