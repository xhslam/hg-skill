[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SpecPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

function New-RectF {
    param(
        [double]$X,
        [double]$Y,
        [double]$Width,
        [double]$Height
    )

    return [System.Drawing.RectangleF]::new([single]$X, [single]$Y, [single]$Width, [single]$Height)
}

function To-StringArray {
    param([object]$Value)

    return @($Value | ForEach-Object { [string]$_ })
}

function New-BlankArray {
    param([int]$Count)

    $items = New-Object string[] $Count
    for ($i = 0; $i -lt $Count; $i++) {
        $items[$i] = ''
    }

    return $items
}

function Render-Page {
    param(
        [string[]]$LeftWords,
        [string[]]$LeftMeanings,
        [string[]]$RightWords,
        [string[]]$RightMeanings,
        [string]$OutPath
    )

    $width = 1240
    $height = 1580
    $margin = 12
    $gap = 10
    $top = 8
    $bottom = 16
    $headerHeight = 34
    $tableWidth = [int](($width - (2 * $margin) - $gap) / 2)
    $rowHeight = [int](($height - $top - $bottom - $headerHeight) / 20)
    $tableHeight = $headerHeight + (20 * $rowHeight)
    $numberWidth = 50
    $wordWidth = 210
    $checkWidth = 54
    $meaningWidth = $tableWidth - $numberWidth - $wordWidth - $checkWidth

    $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(224, 190, 165), 2)
    $gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220, 205, 190), 1)
    $gridPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dot
    $dividerPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150, 145, 140), 2)
    $dividerPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
    $headerBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(247, 166, 112))
    $altBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(253, 232, 221))
    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(37, 37, 37))
    $mutedBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(92, 86, 82))

    $headerFont = New-Object System.Drawing.Font('Arial', 17, [System.Drawing.FontStyle]::Bold)
    $wordFont = New-Object System.Drawing.Font('Arial', 17, [System.Drawing.FontStyle]::Bold)
    $meaningFont = New-Object System.Drawing.Font('Microsoft YaHei UI', 13.5, [System.Drawing.FontStyle]::Regular)
    $numberFont = New-Object System.Drawing.Font('Arial', 14, [System.Drawing.FontStyle]::Bold)

    $headerFormat = New-Object System.Drawing.StringFormat
    $headerFormat.Alignment = [System.Drawing.StringAlignment]::Near
    $headerFormat.LineAlignment = [System.Drawing.StringAlignment]::Center

    $numberFormat = New-Object System.Drawing.StringFormat
    $numberFormat.Alignment = [System.Drawing.StringAlignment]::Center
    $numberFormat.LineAlignment = [System.Drawing.StringAlignment]::Center

    $wordFormat = New-Object System.Drawing.StringFormat
    $wordFormat.Alignment = [System.Drawing.StringAlignment]::Near
    $wordFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
    $wordFormat.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap

    $meaningFormat = New-Object System.Drawing.StringFormat
    $meaningFormat.Alignment = [System.Drawing.StringAlignment]::Near
    $meaningFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
    $meaningFormat.Trimming = [System.Drawing.StringTrimming]::Word

    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.FillRectangle([System.Drawing.Brushes]::White, 0, 0, $width, $height)

    $leftX = $margin
    $rightX = $margin + $tableWidth + $gap
    $centerX = $margin + $tableWidth + [int]($gap / 2)

    function Draw-Half {
        param(
            [double]$StartX,
            [string[]]$Words,
            [string[]]$Meanings
        )

        $graphics.DrawRectangle($borderPen, [int]$StartX, $top, $tableWidth, $tableHeight)
        $graphics.FillRectangle($headerBrush, [single]$StartX, [single]$top, [single]$tableWidth, [single]$headerHeight)

        $graphics.DrawString('Word', $headerFont, $mutedBrush, (New-RectF ($StartX + $numberWidth + 14) $top ($wordWidth - 18) $headerHeight), $headerFormat)
        $graphics.DrawString('Meaning', $headerFont, $mutedBrush, (New-RectF ($StartX + $numberWidth + $wordWidth + 14) $top ($meaningWidth - 18) $headerHeight), $headerFormat)

        for ($i = 0; $i -lt 20; $i++) {
            $y = $top + $headerHeight + ($i * $rowHeight)

            if (($i % 2) -eq 1) {
                $graphics.FillRectangle($altBrush, [single]$StartX, [single]$y, [single]$tableWidth, [single]$rowHeight)
            }

            $graphics.DrawLine($gridPen, [single]$StartX, [single]$y, [single]($StartX + $tableWidth), [single]$y)
            $graphics.DrawString(($i + 1).ToString(), $numberFont, $mutedBrush, (New-RectF $StartX $y $numberWidth $rowHeight), $numberFormat)

            if (-not [string]::IsNullOrWhiteSpace($Words[$i])) {
                $graphics.DrawString($Words[$i], $wordFont, $textBrush, (New-RectF ($StartX + $numberWidth + 14) $y ($wordWidth - 20) $rowHeight), $wordFormat)
            }

            if (-not [string]::IsNullOrWhiteSpace($Meanings[$i])) {
                $graphics.DrawString($Meanings[$i], $meaningFont, $textBrush, (New-RectF ($StartX + $numberWidth + $wordWidth + 14) ($y + 2) ($meaningWidth - 24) ($rowHeight - 4)), $meaningFormat)
            }

            $boxSize = 21
            $boxX = [int]($StartX + $tableWidth - ($checkWidth / 2) - ($boxSize / 2))
            $boxY = [int]($y + ($rowHeight / 2) - ($boxSize / 2))
            $boxPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(168, 166, 158), 2)
            $graphics.DrawRectangle($boxPen, $boxX, $boxY, $boxSize, $boxSize)
            $boxPen.Dispose()
        }

        $graphics.DrawLine($gridPen, [single]($StartX + $numberWidth), [single]$top, [single]($StartX + $numberWidth), [single]($top + $tableHeight))
        $graphics.DrawLine($gridPen, [single]($StartX + $numberWidth + $wordWidth), [single]$top, [single]($StartX + $numberWidth + $wordWidth), [single]($top + $tableHeight))
        $graphics.DrawLine($gridPen, [single]($StartX + $numberWidth + $wordWidth + $meaningWidth), [single]$top, [single]($StartX + $numberWidth + $wordWidth + $meaningWidth), [single]($top + $tableHeight))
    }

    Draw-Half $leftX $LeftWords $LeftMeanings
    Draw-Half $rightX $RightWords $RightMeanings
    $graphics.DrawLine($dividerPen, [single]$centerX, [single]$top, [single]$centerX, [single]($top + $tableHeight))

    $bitmap.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $graphics.Dispose()
    $bitmap.Dispose()
    $borderPen.Dispose()
    $gridPen.Dispose()
    $dividerPen.Dispose()
    $headerBrush.Dispose()
    $altBrush.Dispose()
    $textBrush.Dispose()
    $mutedBrush.Dispose()
    $headerFont.Dispose()
    $wordFont.Dispose()
    $meaningFont.Dispose()
    $numberFont.Dispose()
    $headerFormat.Dispose()
    $numberFormat.Dispose()
    $wordFormat.Dispose()
    $meaningFormat.Dispose()
}

