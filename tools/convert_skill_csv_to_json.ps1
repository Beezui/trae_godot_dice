param(
    [string]$csvPath,
    [string]$jsonPath
)

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Skill CSV to JSON Converter" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "CSV Path: $csvPath" -ForegroundColor Yellow
Write-Host "JSON Path: $jsonPath" -ForegroundColor Yellow
Write-Host ""

# 检查文件是否存在
if (-not (Test-Path $csvPath)) {
    Write-Host "Error: CSV file not found: $csvPath" -ForegroundColor Red
    exit 1
}

Write-Host "Reading CSV file..." -ForegroundColor Cyan

# 尝试多种编码读取 CSV
$encodings = @(
    [System.Text.Encoding]::UTF8,
    [System.Text.Encoding]::GetEncoding('gb2312'),
    [System.Text.Encoding]::GetEncoding('gbk')
)

$content = $null
$usedEncoding = $null

foreach ($encoding in $encodings) {
    try {
        Write-Host "  Trying encoding: $($encoding.WebName)" -ForegroundColor Gray
        $content = [System.IO.File]::ReadAllText($csvPath, $encoding)
        if ($content.Length -gt 0) {
            Write-Host "  Success! Content length: $($content.Length) characters" -ForegroundColor Green
            $usedEncoding = $encoding
            break
        }
    } catch {
        Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red
        continue
    }
}

if (-not $content) {
    Write-Host "Error: Cannot read CSV file with any encoding" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Parsing CSV content..." -ForegroundColor Cyan

# 解析 CSV
$lines = $content -split "`r?`n" | Where-Object { $_.Trim() -ne '' }

if ($lines.Count -lt 2) {
    Write-Host "Error: CSV file has no data rows (found $($lines.Count) lines)" -ForegroundColor Red
    exit 1
}

# 读取表头
$header = $lines[0] -split ','
Write-Host "CSV Header: $($header -join ', ')" -ForegroundColor Yellow
Write-Host ""

# 解析数据行
$skills = @()

for ($i = 1; $i -lt $lines.Count; $i++) {
    $line = $lines[$i].Trim()
    if ($line -eq '') { continue }
    
    Write-Host "Processing line $($i + 1): $line" -ForegroundColor Gray
    
    # 处理引号内的逗号
    $values = @()
    $inQuotes = $false
    $currentValue = ''
    
    foreach ($char in $line.ToCharArray()) {
        if ($char -eq '"') {
            $inQuotes = -not $inQuotes
        } elseif ($char -eq ',' -and -not $inQuotes) {
            $values += $currentValue.Trim().Trim('"')
            $currentValue = ''
        } else {
            $currentValue += $char
        }
    }
    $values += $currentValue.Trim().Trim('"')
    
    Write-Host "  Parsed values: $($values.Count) columns" -ForegroundColor Gray
    
    if ($values.Count -ge 5) {
        $skill = [PSCustomObject]@{
            id = $values[0].Trim()
            name = $values[1].Trim()
            description = $values[2].Trim()
            attribute_dice = @{}
            icon = $values[4].Trim()
        }
        
        # 解析属性类型
        $attrStr = $values[3].Trim()
        Write-Host "  Attribute string: $attrStr" -ForegroundColor Gray
        
        $attrPairs = $attrStr -split ','
        foreach ($pair in $attrPairs) {
            if ($pair -match '^(\d+):(.+)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $skill.attribute_dice.$key = $value
                Write-Host "    Added attribute: $key = $value" -ForegroundColor Gray
            }
        }
        
        $skills += $skill
        Write-Host "  Added skill: $($skill.id) - $($skill.name)" -ForegroundColor Cyan
    } else {
        Write-Host "  Warning: Insufficient columns, skipping" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Creating JSON structure..." -ForegroundColor Cyan

# 创建 JSON 结构
$output = [PSCustomObject]@{
    skills = $skills
}

# 转换为 JSON 并保存
$jsonContent = $output | ConvertTo-Json -Depth 10

Write-Host "Writing JSON file..." -ForegroundColor Cyan
[System.IO.File]::WriteAllText($jsonPath, $jsonContent, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "=====================================" -ForegroundColor Green
Write-Host "Conversion completed successfully!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host "Total skills: $($skills.Count)" -ForegroundColor Green
Write-Host "Output file: $jsonPath" -ForegroundColor Green
Write-Host ""
