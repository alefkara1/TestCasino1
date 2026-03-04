# Golden Crown: 1) logo no bg  2) crown only no bg no text (fast LockBits)
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.InteropServices

$root = $PSScriptRoot
$assetsPath = Join-Path $root 'assets'
$srcPath = Join-Path $assetsPath 'golden-crown-source.png'
$out1 = Join-Path $root 'golden-crown-logo.png'
$out2 = Join-Path $root 'golden-crown-crown-only.png'

if (-not (Test-Path $srcPath)) {
  Write-Warning "File not found: $srcPath"
  exit 1
}

$bmp = [Drawing.Bitmap]::FromFile($srcPath)
$w = $bmp.Width
$h = $bmp.Height

$rect = [Drawing.Rectangle]::new(0, 0, $w, $h)
$srcData = $bmp.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
$noBg = New-Object Drawing.Bitmap $w, $h, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$dstData = $noBg.LockBits($rect, [Drawing.Imaging.ImageLockMode]::WriteOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)

$srcPtr = $srcData.Scan0
$dstPtr = $dstData.Scan0
$bytes = [Math]::Abs($srcData.Stride) * $h
$buffer = [byte[]]::new($bytes)
[System.Runtime.InteropServices.Marshal]::Copy($srcPtr, $buffer, 0, $bytes)

for ($i = 0; $i -lt $buffer.Length; $i += 4) {
  $b = $buffer[$i]; $g = $buffer[$i+1]; $r = $buffer[$i+2]; $a = $buffer[$i+3]
  $isGreen = ($g -gt 60 -and $r -lt 100 -and $b -lt 100) -or ($g -gt $r -and $g -gt $b -and $g -lt 200)
  if ($isGreen) {
    $buffer[$i+3] = 0
  }
}
[System.Runtime.InteropServices.Marshal]::Copy($buffer, 0, $dstPtr, $bytes)

$bmp.UnlockBits($srcData)
$noBg.UnlockBits($dstData)
$bmp.Dispose()

$noBg.Save($out1, [Drawing.Imaging.ImageFormat]::Png)
Write-Output "Saved: $out1"

$crownH = [int]($h * 0.52)
$crownOnly = $noBg.Clone([Drawing.Rectangle]::new(0, 0, $w, $crownH), $noBg.PixelFormat)
$crownOnly.Save($out2, [Drawing.Imaging.ImageFormat]::Png)
$crownOnly.Dispose()
Write-Output "Saved: $out2"

$noBg.Dispose()
Write-Output "Done."
