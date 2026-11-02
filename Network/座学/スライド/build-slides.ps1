$ErrorActionPreference = 'Stop'

$scriptDirectory = $PSScriptRoot
$projectRoot = Resolve-Path (Join-Path $scriptDirectory '..\..\..')
$templatePath = Join-Path $projectRoot 'slide-template\template.pptx'
$outlinePath = Join-Path $scriptDirectory 'slides.json'
$presentationPath = Join-Path $scriptDirectory 'Azure-Network-座学.pptx'
$pdfPath = Join-Path $scriptDirectory 'Azure-Network-座学.pdf'

foreach ($requiredPath in @($templatePath, $outlinePath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required input not found: $requiredPath"
    }
}

foreach ($outputPath in @($presentationPath, $pdfPath)) {
    if (Test-Path -LiteralPath $outputPath) {
        throw "Output already exists; move it before rebuilding to protect manual edits: $outputPath"
    }
}

$outline = Get-Content -LiteralPath $outlinePath -Raw | ConvertFrom-Json -Depth 100
if (-not $outline.slides -or $outline.slides.Count -eq 0) {
    throw "No content slides were found in $outlinePath"
}

function Convert-HexToOleColor([string]$hex) {
    $value = $hex.TrimStart('#')
    $red = [Convert]::ToInt32($value.Substring(0, 2), 16)
    $green = [Convert]::ToInt32($value.Substring(2, 2), 16)
    $blue = [Convert]::ToInt32($value.Substring(4, 2), 16)
    return ($red + ($green * 256) + ($blue * 65536))
}

function Set-TextStyle($shape, [int]$size, [string]$color, [bool]$bold, [string]$align) {
    $shape.TextFrame.WordWrap = -1
    $shape.TextFrame.AutoSize = 0
    $shape.TextFrame.MarginLeft = 0
    $shape.TextFrame.MarginRight = 0
    $shape.TextFrame.MarginTop = 0
    $shape.TextFrame.MarginBottom = 0
    $shape.TextFrame.VerticalAnchor = 1
    $range = $shape.TextFrame.TextRange
    $range.Font.Name = 'Yu Gothic UI'
    $range.Font.NameFarEast = 'Yu Gothic UI'
    $range.Font.Size = $size
    $range.Font.Color.RGB = Convert-HexToOleColor $color
    $range.Font.Bold = [int]$bold
    switch ($align) {
        'center' { $range.ParagraphFormat.Alignment = 2 }
        'right' { $range.ParagraphFormat.Alignment = 3 }
        default { $range.ParagraphFormat.Alignment = 1 }
    }
}

function Add-Text($slide, $item) {
    $shape = $slide.Shapes.AddTextbox(1, [single]$item.x, [single]$item.y, [single]$item.w, [single]$item.h)
    $shape.TextFrame.TextRange.Text = ([string]$item.text).Replace('\n', "`r`n")
    $bold = $item.bold -eq $true
    $align = if ($item.align) { [string]$item.align } else { 'left' }
    Set-TextStyle $shape ([int]$item.size) ([string]$item.color) $bold $align
    if ($item.hyperlink) {
        $shape.TextFrame.TextRange.Font.Underline = -1
        $shape.TextFrame.TextRange.ActionSettings(1).Hyperlink.Address = [string]$item.hyperlink
    }
}

function Add-Rect($slide, $item, [bool]$ellipse = $false) {
    $shapeType = if ($ellipse) { 9 } else { 1 }
    $shape = $slide.Shapes.AddShape($shapeType, [single]$item.x, [single]$item.y, [single]$item.w, [single]$item.h)
    $shape.Fill.Visible = -1
    $shape.Fill.ForeColor.RGB = Convert-HexToOleColor ([string]$item.fill)
    $shape.Line.Visible = -1
    $shape.Line.ForeColor.RGB = Convert-HexToOleColor ([string]$item.line)
    if ($item.lineWidth) {
        $shape.Line.Weight = [single]$item.lineWidth
    } else {
        $shape.Line.Weight = 1
    }
}

function Add-Line($slide, $item, [bool]$arrow = $false) {
    $x1 = [single]$item.x1
    $y1 = [single]$item.y1
    $x2 = [single]$item.x2
    $y2 = [single]$item.y2
    $reverse = ($x2 -lt $x1) -or (($x2 -eq $x1) -and ($y2 -lt $y1))
    if ($reverse) {
        $shape = $slide.Shapes.AddLine($x2, $y2, $x1, $y1)
    } else {
        $shape = $slide.Shapes.AddLine($x1, $y1, $x2, $y2)
    }
    $shape.Line.ForeColor.RGB = Convert-HexToOleColor ([string]$item.color)
    $shape.Line.Weight = [single]$item.width
    if ($arrow) {
        if ($reverse) {
            $shape.Line.BeginArrowheadStyle = 2
        } else {
            $shape.Line.EndArrowheadStyle = 2
        }
    }
}

