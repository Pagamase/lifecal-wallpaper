$ErrorActionPreference = 'Stop'

# LifeCal Selector GUI (v13 - editor de estilo)
# PS 5.1 OK + fix git args + editor style.json (estetica)

function Get-RepoRoot() {
  if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { return $PSScriptRoot }
  if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) { return Split-Path -Parent $PSCommandPath }
  return (Get-Location).Path
}

function Pt([int]$x, [int]$y) { New-Object System.Drawing.Point -ArgumentList $x, $y }
function Sz([int]$w, [int]$h) { New-Object System.Drawing.Size -ArgumentList $w, $h }

function Get-LogPaths() {
  $repo = Get-RepoRoot
  return @{
    Repo = (Join-Path $repo 'lifecal_gui_error.log')
    Temp = (Join-Path $env:TEMP 'lifecal_gui_error.log')
  }
}

function Write-Log([string]$msg) {
  $paths = Get-LogPaths
  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $line = ("[{0}] {1}" -f $stamp, $msg)

  try { Add-Content -Path $paths.Repo -Value $line -Encoding utf8; return $paths.Repo }
  catch { try { Add-Content -Path $paths.Temp -Value $line -Encoding utf8; return $paths.Temp } catch { return $null } }
}

function Reset-Logs() {
  $paths = Get-LogPaths
  foreach ($p in @($paths.Repo, $paths.Temp)) {
    try { if (Test-Path $p) { Remove-Item $p -Force } } catch {}
    try { New-Item -ItemType File -Path $p -Force | Out-Null } catch {}
  }
}

function To-Hashtable($obj) {
  if ($null -eq $obj) { return $null }
  if ($obj -is [System.Collections.IDictionary]) { return $obj }

  if (($obj -is [System.Collections.IEnumerable]) -and -not ($obj -is [string])) {
    $arr = @()
    foreach ($item in $obj) { $arr += (To-Hashtable $item) }
    return $arr
  }

  if ($obj -is [psobject]) {
    $ht = @{}
    foreach ($p in $obj.PSObject.Properties) { $ht[$p.Name] = (To-Hashtable $p.Value) }
    return $ht
  }

  return $obj
}

function Load-JsonObject([string]$path) {
  if (-not (Test-Path $path)) { return @{} }
  $raw = Get-Content -Path $path -Raw
  if ([string]::IsNullOrWhiteSpace($raw)) { return @{} }
  $obj = $raw | ConvertFrom-Json
  $ht = To-Hashtable $obj
  if ($null -eq $ht) { return @{} }
  if ($ht -is [System.Collections.IDictionary]) { return $ht }
  return @{}
}

function Save-JsonObject([hashtable]$obj, [string]$path) {
  $json = $obj | ConvertTo-Json -Depth 50
  Set-Content -Path $path -Value $json -Encoding utf8
}

function Ensure-DirForFile([string]$path) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
}

function Get-DefaultBackupDir([string]$repo) {
  $d1 = Join-Path $repo 'lifecal_route_backups'
  if (Test-Path $d1) { return $d1 }
  $d2 = Join-Path $repo 'route_backups'
  if (Test-Path $d2) { return $d2 }
  return $d1
}

function Try-ParseInlineDesc([string]$tsxPath) {
  try {
    if (-not (Test-Path $tsxPath)) { return $null }
    $lines = Get-Content -Path $tsxPath -TotalCount 160
    if ($lines.Count -eq 0) { return $null }

    $descLines = @()
    foreach ($l in $lines) { if ($l -match '^\s*//\s*DESC\s*:\s*(.*)$') { $descLines += $Matches[1] } }
    if ($descLines.Count -gt 0) { return ($descLines -join "`r`n").Trim() }

    $text = ($lines -join "`n")
    $m = [regex]::Match($text, '/\*\s*DESC\s*(.*?)\*/', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($m.Success) {
      $block = $m.Groups[1].Value
      $block = $block -replace '^\s*\*\s?', ''
      return ($block.Trim())
    }
    return $null
  } catch { return $null }
}

function Find-GitExe() {
  $cmd = Get-Command git -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return $cmd.Source }

  $candidates = @(
    "$env:ProgramFiles\Git\cmd\git.exe",
    "$env:ProgramFiles\Git\bin\git.exe",
    "$env:ProgramFiles(x86)\Git\cmd\git.exe",
    "$env:ProgramFiles(x86)\Git\bin\git.exe",
    "$env:LocalAppData\Programs\Git\cmd\git.exe",
    "$env:LocalAppData\Programs\Git\bin\git.exe"
  )
  foreach ($c in $candidates) { if (-not [string]::IsNullOrWhiteSpace($c) -and (Test-Path $c)) { return $c } }
  return $null
}

