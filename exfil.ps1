param (
    [Parameter(Mandatory=$true)]
    [string]$File,

    [int]$Count = 10
)

# Check file existence
if (-not (Test-Path -Path $File -PathType Leaf)) {
    Write-Error "File not found: $File"
    exit 1
}

# Load required assembly for clipboard access
Add-Type -AssemblyName System.Windows.Forms

function Show-Progress($Message, $Color = "Cyan") {
    Write-Host "`n$($Message.ToUpper())" -ForegroundColor $Color
}

try {
    # Step 1: Compress the file
    Show-Progress "Step 1/4: Compressing file..."
    $originalBytes = [System.IO.File]::ReadAllBytes($File)
    $memoryStream = New-Object System.IO.MemoryStream
    $gzipStream = New-Object System.IO.Compression.GZipStream(
        $memoryStream,
        [System.IO.Compression.CompressionMode]::Compress
    )
    $gzipStream.Write($originalBytes, 0, $originalBytes.Length)
    $gzipStream.Close()
    $compressedBytes = $memoryStream.ToArray()
    Write-Host " Compression complete - Original: $($originalBytes.Length) bytes, Compressed: $($compressedBytes.Length) bytes" -ForegroundColor Green

    # Step 2: Convert to Base64
    Show-Progress "Step 2/4: Converting to base64..."
    $base64String = [Convert]::ToBase64String($compressedBytes)
    Write-Host " Base64 conversion complete - Length: $($base64String.Length) characters" -ForegroundColor Green

    # Step 3: Split into parts
    Show-Progress "Step 3/4: Splitting content..."
    $totalLength = $base64String.Length
    $Count = [Math]::Max(1, [Math]::Min($Count, $totalLength))
    $chunkSize = [Math]::Ceiling($totalLength / $Count)
    $parts = for ($i=0; $i -lt $Count; $i++) {
        $start = $i * $chunkSize
        if ($start -lt $totalLength) {
            $end = [Math]::Min($start + $chunkSize, $totalLength)
            $base64String.Substring($start, $end - $start)
        }
    }
    $actualCount = ($parts | Measure-Object).Count
    Write-Host " Split into $actualCount parts" -ForegroundColor Green

    # Step 4: Interactive copy to clipboard
    Show-Progress "Step 4/4: Interactive copy process" -Color Yellow
    Write-Host " You'll be prompted to copy each part sequentially`n" -ForegroundColor Cyan

    $partNumber = 1
    foreach ($part in $parts) {
        Write-Host "─── Part $partNumber/$actualCount ───" -ForegroundColor Magenta
        Write-Host " Characters: $($part.Length)"
        Write-Host " First 10 chars: $($part.Substring(0, [Math]::Min(10, $part.Length)))..."
        
        # Copy to clipboard
        [System.Windows.Forms.Clipboard]::SetText($part)
        Write-Host "`n ✅ Part $partNumber copied to clipboard!" -ForegroundColor Green
        
        # Pause if not last part
        if ($partNumber -lt $actualCount) {
            Write-Host " Press ENTER to continue to next part..." -ForegroundColor Yellow
            Read-Host
        }
        $partNumber++
    }

    Write-Host "`n 🏁 Process completed! All parts copied successfully." -ForegroundColor Green
}
catch {
    Write-Error "Error occurred: $_"
    exit 1
}
finally {
    if ($memoryStream) { $memoryStream.Dispose() }
    if ($gzipStream) { $gzipStream.Dispose() }
}