function Add-Notes($slide, $content, $sources) {
    $noteText = [string]$content
    if ($sources.Count -gt 0) {
        $noteText += "`r`n`r`n出典:`r`n"
        $noteText += (($sources | ForEach-Object { "$($_.label)`r`n$($_.url)" }) -join "`r`n")
    }
    $notesBody = $null
    foreach ($shape in $slide.NotesPage.Shapes) {
        try {
            if ($shape.PlaceholderFormat.Type -eq 2) {
                $notesBody = $shape
                break
            }
        } catch {
            continue
        }
    }
    if (-not $notesBody) {
        throw "Speaker-notes placeholder not found on slide $($slide.SlideIndex)"
    }
    $notesBody.TextFrame.TextRange.Text = $noteText
}

function Add-Sources($slide, $sources) {
    $x = 46
    foreach ($source in $sources) {
        $label = [string]$source.label
        $width = [Math]::Min(430, [Math]::Max(150, ($label.Length * 6.5) + 18))
        $shape = $slide.Shapes.AddTextbox(1, [single]$x, 489, [single]$width, 18)
        $shape.TextFrame.TextRange.Text = $label
        Set-TextStyle $shape 10 '#0067B8' $false 'left'
        $shape.TextFrame.TextRange.Font.Underline = -1
        $shape.TextFrame.TextRange.ActionSettings(1).Hyperlink.Address = [string]$source.url
        $x += [int]$width + 20
    }
}

Copy-Item -LiteralPath $templatePath -Destination $presentationPath
$powerPoint = $null
$presentation = $null
$completed = $false
try {
    $powerPoint = New-Object -ComObject PowerPoint.Application
    $presentation = $powerPoint.Presentations.Open($presentationPath, $false, $false, $false)

    $cover = $presentation.Slides.Item(1)
    $cover.Shapes.Item(1).TextFrame.TextRange.Text = [string]$outline.title
    $cover.Shapes.Item(1).TextFrame.TextRange.Font.Name = 'Yu Gothic UI'
    $cover.Shapes.Item(1).TextFrame.TextRange.Font.NameFarEast = 'Yu Gothic UI'
    $cover.Shapes.Item(2).TextFrame.TextRange.Text = [string]$outline.subtitle
    $cover.Shapes.Item(2).TextFrame.TextRange.Font.Name = 'Yu Gothic UI'
    $cover.Shapes.Item(2).TextFrame.TextRange.Font.NameFarEast = 'Yu Gothic UI'

    $agenda = $presentation.Slides.Item(2)
    $agenda.Shapes.Item(1).TextFrame.TextRange.Text = '講義の流れ'
    $agendaBody = $agenda.Shapes.Item(2)
    $agendaBody.Top = 185
    $agendaBody.Height = 250
    $agendaBody.TextFrame.TextRange.Text = (($outline.agenda | ForEach-Object { [string]$_ }) -join "`r`n`r`n")
    Set-TextStyle $agendaBody 22 '#202020' $false 'left'

    $baseSlide = $presentation.Slides.Item(3)
    for ($index = 1; $index -lt $outline.slides.Count; $index++) {
        $null = $baseSlide.Duplicate()
    }

    for ($index = 0; $index -lt $outline.slides.Count; $index++) {
        $cursor = $presentation.Slides.Item($index + 3)
        $content = $outline.slides[$index]
        $titleShape = $cursor.Shapes.Item(1)
        $titleShape.TextFrame.TextRange.Text = [string]$content.title
        $titleShape.TextFrame.TextRange.Font.Name = 'Yu Gothic UI'
        $titleShape.TextFrame.TextRange.Font.NameFarEast = 'Yu Gothic UI'
        if ($content.title.Length -gt 30) {
            $titleShape.TextFrame.TextRange.Font.Size = 28
        } elseif ($content.title.Length -gt 23) {
            $titleShape.TextFrame.TextRange.Font.Size = 32
        }

        foreach ($item in $content.elements) {
            switch ([string]$item.kind) {
                'text' { Add-Text $cursor $item }
                'rect' { Add-Rect $cursor $item }
                'circle' { Add-Rect $cursor $item $true }
                'line' { Add-Line $cursor $item }
                'arrow' { Add-Line $cursor $item $true }
                default { throw "Unsupported element kind '$($item.kind)' on slide '$($content.title)'." }
            }
        }
        Add-Sources $cursor $content.sources
        Add-Notes $cursor $content.notes $content.sources
    }

    $presentation.Save()
    $presentation.SaveAs($pdfPath, 32)
    $completed = $true
    Write-Output "Created $($outline.slides.Count + 3) slides."
    Write-Output "PPTX: $presentationPath"
    Write-Output "PDF:  $pdfPath"
} finally {
    if ($presentation) {
        $presentation.Close()
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($presentation)
    }
    if ($powerPoint) {
        $powerPoint.Quit()
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($powerPoint)
    }
    if (-not $completed) {
        foreach ($generatedPath in @($presentationPath, $pdfPath)) {
            if (Test-Path -LiteralPath $generatedPath) {
                Remove-Item -LiteralPath $generatedPath
            }
        }
    }
}
