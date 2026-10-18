param(
  [string]$InputCsv = "data\neurophysiology\band_condition_summary.csv",
  [string]$OutputSvg = "assets\neurophysiology\ru\band-summary-angle.svg"
)

$ErrorActionPreference = "Stop"
$culture = [Globalization.CultureInfo]::InvariantCulture
$rows = Import-Csv -LiteralPath $InputCsv | Where-Object {
  $_.group -eq "noninvasive" -and $_.target_label -eq "Angle"
}

$movementOrder = @("Clenching", "Rotation", "Tapping")
$handOrder = @("LeftHand", "RightHand")
$conditionOrder = @("PreNFB", "PostNFB")
$bandOrder = @("delta", "theta", "alpha", "low_beta", "high_beta")
$bandLabels = @("дельта", "тета", "альфа", "низкая бета", "высокая бета")
$movementLabels = @{Clenching="Сжатие"; Rotation="Вращение"; Tapping="Тэппинг"}
$handLabels = @{LeftHand="левая"; RightHand="правая"}
$conditionLabels = @{PreNFB="до"; PostNFB="после"}

function Escape([string]$value) { [Security.SecurityElement]::Escape($value) }
function HexColor([double]$value) {
  $minimum = -1.2; $zero = 0.0; $maximum = 3.3
  $low = @(9, 78, 83); $mid = @(239, 244, 242); $high = @(213, 104, 53)
  if ($value -le $zero) {
    $t = [Math]::Max(0, [Math]::Min(1, ($value - $minimum) / ($zero - $minimum)))
    $a = $low; $b = $mid
  } else {
    $t = [Math]::Max(0, [Math]::Min(1, ($value - $zero) / ($maximum - $zero)))
    $a = $mid; $b = $high
  }
  $rgb = 0..2 | ForEach-Object { [int][Math]::Round($a[$_] + ($b[$_] - $a[$_]) * $t) }
  "#{0:X2}{1:X2}{2:X2}" -f $rgb[0], $rgb[1], $rgb[2]
}

$lookup = @{}
foreach ($row in $rows) {
  $lookup["$($row.movement)|$($row.hand)|$($row.condition)|$($row.analysis_band)"] = [double]::Parse($row.mean_zMI, $culture)
}

$width = 1280; $height = 930; $left = 330; $top = 150; $cellW = 170; $cellH = 54
$svg = [Text.StringBuilder]::new()
[void]$svg.AppendLine("<svg xmlns='http://www.w3.org/2000/svg' width='$width' height='$height' viewBox='0 0 $width $height'>")
[void]$svg.AppendLine("<rect width='100%' height='100%' fill='#ffffff'/>")
[void]$svg.AppendLine("<style>text{font-family:system-ui,-apple-system,'Segoe UI',Arial,sans-serif;fill:#17252d}.title{font-size:30px;font-weight:700}.subtitle{font-size:16px;fill:#53636b}.axis{font-size:16px;font-weight:650}.row{font-size:15px}.value{font-size:16px;font-weight:700}.legend{font-size:14px;fill:#53636b}</style>")
[void]$svg.AppendLine("<text x='54' y='52' class='title'>Средний zMI по частотным диапазонам</text>")
[void]$svg.AppendLine("<text x='54' y='82' class='subtitle'>Неинвазивные каналы · цель: угол движения · описательная сводка одного участника</text>")

for ($c=0; $c -lt $bandOrder.Count; $c++) {
  $x = $left + $c*$cellW + $cellW/2
  [void]$svg.AppendLine("<text x='$x' y='126' text-anchor='middle' class='axis'>$($bandLabels[$c])</text>")
}

$r = 0
foreach ($movement in $movementOrder) {
  foreach ($hand in $handOrder) {
    foreach ($condition in $conditionOrder) {
      $y = $top + $r*$cellH
      $label = "$($movementLabels[$movement]) · $($handLabels[$hand]) · $($conditionLabels[$condition])"
      [void]$svg.AppendLine("<text x='$($left-18)' y='$($y+34)' text-anchor='end' class='row'>$(Escape $label)</text>")
      for ($c=0; $c -lt $bandOrder.Count; $c++) {
        $band = $bandOrder[$c]
        $value = $lookup["$movement|$hand|$condition|$band"]
        $x = $left + $c*$cellW
        $fill = HexColor $value
        $formatted = $value.ToString("0.00", $culture)
        [void]$svg.AppendLine("<rect x='$x' y='$y' width='$cellW' height='$cellH' fill='$fill' stroke='#ffffff' stroke-width='3'/>")
        [void]$svg.AppendLine("<text x='$($x+$cellW/2)' y='$($y+34)' text-anchor='middle' class='value'>$formatted</text>")
      }
      $r++
    }
  }
}

$legendY = 835
[void]$svg.AppendLine("<text x='54' y='$legendY' class='legend'>Ниже суррогатного среднего</text>")
$legendValues = @(-1.2, -0.5, 0, 1, 2, 3, 3.3)
for ($i=0; $i -lt $legendValues.Count; $i++) {
  $x = 260 + $i*92; $fill = HexColor $legendValues[$i]
  [void]$svg.AppendLine("<rect x='$x' y='$($legendY-19)' width='92' height='22' fill='$fill'/>")
}
[void]$svg.AppendLine("<text x='904' y='$legendY' class='legend'>Выше суррогатного среднего</text>")
[void]$svg.AppendLine("<text x='54' y='882' class='subtitle'>zMI показывает положение наблюдаемой взаимной информации относительно распределения 200 фазово-рандомизированных суррогатов.</text>")
[void]$svg.AppendLine("</svg>")

$directory = Split-Path -Parent $OutputSvg
New-Item -ItemType Directory -Force -Path $directory | Out-Null
[IO.File]::WriteAllText($OutputSvg, $svg.ToString(), [Text.UTF8Encoding]::new($false))
Write-Output $OutputSvg
