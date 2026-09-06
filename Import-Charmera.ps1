$configPath = Join-Path $PSScriptRoot 'config.json'
$historyPath = Join-Path $PSScriptRoot 'downloaded-photos.txt'
$extensions = @('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tif', '.tiff', '.webp')

function Resolve-ConfiguredPath([string]$path) {
    $expanded = [Environment]::ExpandEnvironmentVariables($path)
    if ([IO.Path]::IsPathRooted($expanded)) { return [IO.Path]::GetFullPath($expanded) }
    return [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $expanded))
}

function Get-FreePath([string]$folder, [string]$name) {
    $candidate = Join-Path $folder $name
    if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
    $stem = [IO.Path]::GetFileNameWithoutExtension($name)
    $ext = [IO.Path]::GetExtension($name)
    $number = 2
    do {
        $candidate = Join-Path $folder "$stem ($number)$ext"
        $number++
    } while (Test-Path -LiteralPath $candidate)
    return $candidate
}

if (-not (Test-Path -LiteralPath $configPath)) {
    Write-Error "Config file not found: $configPath"
    exit 1
}

try {
    $config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
    if (-not $config.sourceFolder -or -not $config.cameraVolumeLabel -or -not $config.cameraPhotoFolder) {
        throw 'sourceFolder, cameraVolumeLabel, or cameraPhotoFolder is missing'
    }
    $destinationFolder = Resolve-ConfiguredPath $config.sourceFolder
} catch {
    Write-Error "Could not read config.json: $($_.Exception.Message)"
    exit 1
}

$mutex = New-Object Threading.Mutex($false, 'PhotoSorterCharmeraImport')
if (-not $mutex.WaitOne(0, $false)) { exit 0 }

try {
    $cameraFolder = $null
    foreach ($drive in [IO.DriveInfo]::GetDrives()) {
        try {
            if ($drive.IsReady -and $drive.VolumeLabel -ieq $config.cameraVolumeLabel) {
                $candidate = Join-Path $drive.RootDirectory.FullName $config.cameraPhotoFolder
                if (Test-Path -LiteralPath $candidate) {
                    $cameraFolder = $candidate
                    break
                }
            }
        } catch {
            # The drive may have been disconnected while it was being checked.
        }
    }

    if (-not $cameraFolder) {
        Write-Output "No ready drive named '$($config.cameraVolumeLabel)' with a '$($config.cameraPhotoFolder)' folder was found."
        exit 0
    }

    New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null

    $downloaded = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    if (Test-Path -LiteralPath $historyPath) {
        foreach ($line in Get-Content -LiteralPath $historyPath) {
            if ($line.Trim()) { [void]$downloaded.Add($line.Trim()) }
        }
    }

    $copied = 0
    $skipped = 0
    $failed = 0
    $files = Get-ChildItem -LiteralPath $cameraFolder -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
        $extensions -contains $_.Extension.ToLowerInvariant()
    } | Sort-Object FullName

    foreach ($file in $files) {
        $temporary = $null
        try {
            $relativePath = $file.FullName.Substring($cameraFolder.Length).TrimStart('\')
            $fingerprint = "$relativePath`t$($file.Length)`t$($file.LastWriteTimeUtc.Ticks)"
            if ($downloaded.Contains($fingerprint)) {
                $skipped++
                continue
            }

            $destination = Get-FreePath $destinationFolder $file.Name
            $temporary = "$destination.partial"
            Copy-Item -LiteralPath $file.FullName -Destination $temporary -ErrorAction Stop
            Move-Item -LiteralPath $temporary -Destination $destination -ErrorAction Stop
            Add-Content -LiteralPath $historyPath -Value $fingerprint -Encoding UTF8
            [void]$downloaded.Add($fingerprint)
            $copied++
        } catch {
            $failed++
            if ($temporary -and (Test-Path -LiteralPath $temporary)) {
                Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Output "Charmera import finished. Copied: $copied. Already downloaded: $skipped. Failed: $failed."
    if ($failed -gt 0) { exit 1 }
} finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