$spec = Get-Content -LiteralPath $SpecPath -Raw | ConvertFrom-Json
$blocks = @($spec.blocks)
if ($blocks.Count -ne 2) {
    throw "Spec must contain exactly 2 blocks."
}

$normalizedBlocks = foreach ($block in $blocks) {
    $words = To-StringArray $block.words
    $meanings = To-StringArray $block.meanings
    if ($words.Count -ne 20 -or $meanings.Count -ne 20) {
        throw "Each block must contain exactly 20 words and 20 meanings."
    }

    [pscustomobject]@{
        words = $words
        meanings = $meanings
    }
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$blank = New-BlankArray -Count 20
$pages = @(
    [pscustomobject]@{ name = 'page-1-english-to-chinese.png'; leftWords = $normalizedBlocks[0].words; leftMeanings = $blank; rightWords = $normalizedBlocks[1].words; rightMeanings = $blank },
    [pscustomobject]@{ name = 'page-2-chinese-to-english.png'; leftWords = $blank; leftMeanings = $normalizedBlocks[0].meanings; rightWords = $blank; rightMeanings = $normalizedBlocks[1].meanings },
    [pscustomobject]@{ name = 'page-3-mixed-english-then-chinese.png'; leftWords = $normalizedBlocks[0].words; leftMeanings = $blank; rightWords = $blank; rightMeanings = $normalizedBlocks[1].meanings },
    [pscustomobject]@{ name = 'page-4-mixed-chinese-then-english.png'; leftWords = $blank; leftMeanings = $normalizedBlocks[0].meanings; rightWords = $normalizedBlocks[1].words; rightMeanings = $blank }
)

foreach ($page in $pages) {
    $outPath = Join-Path $OutputDir $page.name
    Render-Page -LeftWords $page.leftWords -LeftMeanings $page.leftMeanings -RightWords $page.rightWords -RightMeanings $page.rightMeanings -OutPath $outPath
}

Write-Output $OutputDir
