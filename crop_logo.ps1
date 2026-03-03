Add-Type -AssemblyName System.Drawing

$assetsPath = Join-Path $PSScriptRoot 'assets'
if (-not (Test-Path $assetsPath)) {
  New-Item -ItemType Directory -Path $assetsPath -Force | Out-Null
}
# Обрабатываем все PNG и JPG в папке assets (в т.ч. новые загруженные логотипы)
$logoFiles = @(Get-ChildItem -Path $assetsPath -File | Where-Object { $_.Extension -match '\.(png|jpe?g)$' } | Select-Object -ExpandProperty Name)

# Порог: пиксели темнее этого считаются фоном (будут прозрачными). 70 — чтобы убирать и тёмно-синий фон.
$bgThreshold = 70

foreach ($fileName in $logoFiles) {
  $path = Join-Path $assetsPath $fileName
  if (-not (Test-Path $path)) { continue }

  try {
  $bmp = [Drawing.Bitmap]::FromFile($path)
  $w = $bmp.Width
  $h = $bmp.Height

  # Ищем границы контента (не фон и не прозрачное)
  $x1 = $w
  $y1 = $h
  $x2 = 0
  $y2 = 0
  for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      $c = $bmp.GetPixel($x, $y)
      $isContent = $c.A -gt 10 -and ($c.R -gt $bgThreshold -or $c.G -gt $bgThreshold -or $c.B -gt $bgThreshold)
      if ($isContent) {
        if ($x -lt $x1) { $x1 = $x }
        if ($x -gt $x2) { $x2 = $x }
        if ($y -lt $y1) { $y1 = $y }
        if ($y -gt $y2) { $y2 = $y }
      }
    }
  }

  $pad = [Math]::Max([Math]::Max($x2 - $x1, $y2 - $y1) / 10, 4)
  $left = [Math]::Max(0, $x1 - $pad)
  $top = [Math]::Max(0, $y1 - $pad)
  $rw = [Math]::Min($w - $left, $x2 - $x1 + 2 * $pad)
  $rh = [Math]::Min($h - $top, $y2 - $y1 + 2 * $pad)

  # Новый bitmap с прозрачностью (ARGB)
  $out = New-Object Drawing.Bitmap $rw, $rh, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [Drawing.Graphics]::FromImage($out)
  $g.Clear([Drawing.Color]::Transparent)
  $g.Dispose()

  # Копируем пиксели: фон делаем прозрачным
  for ($dy = 0; $dy -lt $rh; $dy++) {
    for ($dx = 0; $dx -lt $rw; $dx++) {
      $sx = $left + $dx
      $sy = $top + $dy
      $c = $bmp.GetPixel($sx, $sy)
      $isBg = $c.A -lt 15 -or ($c.R -le $bgThreshold -and $c.G -le $bgThreshold -and $c.B -le $bgThreshold)
      if ($isBg) {
        $out.SetPixel($dx, $dy, [Drawing.Color]::FromArgb(0, 0, 0, 0))
      } else {
        $out.SetPixel($dx, $dy, $c)
      }
    }
  }

  $bmp.Dispose()
  # Сохраняем всегда как PNG (прозрачность). Если был JPG — сохраняем в .png и удаляем исходник
  $ext = [IO.Path]::GetExtension($fileName).ToLowerInvariant()
  $savePath = if ($ext -match '^\.jpe?g$') {
    [IO.Path]::ChangeExtension($path, '.png')
  } else {
    $path
  }
  $out.Save($savePath, [Drawing.Imaging.ImageFormat]::Png)
  $out.Dispose()
  if ($savePath -ne $path) { Remove-Item $path -Force }
  Write-Output "OK: $fileName"
  } catch {
    Write-Warning "Skip $fileName : $_"
  }
}

Write-Output 'Done'
