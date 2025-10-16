param(
    [ValidateScript({ (Test-Path $_) -and (Get-Item $_).PSIsContainer })]
    [Parameter(Mandatory, Position=0)]
    [string]$LogDir,

    [Parameter(Mandatory, Position=1)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$Size
)

function Write-ExtLog($msg) {
    if ($env:LROTATE_EXTENDED_LOG -eq "true") {
        Write-Output "ExtendedLog: $msg"
    }
}

$NeededPercentage = 70
if (-not $env:LROTATE_NEEDED_PERCENTAGE) {
    Write-ExtLog("LROTATE_NEEDED_PERCENTAGE is empty, using default percentage!")
}elseif (-not [int]::TryParse($env:LROTATE_NEEDED_PERCENTAGE,[ref]$NeededPercentage) -or $NeededPercentage -le 0) {
    Write-Error("LROTATE_NEEDED_PERCENTAGE must be a positive integer")
	exit 1
}

$dirSize = (Get-ChildItem -Path $LogDir -File | Measure-Object Length -Sum).Sum
if (-not $dirSize) { $dirSize = 0 }

$perc = [math]::Floor($dirSize * 100 / $Size)
$threshold = [math]::Floor($NeededPercentage * $Size / 100)

Write-Output "Directory $LogDir takes $perc% of the given size."

if ($dirSize -eq 0) {
    Write-Output "The folder is empty. No archivation needed."
    return
}

if ($dirSize -lt $threshold) {
    Write-Output "The usage is less than threshold($threshold). No archivation needed."
    return
}

Write-Output "The usage exceeds the threshold($threshold). Archivation needed."

$backupDir = Join-Path (Get-Location) "backup"
if (-not (Test-Path $backupDir)) {
    New-Item $backupDir -ItemType Directory | Out-Null
}

$files = Get-ChildItem -Path $LogDir -File | Sort-Object LastWriteTime
$tmpSize = $dirSize
$toArchive = @()
foreach ($f in $files) {
    $toArchive += $f.FullName
    $tmpSize -= $f.Length
    if ($tmpSize -lt $threshold) { break }
}

Write-ExtLog "files to be archived: $($toArchive -join ', ')"

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupName = "backup_$timestamp.zip"
$backupPath = Join-Path $backupDir $backupName

try {
    Compress-Archive -Path $toArchive -DestinationPath $backupPath -Force
    Write-ExtLog "files archived. Removing originals..."
    Remove-Item $toArchive -Force
    Write-Output "Backup `"$backupName`" created."
} catch {
    Write-Error "Archivation failed: $_"
    exit 1
}