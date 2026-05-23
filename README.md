# Forza Horizon 6 — E:0-17 Fix helper script

A menu-driven PowerShell tool that **diagnoses and fixes the Forza Horizon 6 `E:0-17` error** caused by Windows debloat / anti‑telemetry tweaks (privacy.sexy, O&O ShutUp10, Win10/11Debloater, etc.).

🇬🇧 [English](#english) · 🇷🇺 [Русский](#русский)

The error usually comes from a broken save‑folder provisioning chain: a debloat script disables telemetry and sets `DisableOneSettingsDownloads=1`, so Windows never downloads the **OneSettings** config, and **Gaming Services** can't create the save folder → `E:0-17`.

---

## English

### What it does
- **Diagnoses** the system (telemetry/OneSettings, DiagTrack, Gaming Services, Store policies, Xbox services, hosts, firewall, metered connection, Windows Update) and writes a log to your Desktop.
- Shows a **numbered menu of fixes**, ordered by priority. Each item has a description, an explanation of *what it changes*, and a **rollback** option.
- **Backs up every change first** (registry values, `.reg` exports, `hosts` copy, firewall/service state) to a folder on your Desktop, so anything can be undone.

### How to use
1. Download [**`Fix-Forza-E0-17.ps1`**](https://github.com/drizzle-mizzle/Forza-Horizon-6-E-0-17-Fix-helper-script/blob/main/Fix-Forza-E0-17.ps1).
2. Open **Windows PowerShell as Administrator** (right‑click → *Run as administrator*).
3. Go to the folder with the script, e.g. `cd $env:USERPROFILE\Downloads`.
4. Allow the script to run for this session:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
5. Run it:
   ```powershell
   .\Fix-Forza-E0-17.ps1
   ```
6. Pick a language → run **Full diagnostics** → open the **fixes menu** and apply items **top‑down**, launching the game and checking after each one.

### Notes
- Run in **Windows PowerShell (as admin)**, not PowerShell 7 — fewer surprises (the script already works around the missing Appx module in PS7).
- The log and the backup folder are created on your **Desktop** (`Forza_E0-17_Diagnostics.txt`, `Forza_E0-17_Backups`).
- Fix #2 starts the **DiagTrack** service so OneSettings is fetched — after applying it, **run the game in the same session without rebooting the system, as the service may be disabled again**.
- This tool changes registry keys and Windows services. Backups are made automatically, but use it at your own risk.

---

## Русский

### Что делает
- **Диагностирует** систему (телеметрия/OneSettings, DiagTrack, Gaming Services, политики Store, службы Xbox, hosts, брандмауэр, лимитное подключение, Windows Update) и пишет лог на Рабочий стол.
- Показывает **пронумерованное меню фиксов** по приоритету. У каждого пункта есть описание, пояснение *что именно изменится* и **откат**.
- **Перед каждым изменением делает бэкап** (значения реестра, экспорт `.reg`, копия `hosts`, состояние служб/брандмауэра) в папку на Рабочем столе — любой шаг можно отменить.

### Как пользоваться
1. Скачать [**`Fix-Forza-E0-17.ps1`**](https://github.com/drizzle-mizzle/Forza-Horizon-6-E-0-17-Fix-helper-script/blob/main/Fix-Forza-E0-17.ps1).
2. Открыть **Windows PowerShell от имени администратора** (правый клик → *Запуск от имени администратора*).
3. Перейти в папку со скриптом, например `cd $env:USERPROFILE\Downloads`.
4. Разрешить запуск скриптов на эту сессию:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
5. Запустить:
   ```powershell
   .\Fix-Forza-E0-17.ps1
   ```
6. Выбрать язык → сделать **Диагностику проблем** → открыть **Меню исправлений** и применить подходящие пункты **сверху вниз**, после каждого запуская игру и проверяя результат.

### Примечания
- Запускайте в **Windows PowerShell (от админа)**, а не в PowerShell 7 — меньше сюрпризов (обход отсутствующего модуля Appx в PS7 уже встроен).
- Лог и папка с бэкапами создаются на **Рабочем столе** (`Forza_E0-17_Diagnostics.txt`, `Forza_E0-17_Backups`).
- Фикс №2 запускает службу **DiagTrack**, чтобы скачался OneSettings — после его применения **запускайте игру в том же сеансе, не перезагружая систему, так как служба может снова отключиться.**.
- Скрипт меняет ключи реестра и службы Windows. Бэкапы делаются автоматически, но используешь на свой риск.