function Run-Git([string]$gitExe, [string]$repo, [string]$gitArgs) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $gitExe
  $psi.Arguments = $gitArgs
  $psi.WorkingDirectory = $repo
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi

  [void]$p.Start()
  $out = $p.StandardOutput.ReadToEnd()
  $err = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  return @{ ExitCode = $p.ExitCode; Stdout = $out; Stderr = $err; GitArgs = $gitArgs }
}

function Git-CommitPush([string]$gitExe, [string]$repo, [string]$commitMsg) {
  $resStatus = Run-Git $gitExe $repo 'status --porcelain'
  if ($resStatus.ExitCode -ne 0) { return @{ Ok=$false; Msg=("Git status fallo:`r`n" + $resStatus.Stderr + "`r`n" + $resStatus.Stdout) } }
  if ([string]::IsNullOrWhiteSpace($resStatus.Stdout)) { return @{ Ok=$true; Msg='No hay cambios en git. Nada que subir.' } }

  [void](Run-Git $gitExe $repo 'add -A')
  [void](Run-Git $gitExe $repo ("commit -m `"$commitMsg`""))

  $resPush = Run-Git $gitExe $repo 'push'
  if ($resPush.ExitCode -ne 0) { return @{ Ok=$false; Msg=("Git push fallo:`r`n" + $resPush.Stderr + "`r`n" + $resPush.Stdout) } }
  return @{ Ok=$true; Msg='Push hecho.' }
}

function Normalize-Hex([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return $null }
  $t = $s.Trim()
  if ($t.StartsWith('#')) { $t = $t.Substring(1) }
  if ($t -match '^[0-9a-fA-F]{6}$') { return ('#' + $t.ToLower()) }
  return $null
}

function Default-Style() {
  return @{
    bg = '#0f0f10'
    label = '#a9a9aa'
    subtle = '#7c7c7d'
    accent = '#ff7a00'
    pastDay = '#e9e9ea'
    futureDay = '#2f2f31'
    futureSaturday = '#6b6b70'
    sundayRed = '#ff3b30'
    sundayRedInnerWhenBirthday = '#b3261e'
    birthdayRing = '#ff3b30'
    todayHalo = '#f2f2f2'
    sundayRingColor = '#f2f2f2'
    barTrack = '#1b1b1d'
    topMarginPct = 0.30
    bottomMarginPct = 0.22
    contentWidthPct = 0.72
    colGapPct = 0.06
    rowGapPct = 0.055
    showSundayRing = $true
    birthdays = @('05-01','03-28','10-08','11-08','11-24')
  }
}

function Load-Style([string]$stylePath) {
  $d = Default-Style
  if (-not (Test-Path $stylePath)) { return $d }
  $cfg = Load-JsonObject $stylePath
  foreach ($k in $cfg.Keys) { $d[$k] = $cfg[$k] }
  return $d
}

function Save-Style([hashtable]$style, [string]$stylePath) {
  Ensure-DirForFile $stylePath
  Save-JsonObject $style $stylePath
}

function Show-StyleEditor([string]$stylePath, [string]$gitExe, [string]$repo) {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $style = Load-Style $stylePath

  $dlg = New-Object System.Windows.Forms.Form
  $dlg.Text = 'Editar estilo (style.json)'
  $dlg.Size = Sz 780 740
  $dlg.StartPosition = 'CenterParent'
  $dlg.FormBorderStyle = 'FixedDialog'
  $dlg.MaximizeBox = $false
  $dlg.MinimizeBox = $false

  $info = New-Object System.Windows.Forms.Label
  $info.AutoSize = $true
  $info.Location = Pt 12 10
  $info.Text = "Archivo: $stylePath`r`nColores en #RRGGBB."
  $dlg.Controls.Add($info)

  $panel = New-Object System.Windows.Forms.Panel
  $panel.Location = Pt 12 60
  $panel.Size = Sz 740 560
  $panel.AutoScroll = $true
  $dlg.Controls.Add($panel)

  $y = 8
  function Add-Row([string]$label, [string]$value) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.AutoSize = $true
    $lbl.Location = Pt 8 $script:y
    $lbl.Text = $label
    $panel.Controls.Add($lbl)

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location = Pt 320 $script:y
    $tb.Size = Sz 170 22
    $tb.Text = $value
    $panel.Controls.Add($tb)

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = '...'
    $btn.Location = Pt 500 $script:y
    $btn.Size = Sz 36 22
    $panel.Controls.Add($btn)

    $btn.Add_Click({
      $cd = New-Object System.Windows.Forms.ColorDialog
      $cd.FullOpen = $true
      $norm = Normalize-Hex $tb.Text
      if ($norm) { try { $cd.Color = [System.Drawing.ColorTranslator]::FromHtml($norm) } catch {} }
      if ($cd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $tb.Text = ("#{0:X2}{1:X2}{2:X2}" -f $cd.Color.R, $cd.Color.G, $cd.Color.B).ToLower()
      }
    })

    $script:y += 30
    return $tb
  }

  $tbBg = Add-Row 'Fondo (bg)' ([string]$style.bg)
  $tbLabel = Add-Row 'Meses (label)' ([string]$style.label)
  $tbSubtle = Add-Row 'Texto secundario (subtle)' ([string]$style.subtle)
  $tbAccent = Add-Row 'Acento (accent)' ([string]$style.accent)
  $tbPast = Add-Row 'Dia pasado (pastDay)' ([string]$style.pastDay)
  $tbFuture = Add-Row 'Dia futuro (futureDay)' ([string]$style.futureDay)
  $tbSat = Add-Row 'Sabado futuro (futureSaturday)' ([string]$style.futureSaturday)
  $tbSun = Add-Row 'Domingo (sundayRed)' ([string]$style.sundayRed)
  $tbSunInner = Add-Row 'Domingo si cumple (sundayRedInnerWhenBirthday)' ([string]$style.sundayRedInnerWhenBirthday)
  $tbBdayRing = Add-Row 'Anillo cumple (birthdayRing)' ([string]$style.birthdayRing)
  $tbTodayHalo = Add-Row 'Halo hoy (todayHalo)' ([string]$style.todayHalo)
  $tbSunRing = Add-Row 'Anillo domingo (sundayRingColor)' ([string]$style.sundayRingColor)
  $tbBarTrack = Add-Row 'Track barra (barTrack)' ([string]$style.barTrack)

  $script:y += 12

  $lblNums = New-Object System.Windows.Forms.Label
  $lblNums.AutoSize = $true
  $lblNums.Location = Pt 8 $script:y
  $lblNums.Text = 'MARGENES / ESPACIADO (porcentaje)'
  $panel.Controls.Add($lblNums)
  $script:y += 26

  function Add-Num([string]$label, [double]$value) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.AutoSize = $true
    $lbl.Location = Pt 8 $script:y
    $lbl.Text = $label
    $panel.Controls.Add($lbl)

    $num = New-Object System.Windows.Forms.NumericUpDown
    $num.Location = Pt 320 $script:y
    $num.Size = Sz 170 22
    $num.DecimalPlaces = 3
    $num.Increment = 0.005
    $num.Minimum = 0.05
    $num.Maximum = 0.95
    $num.Value = [decimal]$value
    $panel.Controls.Add($num)

    $script:y += 30
    return $num
  }

  $numTop = Add-Num 'Margen arriba (topMarginPct)' ([double]$style.topMarginPct)
  $numBottom = Add-Num 'Margen abajo (bottomMarginPct)' ([double]$style.bottomMarginPct)
  $numContent = Add-Num 'Ancho contenido (contentWidthPct)' ([double]$style.contentWidthPct)
  $numColGap = Add-Num 'Separacion columnas (colGapPct)' ([double]$style.colGapPct)
  $numRowGap = Add-Num 'Separacion filas (rowGapPct)' ([double]$style.rowGapPct)

  $script:y += 8
  $chkSunRing = New-Object System.Windows.Forms.CheckBox
  $chkSunRing.Text = 'Mostrar anillo en domingo (showSundayRing)'
  $chkSunRing.Location = Pt 8 $script:y
  $chkSunRing.Size = Sz 500 24
  $chkSunRing.Checked = [bool]$style.showSundayRing
  $panel.Controls.Add($chkSunRing)

  $script:y += 36
  $lblB = New-Object System.Windows.Forms.Label
  $lblB.AutoSize = $true
  $lblB.Location = Pt 8 $script:y
  $lblB.Text = 'Cumples (MM-DD), uno por linea:'
  $panel.Controls.Add($lblB)
  $script:y += 24

  $tbBirthdays = New-Object System.Windows.Forms.TextBox
  $tbBirthdays.Location = Pt 8 $script:y
  $tbBirthdays.Size = Sz 528 120
  $tbBirthdays.Multiline = $true
  $tbBirthdays.ScrollBars = 'Vertical'
  $tbBirthdays.Font = New-Object System.Drawing.Font('Consolas', 10)
  if ($style.birthdays -is [System.Collections.IEnumerable]) {
    $tbBirthdays.Text = (($style.birthdays | ForEach-Object { [string]$_ }) -join "`r`n")
  } else { $tbBirthdays.Text = '' }
  $panel.Controls.Add($tbBirthdays)

  $btnSave = New-Object System.Windows.Forms.Button
  $btnSave.Text = 'Guardar estilo'
  $btnSave.Location = Pt 12 632
  $btnSave.Size = Sz 150 36
  $dlg.Controls.Add($btnSave)

  $btnSavePush = New-Object System.Windows.Forms.Button
  $btnSavePush.Text = 'Guardar + Push'
  $btnSavePush.Location = Pt 172 632
  $btnSavePush.Size = Sz 160 36
  $dlg.Controls.Add($btnSavePush)

  $btnClose = New-Object System.Windows.Forms.Button
  $btnClose.Text = 'Cerrar'
  $btnClose.Location = Pt 642 632
  $btnClose.Size = Sz 110 36
  $dlg.Controls.Add($btnClose)

  function Build-StyleFromUI() {
    $s = @{}
    $map = @{
      bg=$tbBg.Text; label=$tbLabel.Text; subtle=$tbSubtle.Text; accent=$tbAccent.Text;
      pastDay=$tbPast.Text; futureDay=$tbFuture.Text; futureSaturday=$tbSat.Text;
      sundayRed=$tbSun.Text; sundayRedInnerWhenBirthday=$tbSunInner.Text;
      birthdayRing=$tbBdayRing.Text; todayHalo=$tbTodayHalo.Text; sundayRingColor=$tbSunRing.Text; barTrack=$tbBarTrack.Text
    }
    foreach ($k in $map.Keys) {
      $norm = Normalize-Hex ([string]$map[$k])
      if (-not $norm) { throw ("Color invalido para {0}: {1}" -f $k, $map[$k]) }
      $s[$k] = $norm
    }
    $s.topMarginPct = [double]$numTop.Value
    $s.bottomMarginPct = [double]$numBottom.Value
    $s.contentWidthPct = [double]$numContent.Value
    $s.colGapPct = [double]$numColGap.Value
    $s.rowGapPct = [double]$numRowGap.Value
    $s.showSundayRing = [bool]$chkSunRing.Checked

    $b = @()
    $raw = $tbBirthdays.Text -split "(`r`n|`n|`r)"
    foreach ($line in $raw) {
      $t = $line.Trim()
      if ([string]::IsNullOrWhiteSpace($t)) { continue }
      if ($t -notmatch '^\d{2}-\d{2}$') { throw ("Cumple invalido: {0} (usa MM-DD)" -f $t) }
      $b += $t
    }
    $s.birthdays = $b
    return $s
  }

  $btnSave.Add_Click({
    try {
      $s = Build-StyleFromUI
      Save-Style $s $stylePath
      [System.Windows.Forms.MessageBox]::Show("Guardado OK:`r`n$stylePath", 'LifeCal') | Out-Null
    } catch {
      [System.Windows.Forms.MessageBox]::Show(("Error guardando estilo:`r`n{0}" -f $_.Exception.Message), 'LifeCal') | Out-Null
    }
  })

  $btnSavePush.Add_Click({
    try {
      $s = Build-StyleFromUI
      Save-Style $s $stylePath
      $stamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
      $res = Git-CommitPush $gitExe $repo ("Update style.json $stamp")
      [System.Windows.Forms.MessageBox]::Show($res.Msg, 'LifeCal') | Out-Null
    } catch {
      [System.Windows.Forms.MessageBox]::Show(("Error Guardar+Push:`r`n{0}" -f $_.Exception.Message), 'LifeCal') | Out-Null
    }
  })

  $btnClose.Add_Click({ $dlg.Close() })

  [void]$dlg.ShowDialog()
}

function Prompt-Multiline([string]$title, [string]$labelText, [string]$initial) {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $dlg = New-Object System.Windows.Forms.Form
  $dlg.Text = $title
  $dlg.Size = Sz 640 420
  $dlg.StartPosition = 'CenterParent'
  $dlg.FormBorderStyle = 'FixedDialog'
  $dlg.MaximizeBox = $false
  $dlg.MinimizeBox = $false

  $lbl = New-Object System.Windows.Forms.Label
  $lbl.AutoSize = $true
  $lbl.Location = Pt 12 12
  $lbl.Text = $labelText
  $dlg.Controls.Add($lbl)

  $tb = New-Object System.Windows.Forms.TextBox
  $tb.Location = Pt 12 40
  $tb.Size = Sz 600 280
  $tb.Multiline = $true
  $tb.ScrollBars = 'Vertical'
  $tb.Text = $initial
  $tb.Font = New-Object System.Drawing.Font('Consolas', 10)
  $dlg.Controls.Add($tb)

  $ok = New-Object System.Windows.Forms.Button
  $ok.Text = 'OK'
  $ok.Location = Pt 412 330
  $ok.Size = Sz 96 34
  $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $dlg.AcceptButton = $ok
  $dlg.Controls.Add($ok)

  $cancel = New-Object System.Windows.Forms.Button
  $cancel.Text = 'Cancelar'
  $cancel.Location = Pt 516 330
  $cancel.Size = Sz 96 34
  $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $dlg.CancelButton = $cancel
  $dlg.Controls.Add($cancel)

  $result = $dlg.ShowDialog()
  if ($result -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
  return $tb.Text
}

function Prompt-OneLine([string]$title, [string]$labelText, [string]$initial) {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $dlg = New-Object System.Windows.Forms.Form
  $dlg.Text = $title
  $dlg.Size = Sz 620 170
  $dlg.StartPosition = 'CenterParent'
  $dlg.FormBorderStyle = 'FixedDialog'
  $dlg.MaximizeBox = $false
  $dlg.MinimizeBox = $false

  $lbl = New-Object System.Windows.Forms.Label
  $lbl.AutoSize = $true
  $lbl.Location = Pt 12 12
  $lbl.Text = $labelText
  $dlg.Controls.Add($lbl)

  $tb = New-Object System.Windows.Forms.TextBox
  $tb.Location = Pt 12 40
  $tb.Size = Sz 580 24
  $tb.Text = $initial
  $dlg.Controls.Add($tb)

  $ok = New-Object System.Windows.Forms.Button
  $ok.Text = 'OK'
  $ok.Location = Pt 392 80
  $ok.Size = Sz 96 34
  $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $dlg.AcceptButton = $ok
  $dlg.Controls.Add($ok)

  $cancel = New-Object System.Windows.Forms.Button
  $cancel.Text = 'Cancelar'
  $cancel.Location = Pt 496 80
  $cancel.Size = Sz 96 34
  $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $dlg.CancelButton = $cancel
  $dlg.Controls.Add($cancel)

  $result = $dlg.ShowDialog()
  if ($result -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
  return $tb.Text
}

try {
  Reset-Logs | Out-Null
  Write-Log 'Inicio selector GUI (v13).' | Out-Null

  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $repo = Get-RepoRoot
  $gitExe = Find-GitExe
  if ([string]::IsNullOrWhiteSpace($gitExe)) { throw 'No encuentro git.exe (Git for Windows).' }

  $configPath = Join-Path $repo 'lifecal_selector_config.json'
  $cfg = Load-JsonObject $configPath

  if ($cfg.ContainsKey('backupDir') -and -not [string]::IsNullOrWhiteSpace([string]$cfg['backupDir'])) {
    $backupDir = [string]$cfg['backupDir']
  } else {
    $backupDir = Get-DefaultBackupDir $repo
  }

  $target = Join-Path $repo 'app\year\route.tsx'
  $stylePath = Join-Path $repo 'app\year\style.json'

  if (-not (Test-Path (Split-Path -Parent $target))) { throw 'No encuentro app\year. Ejecuta esto desde la raiz del repo.' }
  if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Force -Path $backupDir | Out-Null }

  $descPath = Join-Path $backupDir 'route_descriptions.json'
  $descMap = Load-JsonObject $descPath

  function List-Backups() {
    if (-not (Test-Path $backupDir)) { return @() }
    return (Get-ChildItem -Path $backupDir -Filter *.tsx -File | Sort-Object Name | Select-Object -ExpandProperty Name)
  }

  function Update-Description([System.Windows.Forms.ListBox]$list, [System.Windows.Forms.TextBox]$descBox) {
    if ($null -eq $list.SelectedItem) { $descBox.Text = ''; return }
    $file = $list.SelectedItem.ToString()
    $desc = $null
    if ($descMap.ContainsKey($file)) { $desc = [string]$descMap[$file] }
    else {
      $inline = Try-ParseInlineDesc (Join-Path $backupDir $file)
      if (-not [string]::IsNullOrWhiteSpace($inline)) { $desc = $inline }
    }
    if ([string]::IsNullOrWhiteSpace($desc)) { $desc = "Sin descripcion.`r`n`r`nTip: pulsa 'Editar resumen' y se guarda en:`r`n$descPath" }
    $descBox.Text = $desc
  }

  function Refresh-List([System.Windows.Forms.ListBox]$list, [System.Windows.Forms.TextBox]$descBox, [string]$keepFile) {
    $items = List-Backups
    $list.BeginUpdate(); $list.Items.Clear(); [void]$list.Items.AddRange($items); $list.EndUpdate()
    if ($items.Count -eq 0) { $descBox.Text = "No hay .tsx en: $backupDir"; return }
    if (-not [string]::IsNullOrWhiteSpace($keepFile) -and $items -contains $keepFile) { $list.SelectedItem = $keepFile } else { $list.SelectedIndex = 0 }
    Update-Description $list $descBox
  }

  # UI
  $form = New-Object System.Windows.Forms.Form
  $form.Text = 'LifeCal - selector route.tsx + estilo'
  $form.Size = Sz 980 820
  $form.StartPosition = 'CenterScreen'
  $form.FormBorderStyle = 'FixedDialog'
  $form.MaximizeBox = $false

  $label = New-Object System.Windows.Forms.Label
  $label.AutoSize = $true
  $label.Location = Pt 16 12
  $label.Text = "Repo: $repo`r`nBackups: $backupDir`r`nDestino: $target`r`nEstilo: $stylePath`r`nGit: $gitExe"
  $form.Controls.Add($label)

  $btnConfig = New-Object System.Windows.Forms.Button
  $btnConfig.Text = 'Config...'
  $btnConfig.Location = Pt 860 14
  $btnConfig.Size = Sz 96 30
  $form.Controls.Add($btnConfig)

  $btnStyle = New-Object System.Windows.Forms.Button
  $btnStyle.Text = 'Editar estilo'
  $btnStyle.Location = Pt 860 50
  $btnStyle.Size = Sz 96 30
  $form.Controls.Add($btnStyle)

  $listLabel = New-Object System.Windows.Forms.Label
  $listLabel.AutoSize = $true
  $listLabel.Location = Pt 16 110
  $listLabel.Text = 'Versiones (.tsx):'
  $form.Controls.Add($listLabel)

  $list = New-Object System.Windows.Forms.ListBox
  $list.Location = Pt 16 132
  $list.Size = Sz 940 290
  $list.Font = New-Object System.Drawing.Font('Consolas', 10)
  $form.Controls.Add($list)

  $descLabel = New-Object System.Windows.Forms.Label
  $descLabel.AutoSize = $true
  $descLabel.Location = Pt 16 432
  $descLabel.Text = 'Resumen:'
  $form.Controls.Add($descLabel)

  $descBox = New-Object System.Windows.Forms.TextBox
  $descBox.Location = Pt 16 454
  $descBox.Size = Sz 940 180
  $descBox.Multiline = $true
  $descBox.ReadOnly = $true
  $descBox.ScrollBars = 'Vertical'
  $descBox.Font = New-Object System.Drawing.Font('Consolas', 9)
  $form.Controls.Add($descBox)

  $btnRowY = 646

  $btnRefresh = New-Object System.Windows.Forms.Button
  $btnRefresh.Text = 'Refrescar lista'
  $btnRefresh.Location = Pt 16 $btnRowY
  $btnRefresh.Size = Sz 140 34
  $form.Controls.Add($btnRefresh)

  $chkAuto = New-Object System.Windows.Forms.CheckBox
  $chkAuto.Text = 'Auto-refrescar'
  $chkAuto.Location = Pt 170 ($btnRowY + 7)
  $chkAuto.Size = Sz 140 24
  $form.Controls.Add($chkAuto)

  $btnPreview = New-Object System.Windows.Forms.Button
  $btnPreview.Text = 'Vista previa (Notepad)'
  $btnPreview.Location = Pt 320 $btnRowY
  $btnPreview.Size = Sz 180 34
  $form.Controls.Add($btnPreview)

  $btnEdit = New-Object System.Windows.Forms.Button
  $btnEdit.Text = 'Editar resumen'
  $btnEdit.Location = Pt 510 $btnRowY
  $btnEdit.Size = Sz 140 34
  $form.Controls.Add($btnEdit)

  $btnSnapshot = New-Object System.Windows.Forms.Button
  $btnSnapshot.Text = 'Snapshot del route actual'
  $btnSnapshot.Location = Pt 660 $btnRowY
  $btnSnapshot.Size = Sz 176 34
  $form.Controls.Add($btnSnapshot)

  $btnApplyY = 706

  $btnApply = New-Object System.Windows.Forms.Button
  $btnApply.Text = 'Aplicar (copiar a route.tsx)'
  $btnApply.Location = Pt 16 $btnApplyY
  $btnApply.Size = Sz 220 36
  $form.Controls.Add($btnApply)

  $chkPush = New-Object System.Windows.Forms.CheckBox
  $chkPush.Text = 'Hacer git add/commit/push despues'
  $chkPush.Location = Pt 252 ($btnApplyY + 9)
  $chkPush.Size = Sz 260 24
  $form.Controls.Add($chkPush)

  $btnPushOnly = New-Object System.Windows.Forms.Button
  $btnPushOnly.Text = 'Git push cambios'
  $btnPushOnly.Location = Pt 520 $btnApplyY
  $btnPushOnly.Size = Sz 170 36
  $form.Controls.Add($btnPushOnly)

  $btnPull = New-Object System.Windows.Forms.Button
  $btnPull.Text = 'Git pull'
  $btnPull.Location = Pt 700 $btnApplyY
  $btnPull.Size = Sz 110 36
  $form.Controls.Add($btnPull)

  $btnClose = New-Object System.Windows.Forms.Button
  $btnClose.Text = 'Cerrar'
  $btnClose.Location = Pt 846 $btnApplyY
  $btnClose.Size = Sz 110 36
  $form.Controls.Add($btnClose)

  $status = New-Object System.Windows.Forms.Label
  $status.AutoSize = $true
  $status.Location = Pt 16 760
  $status.Text = ''
  $form.Controls.Add($status)

  $timer = New-Object System.Windows.Forms.Timer
  $timer.Interval = 2000

  Refresh-List $list $descBox $null

  $list.Add_SelectedIndexChanged({ Update-Description $list $descBox })
  $btnStyle.Add_Click({ Show-StyleEditor $stylePath $gitExe $repo })

  $btnRefresh.Add_Click({
    $keep = $null
    if ($null -ne $list.SelectedItem) { $keep = $list.SelectedItem.ToString() }
    Refresh-List $list $descBox $keep
    $status.Text = "Lista refrescada: " + (Get-Date -Format 'HH:mm:ss')
  })

  $chkAuto.Add_CheckedChanged({ if ($chkAuto.Checked) { $timer.Start() } else { $timer.Stop() } })
  $timer.Add_Tick({
    $keep = $null
    if ($null -ne $list.SelectedItem) { $keep = $list.SelectedItem.ToString() }
    Refresh-List $list $descBox $keep
  })

  $btnPreview.Add_Click({
    if ($null -eq $list.SelectedItem) { return }
    $src = Join-Path $backupDir $list.SelectedItem.ToString()
    if (-not (Test-Path $src)) { return }
    Start-Process notepad.exe $src | Out-Null
  })

  $btnEdit.Add_Click({
    if ($null -eq $list.SelectedItem) { return }
    $file = $list.SelectedItem.ToString()
    $current = ''
    if ($descMap.ContainsKey($file)) { $current = [string]$descMap[$file] }

    $newText = Prompt-Multiline 'Editar resumen' ("Archivo: $file`r`nResumen (se guarda en route_descriptions.json):") $current
    if ($null -eq $newText) { return }
    $descMap[$file] = $newText.Trim()
    Save-JsonObject $descMap $descPath
    Update-Description $list $descBox
    $status.Text = "Resumen guardado para: $file"
  })

  $btnSnapshot.Add_Click({
    try {
      if (-not (Test-Path $target)) { [System.Windows.Forms.MessageBox]::Show("No existe: $target", 'LifeCal') | Out-Null; return }
      $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
      $defaultName = "snapshot_$stamp.tsx"
      $name = Prompt-OneLine 'Snapshot' "Nombre del .tsx en backups:" $defaultName
      if ($null -eq $name) { return }
      $name = $name.Trim()
      if ([string]::IsNullOrWhiteSpace($name)) { return }
      if (-not $name.ToLower().EndsWith('.tsx')) { $name = $name + '.tsx' }
      $dest = Join-Path $backupDir $name
      Copy-Item -Path $target -Destination $dest -Force
      Refresh-List $list $descBox $name
      $status.Text = "Snapshot creado: $name"
    } catch {
      [System.Windows.Forms.MessageBox]::Show(("Error snapshot:`r`n{0}" -f $_.Exception.Message), 'LifeCal') | Out-Null
    }
  })

  $btnPushOnly.Add_Click({
    $stamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
    $res = Git-CommitPush $gitExe $repo ("GUI push $stamp")
    [System.Windows.Forms.MessageBox]::Show($res.Msg, 'LifeCal') | Out-Null
  })

  $btnApply.Add_Click({
    if ($null -eq $list.SelectedItem) { return }
    $file = $list.SelectedItem.ToString()
    $src = Join-Path $backupDir $file
    if (-not (Test-Path $src)) { [System.Windows.Forms.MessageBox]::Show("No existe: $src", 'LifeCal') | Out-Null; return }
    Copy-Item -Path $src -Destination $target -Force
    $status.Text = "Aplicado: $file"
    if ($chkPush.Checked) {
      $stamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
      $res = Git-CommitPush $gitExe $repo ("Switch route $file $stamp")
      [System.Windows.Forms.MessageBox]::Show($res.Msg, 'LifeCal') | Out-Null
    }
  })

  $btnPull.Add_Click({
    $res = Run-Git $gitExe $repo 'pull'
    $msg = $res.Stdout
    if (-not [string]::IsNullOrWhiteSpace($res.Stderr)) { $msg = $msg + "`r`n`r`n" + $res.Stderr }
    if ([string]::IsNullOrWhiteSpace($msg)) { $msg = '(sin salida)' }
    [System.Windows.Forms.MessageBox]::Show($msg, 'Git pull') | Out-Null
  })

  $btnConfig.Add_Click({
    $hint = "Ruta actual backups:`r`n$backupDir`r`n`r`nPon una ruta nueva."
    $newDir = Prompt-OneLine 'Config backups' $hint $backupDir
    if ($null -eq $newDir) { return }
    $newDir = $newDir.Trim()
    if ([string]::IsNullOrWhiteSpace($newDir)) { return }
    if (-not (Test-Path $newDir)) { New-Item -ItemType Directory -Force -Path $newDir | Out-Null }
    $cfg['backupDir'] = $newDir
    Save-JsonObject $cfg $configPath
    $backupDir = $newDir
    $descPath = Join-Path $backupDir 'route_descriptions.json'
    $descMap = Load-JsonObject $descPath
    $label.Text = "Repo: $repo`r`nBackups: $backupDir`r`nDestino: $target`r`nEstilo: $stylePath`r`nGit: $gitExe"
    Refresh-List $list $descBox $null
    $status.Text = 'Config actualizada.'
  })

  $btnClose.Add_Click({ try { $timer.Stop() } catch {}; $form.Close() })

  [void]$form.ShowDialog()
  exit 0
}
catch {
  $p = Write-Log ("FATAL: " + $_.Exception.ToString())
  try {
    Add-Type -AssemblyName System.Windows.Forms
    $paths = Get-LogPaths
    [System.Windows.Forms.MessageBox]::Show(
      ("Fallo la GUI.`r`n`r`nError: {0}`r`n`r`nLog repo: {1}`r`nLog temp: {2}" -f $_.Exception.Message, $paths.Repo, $paths.Temp),
      'LifeCal',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
  } catch {}
  exit 1
}
