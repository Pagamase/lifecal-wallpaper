$ErrorActionPreference = 'Stop'

function Write-Log([string]$msg) {
  $logPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'lifecal_gui_error.log'
  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  Add-Content -Path $logPath -Value ("[{0}] {1}" -f $stamp, $msg)
}

# NOTA:
# Dejo el texto en espanol SIN tildes para evitar problemas de codificacion
# en PowerShell/Windows (codepages) como el que te rompio antes el script.

function Get-RouteDescription([string]$fileName) {
  $map = @{
    '01_route_year_19_and_birthdays_queryparam.tsx' = @"
EXPERIMENTAL.
- Marca el dia 19 de cada mes con anillo rojo.
- El 19 de febrero es rojo relleno (circulo solido).
- Cumples por query param: b=MM-DD,MM-DD
- Footer: 'Xd left · Y%'.
- Semana empieza en lunes.
"@
    '02_route_year_weekend_blue_variant.tsx' = @"
Anio normal. Sin cumples. Sin dia 19 especial.
- Findes en tono azulado (sabado+domingo).
- Hoy en naranja.
- Footer: 'Xd left · Y%'.
- Semana empieza en lunes.
"@
    '03_route_year_sat_dark_sun_red.tsx' = @"
Anio normal. Sin cumples.
- Sabado: gris mas oscuro.
- Domingo: rojo.
- Hoy: naranja.
- Footer: 'Xd left · Y%'.
- Semana empieza en lunes.
"@
    '04_route_year_sat_light_sun_red.tsx' = @"
Anio normal. Sin cumples.
- Sabado: gris mas claro (se ve mas).
- Domingo: rojo.
- Hoy: naranja.
- Footer: 'Xd left · Y%'.
- Semana empieza en lunes.
"@
    '05_route_year_sat_light_sun_red_footer_glued.tsx' = @"
Igual que 04 + ajuste de layout:
- El texto de abajo queda mas pegado al calendario.
- Tamano por defecto 1179x2556.
- Sabado gris claro. Domingo rojo. Hoy naranja.
"@
    '06_route_year_progress_bar.tsx' = @"
Anade barra de progreso (progreso del anio):
- Sabado gris claro. Domingo rojo.
- Hoy: naranja.
- Footer: 'Xd left' a la izquierda y 'Y%' a la derecha.
- Barra fina debajo del footer.
"@
    '07_route_year_progress_bar_birthdays_red_ring.tsx' = @"
Barra de progreso + cumples:
- Cumples fijos en el codigo (set MM-DD).
- Cumples con anillo rojo exterior.
- Domingo sigue rojo; si un cumple cae en domingo, el interior es mas oscuro para que el anillo se vea.
- Hoy: naranja.
"@
    '08_route_year_progress_bar_birthdays_today_halo.tsx' = @"
Barra + cumples + halo para HOY:
- Cumples: anillo rojo exterior.
- Hoy: naranja con halo claro (ayuda cuando HOY cae en domingo rojo).
- Domingo rojo; si es cumple en domingo, interior mas oscuro para ver el anillo.
"@
  }

  if ($map.ContainsKey($fileName)) { return $map[$fileName] }
  return "No hay descripcion para este archivo todavia."
}

