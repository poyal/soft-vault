$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$repoRoot = Split-Path -Parent $PSScriptRoot
$original = [System.Drawing.Image]::FromFile((Join-Path $repoRoot 'design/assets/app-icon.png'))
$sizes = @(16,32,48,64,128,256)
$images = [System.Collections.Generic.List[byte[]]]::new()
try {
  foreach ($size in $sizes) {
    $bitmap = [System.Drawing.Bitmap]::new($size,$size,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $stream = [System.IO.MemoryStream]::new()
    try {
      $graphics.Clear([System.Drawing.Color]::Transparent)
      $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.DrawImage($original,0,0,$size,$size)
      $bitmap.Save($stream,[System.Drawing.Imaging.ImageFormat]::Png)
      $images.Add($stream.ToArray())
    } finally { $stream.Dispose(); $graphics.Dispose(); $bitmap.Dispose() }
  }
  $output = [System.IO.File]::Create((Join-Path $repoRoot 'windows/runner/resources/app_icon.ico'))
  $writer = [System.IO.BinaryWriter]::new($output)
  try {
    $writer.Write([UInt16]0); $writer.Write([UInt16]1); $writer.Write([UInt16]$sizes.Length)
    $offset = 6 + 16 * $sizes.Length
    for ($index=0; $index -lt $sizes.Length; $index++) {
      $dimension = if ($sizes[$index] -eq 256) { 0 } else { $sizes[$index] }
      $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
      $writer.Write([byte]0); $writer.Write([byte]0)
      $writer.Write([UInt16]1); $writer.Write([UInt16]32)
      $writer.Write([UInt32]$images[$index].Length); $writer.Write([UInt32]$offset)
      $offset += $images[$index].Length
    }
    foreach ($bytes in $images) { $writer.Write($bytes) }
  } finally { $writer.Dispose(); $output.Dispose() }
  foreach ($size in @(16,32,64,128,256,512,1024)) {
    $bitmap = [System.Drawing.Bitmap]::new($size,$size,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.Clear([System.Drawing.Color]::Transparent)
      $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.DrawImage($original,0,0,$size,$size)
      $bitmap.Save((Join-Path $repoRoot "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png"),[System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
  }
} finally { $original.Dispose() }
