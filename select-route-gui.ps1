$ErrorActionPreference = 'Stop'

# Texto en espanol SIN tildes/enye para evitar problemas de codificacion en PowerShell/Windows.
# v10 FIX:
# Tu PowerShell no soporta ConvertFrom-Json -AsHashtable (tipico en PowerShell 5.1).
# Implementamos una conversion a hashtable compatible.

function Get-RepoRoot() {
  if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { return $PSScriptRoot }
  if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) { return Split-Path -Parent $PSCommandPath }
  return (Get-Location).Path
}

function Pt([int]$x, [int]$y) { New-Object System.Drawing.Point -ArgumentList $x, $y }
function Sz([int]$w, [int]$h) { New-Object System.Drawing.Size -ArgumentList $w, $h }

function Get-LogPaths() {
  $repo = Get-RepoRoot
  $repoLog = Join-Path $repo 'lifecal_gui_error.log'
  $tempLog = Join-Path $env:TEMP 'lifecal_gui_error.log'
  return @{ Repo = $repoLog; Temp = $tempLog }
}

function Write-Log([string]$msg) {
  $paths = Get-LogPaths
  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $line = ("[{0}] {1}" -f $stamp, $msg)

  try {
    Add-Content -Path $paths.Repo -Value $line -Encoding utf8
    return $paths.Repo
  } catch {
    try {
      Add-Content -Path $paths.Temp -Value $line -Encoding utf8
      return $paths.Temp
    } catch {
      return $null
    }
  }
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

  # Ya es diccionario/hashtable
  if ($obj -is [System.Collections.IDictionary]) { return $obj }

  # Arrays/Listas (pero no string)
  if (($obj -is [System.Collections.IEnumerable]) -and -not ($obj -is [string])) {
    $arr = @()
    foreach ($item in $obj) { $arr += (To-Hashtable $item) }
    return $arr
  }

  # PSCustomObject / PSObject -> hashtable
  if ($obj -is [psobject]) {
    $ht = @{}
    foreach ($p in $obj.PSObject.Properties) {
      $ht[$p.Name] = (To-Hashtable $p.Value)
    }
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
    foreach ($l in $lines) {
      if ($l -match '^\s*//\s*DESC\s*:\s*(.*)$') { $descLines += $Matches[1] }
    }
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

function Run-Git([string]$repo, [string]$args) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'git'
  $psi.Arguments = $args
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

  return @{ ExitCode = $p.ExitCode; Stdout = $out; Stderr = $err }
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
  Write-Log "Inicio selector GUI." | Out-Null

  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $repo = Get-RepoRoot
  Write-Log ("Repo root: " + $repo) | Out-Null

  $configPath = Join-Path $repo 'lifecal_selector_config.json'
  $cfg = Load-JsonObject $configPath

  $backupDir = $null
  if ($cfg.ContainsKey('backupDir') -and -not [string]::IsNullOrWhiteSpace([string]$cfg['backupDir'])) {
    $backupDir = [string]$cfg['backupDir']
  } else {
    $backupDir = Get-DefaultBackupDir $repo
  }

  $target = Join-Path $repo 'app\year\route.tsx'
  if (-not (Test-Path (Split-Path -Parent $target))) {
    Write-Log ("No encuentro app/year. Target=" + $target) | Out-Null
    [System.Windows.Forms.MessageBox]::Show(
      "No encuentro app\year en esta carpeta.`r`nEjecuta esto desde la raiz del repo lifecal-wallpaper.",
      'LifeCal Selector',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 3
  }

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

    if ([string]::IsNullOrWhiteSpace($desc)) {
      $desc = "Sin descripcion.`r`n`r`nTip: pulsa 'Editar resumen' y se guardara en:`r`n$descPath"
    }
    $descBox.Text = $desc
  }

  function Refresh-List([System.Windows.Forms.ListBox]$list, [System.Windows.Forms.TextBox]$descBox, [string]$keepFile) {
    $items = List-Backups

    $list.BeginUpdate()
    $list.Items.Clear()
    [void]$list.Items.AddRange($items)
    $list.EndUpdate()

    if ($items.Count -eq 0) { $descBox.Text = "No hay .tsx en: $backupDir"; return }

    if (-not [string]::IsNullOrWhiteSpace($keepFile) -and $items -contains $keepFile) { $list.SelectedItem = $keepFile }
    else { $list.SelectedIndex = 0 }

    Update-Description $list $descBox
  }

  # UI
  $form = New-Object System.Windows.Forms.Form
  $form.Text = 'LifeCal - selector route.tsx (dinamico)'
  $form.Size = Sz 860 720
  $form.StartPosition = 'CenterScreen'
  $form.FormBorderStyle = 'FixedDialog'
  $form.MaximizeBox = $false

  $label = New-Object System.Windows.Forms.Label
  $label.AutoSize = $true
  $label.Location = Pt 16 12
  $label.Text = "Repo: $repo`r`nBackups: $backupDir`r`nDestino: $target"
  $form.Controls.Add($label)

  $btnConfig = New-Object System.Windows.Forms.Button
  $btnConfig.Text = 'Config...'
  $btnConfig.Location = Pt 740 14
  $btnConfig.Size = Sz 96 30
  $form.Controls.Add($btnConfig)

  $listLabel = New-Object System.Windows.Forms.Label
  $listLabel.AutoSize = $true
  $listLabel.Location = Pt 16 70
  $listLabel.Text = 'Versiones (.tsx):'
  $form.Controls.Add($listLabel)

  $list = New-Object System.Windows.Forms.ListBox
  $list.Location = Pt 16 92
  $list.Size = Sz 820 260
  $list.Font = New-Object System.Drawing.Font('Consolas', 10)
  $form.Controls.Add($list)

  $descLabel = New-Object System.Windows.Forms.Label
  $descLabel.AutoSize = $true
  $descLabel.Location = Pt 16 362
  $descLabel.Text = 'Resumen:'
  $form.Controls.Add($descLabel)

  $descBox = New-Object System.Windows.Forms.TextBox
  $descBox.Location = Pt 16 384
  $descBox.Size = Sz 820 160
  $descBox.Multiline = $true
  $descBox.ReadOnly = $true
  $descBox.ScrollBars = 'Vertical'
  $descBox.Font = New-Object System.Drawing.Font('Consolas', 9)
  $form.Controls.Add($descBox)

  $btnRowY = 556

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

  $btnApplyY = 600

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

  $btnPull = New-Object System.Windows.Forms.Button
  $btnPull.Text = 'Git pull (actualizar repo)'
  $btnPull.Location = Pt 520 $btnApplyY
  $btnPull.Size = Sz 200 36
  $form.Controls.Add($btnPull)

  $btnClose = New-Object System.Windows.Forms.Button
  $btnClose.Text = 'Cerrar'
  $btnClose.Location = Pt 736 $btnApplyY
  $btnClose.Size = Sz 100 36
  $form.Controls.Add($btnClose)

  $status = New-Object System.Windows.Forms.Label
  $status.AutoSize = $true
  $status.Location = Pt 16 650
  $status.Text = ''
  $form.Controls.Add($status)

  $timer = New-Object System.Windows.Forms.Timer
  $timer.Interval = 2000

  # Init
  Refresh-List $list $descBox $null

  # Events
  $list.Add_SelectedIndexChanged({ Update-Description $list $descBox })

  $btnRefresh.Add_Click({
    $keep = $null
    if ($null -ne $list.SelectedItem) { $keep = $list.SelectedItem.ToString() }
    Refresh-List $list $descBox $keep
    $status.Text = "Lista refrescada: " + (Get-Date -Format 'HH:mm:ss')
  })

  $chkAuto.Add_CheckedChanged({
    if ($chkAuto.Checked) { $timer.Start() } else { $timer.Stop() }
  })

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

    $newText = Prompt-Multiline 'Editar resumen' ("Archivo: $file`r`nEscribe un resumen (se guarda en route_descriptions.json):") $current
    if ($null -eq $newText) { return }

    $descMap[$file] = $newText.Trim()
    Save-JsonObject $descMap $descPath
    Update-Description $list $descBox
    $status.Text = "Resumen guardado para: $file"
  })

  $btnSnapshot.Add_Click({
    try {
      if (-not (Test-Path $target)) {
        [System.Windows.Forms.MessageBox]::Show("No existe: $target", 'LifeCal Selector') | Out-Null
        return
      }

      $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
      $defaultName = "snapshot_$stamp.tsx"
      $name = Prompt-OneLine 'Snapshot' "Nombre del archivo .tsx a crear en backups:" $defaultName
      if ($null -eq $name) { return }

      $name = $name.Trim()
      if ([string]::IsNullOrWhiteSpace($name)) { return }
      if (-not $name.ToLower().EndsWith('.tsx')) { $name = $name + '.tsx' }

      $dest = Join-Path $backupDir $name
      Copy-Item -Path $target -Destination $dest -Force

      Refresh-List $list $descBox $name
      $status.Text = "Snapshot creado: $name"
    } catch {
      $p = Write-Log ("Snapshot error: " + $_.Exception.ToString())
      [System.Windows.Forms.MessageBox]::Show(("Error creando snapshot:`r`n{0}`r`nLog: {1}" -f $_.Exception.Message, $p), 'LifeCal Selector') | Out-Null
    }
  })

  $btnApply.Add_Click({
    if ($null -eq $list.SelectedItem) { return }
    $file = $list.SelectedItem.ToString()
    $src = Join-Path $backupDir $file

    if (-not (Test-Path $src)) {
      [System.Windows.Forms.MessageBox]::Show("No existe: $src", 'LifeCal Selector') | Out-Null
      return
    }

    Copy-Item -Path $src -Destination $target -Force
    $status.Text = "Aplicado: $file"

    if ($chkPush.Checked) {
      try {
        $resStatus = Run-Git $repo 'status --porcelain'
        if ($resStatus.ExitCode -ne 0) {
          [System.Windows.Forms.MessageBox]::Show(("Git status fallo:`r`n{0}" -f $resStatus.Stderr), 'LifeCal Selector') | Out-Null
          return
        }
        if ([string]::IsNullOrWhiteSpace($resStatus.Stdout)) {
          [System.Windows.Forms.MessageBox]::Show('No hay cambios en git. Nada que subir.', 'LifeCal Selector') | Out-Null
          return
        }

        [void](Run-Git $repo 'add -A')
        $stamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
        $msg = "Switch route $file $stamp"
        [void](Run-Git $repo ("commit -m `"$msg`""))

        $resPush = Run-Git $repo 'push'
        if ($resPush.ExitCode -ne 0) {
          $p = Write-Log ("git push error: " + $resPush.Stderr)
          [System.Windows.Forms.MessageBox]::Show(("Git push fallo:`r`n{0}`r`nLog: {1}" -f $resPush.Stderr, $p), 'LifeCal Selector') | Out-Null
          return
        }

        [System.Windows.Forms.MessageBox]::Show('Push hecho.', 'LifeCal Selector') | Out-Null
      } catch {
        $p = Write-Log ("git error: " + $_.Exception.ToString())
        [System.Windows.Forms.MessageBox]::Show(("Error git:`r`n{0}`r`nLog: {1}" -f $_.Exception.Message, $p), 'LifeCal Selector') | Out-Null
      }
    }
  })

  $btnPull.Add_Click({
    try {
      $res = Run-Git $repo 'pull'
      $msg = $res.Stdout
      if (-not [string]::IsNullOrWhiteSpace($res.Stderr)) { $msg = $msg + "`r`n`r`n" + $res.Stderr }
      if ([string]::IsNullOrWhiteSpace($msg)) { $msg = '(sin salida)' }

      [System.Windows.Forms.MessageBox]::Show($msg, 'Git pull') | Out-Null

      $keep = $null
      if ($null -ne $list.SelectedItem) { $keep = $list.SelectedItem.ToString() }
      Refresh-List $list $descBox $keep
    } catch {
      $p = Write-Log ("git pull error: " + $_.Exception.ToString())
      [System.Windows.Forms.MessageBox]::Show(("Git pull error:`r`n{0}`r`nLog: {1}" -f $_.Exception.Message, $p), 'LifeCal Selector') | Out-Null
    }
  })

  $btnConfig.Add_Click({
    try {
      $hint = "Ruta actual backups:`r`n$backupDir`r`n`r`nPon una ruta nueva (carpeta local o red).`r`nEjemplo: \\server\share\lifecal_backups"
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

      $label.Text = "Repo: $repo`r`nBackups: $backupDir`r`nDestino: $target"
      Refresh-List $list $descBox $null
      $status.Text = 'Config actualizada.'
    } catch {
      $p = Write-Log ("config error: " + $_.Exception.ToString())
      [System.Windows.Forms.MessageBox]::Show(("Config error:`r`n{0}`r`nLog: {1}" -f $_.Exception.Message, $p), 'LifeCal Selector') | Out-Null
    }
  })

  $btnClose.Add_Click({
    try { $timer.Stop() } catch {}
    $form.Close()
  })

  Write-Log "GUI lista. Mostrando ventana." | Out-Null
  [void]$form.ShowDialog()
  Write-Log "Cerrada la GUI." | Out-Null
  exit 0
}
catch {
  $p = Write-Log ("FATAL: " + $_.Exception.ToString())
  try {
    Add-Type -AssemblyName System.Windows.Forms
    $paths = Get-LogPaths
    $extra = "Log repo: " + $paths.Repo + "`r`nLog temp: " + $paths.Temp
    [System.Windows.Forms.MessageBox]::Show(
      ("Fallo la GUI.`r`n`r`nError: {0}`r`n`r`n{1}" -f $_.Exception.Message, $extra),
      'LifeCal Selector',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
  } catch {}
  exit 1
}