try {
  # Reset log
  $logPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'lifecal_gui_error.log'
  if (Test-Path $logPath) { Remove-Item $logPath -Force }

  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  # ==============================
  # Rutas
  # ==============================
  $repo = Split-Path -Parent $MyInvocation.MyCommand.Path
  $backupDir = Join-Path $repo 'lifecal_route_backups'
  if (-not (Test-Path $backupDir)) {
    $backupDir = Join-Path $repo 'route_backups'
  }

  $target = Join-Path $repo 'app\year\route.tsx'

  if (-not (Test-Path $backupDir)) {
    [System.Windows.Forms.MessageBox]::Show(
      "No encuentro la carpeta de backups.`r`nCrea una en la raiz del repo:`r`n- lifecal_route_backups`r`n- route_backups",
      'LifeCal Selector',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 2
  }

  if (-not (Test-Path (Split-Path -Parent $target))) {
    [System.Windows.Forms.MessageBox]::Show(
      "No encuentro app\year en esta carpeta.`r`nEjecuta esto desde la raiz del repo lifecal-wallpaper",
      'LifeCal Selector',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 3
  }

  # Orden preferido
  $preferred = @(
    '01_route_year_19_and_birthdays_queryparam.tsx',
    '02_route_year_weekend_blue_variant.tsx',
    '03_route_year_sat_dark_sun_red.tsx',
    '04_route_year_sat_light_sun_red.tsx',
    '05_route_year_sat_light_sun_red_footer_glued.tsx',
    '06_route_year_progress_bar.tsx',
    '07_route_year_progress_bar_birthdays_red_ring.tsx',
    '08_route_year_progress_bar_birthdays_today_halo.tsx'
  )

  $existingPreferred = $preferred | Where-Object { Test-Path (Join-Path $backupDir $_) }
  $all = Get-ChildItem -Path $backupDir -Filter *.tsx -File | Select-Object -ExpandProperty Name

  if ($existingPreferred.Count -gt 0) {
    $items = $existingPreferred
  } else {
    $items = $all | Sort-Object
  }

  if ($items.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show(
      "No hay archivos .tsx en: $backupDir",
      'LifeCal Selector',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 4
  }

  # ==============================
  # UI
  # ==============================
  $form = New-Object System.Windows.Forms.Form
  $form.Text = 'LifeCal - selector route.tsx'
  $form.Size = New-Object System.Drawing.Size(780, 650)
  $form.StartPosition = 'CenterScreen'
  $form.FormBorderStyle = 'FixedDialog'
  $form.MaximizeBox = $false

  $label = New-Object System.Windows.Forms.Label
  $label.AutoSize = $true
  $label.Location = New-Object System.Drawing.Point(16, 16)
  $label.Text = "Repo: $repo`r`nBackups: $backupDir`r`nDestino: $target"
  $form.Controls.Add($label)

  $list = New-Object System.Windows.Forms.ListBox
  $list.Location = New-Object System.Drawing.Point(16, 80)
  $list.Size = New-Object System.Drawing.Size(740, 230)
  $list.Font = New-Object System.Drawing.Font('Consolas', 10)
  [void]$list.Items.AddRange($items)
  $list.SelectedIndex = 0
  $form.Controls.Add($list)

  $descLabel = New-Object System.Windows.Forms.Label
  $descLabel.AutoSize = $true
  $descLabel.Location = New-Object System.Drawing.Point(16, 320)
  $descLabel.Text = "Resumen:"
  $form.Controls.Add($descLabel)

  $descBox = New-Object System.Windows.Forms.TextBox
  $descBox.Location = New-Object System.Drawing.Point(16, 342)
  $descBox.Size = New-Object System.Drawing.Size(740, 150)
  $descBox.Multiline = $true
  $descBox.ReadOnly = $true
  $descBox.ScrollBars = 'Vertical'
  $descBox.Font = New-Object System.Drawing.Font('Consolas', 9)
  $form.Controls.Add($descBox)

  $btnPreview = New-Object System.Windows.Forms.Button
  $btnPreview.Text = 'Vista previa (Notepad)'
  $btnPreview.Location = New-Object System.Drawing.Point(16, 505)
  $btnPreview.Size = New-Object System.Drawing.Size(180, 34)
  $form.Controls.Add($btnPreview)

  $btnApply = New-Object System.Windows.Forms.Button
  $btnApply.Text = 'Aplicar (copiar a route.tsx)'
  $btnApply.Location = New-Object System.Drawing.Point(210, 505)
  $btnApply.Size = New-Object System.Drawing.Size(220, 34)
  $form.Controls.Add($btnApply)

  $chkPush = New-Object System.Windows.Forms.CheckBox
  $chkPush.Text = 'Hacer git add/commit/push despues'
  $chkPush.Location = New-Object System.Drawing.Point(450, 512)
  $chkPush.Size = New-Object System.Drawing.Size(300, 24)
  $form.Controls.Add($chkPush)

  $btnClose = New-Object System.Windows.Forms.Button
  $btnClose.Text = 'Cerrar'
  $btnClose.Location = New-Object System.Drawing.Point(16, 550)
  $btnClose.Size = New-Object System.Drawing.Size(120, 34)
  $form.Controls.Add($btnClose)

  $status = New-Object System.Windows.Forms.Label
  $status.AutoSize = $true
  $status.Location = New-Object System.Drawing.Point(150, 558)
  $status.Text = ''
  $form.Controls.Add($status)

  # ==============================
  # Helpers
  # ==============================
  function Update-Description() {
    if ($null -eq $list.SelectedItem) { return }
    $file = $list.SelectedItem.ToString()
    $descBox.Text = Get-RouteDescription $file
  }

  Update-Description
  $list.Add_SelectedIndexChanged({ Update-Description })

  # ==============================
  # Actions
  # ==============================
  $btnPreview.Add_Click({
    if ($null -eq $list.SelectedItem) { return }
    $src = Join-Path $backupDir $list.SelectedItem.ToString()
    if (-not (Test-Path $src)) { return }
    Start-Process notepad.exe $src | Out-Null
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
        Set-Location $repo

        $dirty = & git status --porcelain
        if ([string]::IsNullOrWhiteSpace($dirty)) {
          [System.Windows.Forms.MessageBox]::Show('No hay cambios en git. Nada que subir.', 'LifeCal Selector') | Out-Null
          return
        }

        & git add -A | Out-Null
        $stamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
        $msg = "Switch route $file $stamp"
        & git commit -m $msg | Out-Null
        & git push | Out-Null

        [System.Windows.Forms.MessageBox]::Show('Push hecho.', 'LifeCal Selector') | Out-Null
      } catch {
        [System.Windows.Forms.MessageBox]::Show(("Error git:`r`n{0}" -f $_.Exception.Message), 'LifeCal Selector') | Out-Null
        Write-Log ("git error: " + $_.Exception.ToString())
      }
    }
  })

  $btnClose.Add_Click({ $form.Close() })

  [void]$form.ShowDialog()
  exit 0
}
catch {
  try { Write-Log ("FATAL: " + $_.Exception.ToString()) } catch {}
  try {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
      'Fallo la GUI. Mira lifecal_gui_error.log en la raiz del repo.',
      'LifeCal Selector',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
  } catch {}
  exit 1
}
