$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
public static class VaultPixelReview {
  public static double[] Measure(string reference, string actual, int x, int y, int w, int h) {
    using(var a = new Bitmap(reference)) using(var b = new Bitmap(actual)) {
      if(a.Width != b.Width || a.Height != b.Height) throw new Exception("Image sizes differ");
      long delta=0, exact=0, count=0;
      for(int py=y;py<y+h;py++) for(int px=x;px<x+w;px++) {
        var ca=a.GetPixel(px,py);var cb=b.GetPixel(px,py);
        delta+=Math.Abs(ca.R-cb.R)+Math.Abs(ca.G-cb.G)+Math.Abs(ca.B-cb.B);
        if(ca.ToArgb()==cb.ToArgb())exact++;
        count++;
      }
      return new double[]{delta/(count*3.0),exact*100.0/count};
    }
  }
}
'@
$results = @()
foreach ($width in @(1280,1440)) {
  $referenceName = if ($width -eq 1280) {'01-library-1280.png'} else {'01-library.png'}
  $reference = Join-Path $repoRoot "design/previews/selected/$referenceName"
  $actual = Join-Path $repoRoot "build/e2e/design-library-$width.png"
  $height = if ($width -eq 1280) {800} else {900}
  $region = if ($width -eq 1280) {@(30,196,870,360)} else {@(38,199,984,435)}
  $whole = [VaultPixelReview]::Measure($reference,$actual,0,0,$width,$height)
  $stage = [VaultPixelReview]::Measure($reference,$actual,$region[0],$region[1],$region[2],$region[3])
  $results += [pscustomobject]@{width=$width;height=$height;wholeImageMeanRgbError=$whole[0];wholeImageExactPixelsPercent=$whole[1];previewMeanRgbError=$stage[0];previewExactPixelsPercent=$stage[1];note='Different renderers and functional controls: these are measurements, not a claim of zero pixel difference.'}
}
$results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $repoRoot 'build/e2e/design-pixel-results.json') -Encoding UTF8
$results | Format-Table width,wholeImageMeanRgbError,previewMeanRgbError,previewExactPixelsPercent
