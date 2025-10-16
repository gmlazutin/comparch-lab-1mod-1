$Script = Join-Path (Get-Location) "lrotate.ps1"
$WorkDir = Join-Path (Get-Location) "test_lrotate"
$TestDir = Join-Path $WorkDir "test_dir"

if (-not (Test-Path -Path $Script -PathType Leaf)) {
    Write-Error "$Script not found"
    exit 1
}

New-Item -Path $WorkDir -ItemType Directory -Force | Out-Null
Set-Location $WorkDir

function Clean-AndExit($code) {
    Remove-Item Env:LROTATE_NEEDED_PERCENTAGE -ErrorAction SilentlyContinue
    Remove-Item Env:LROTATE_EXTENDED_LOG -ErrorAction SilentlyContinue
	Set-Location ..
    Remove-Item -Path $WorkDir -Recurse -Force
    exit $code
}

function Init-Test {
    Remove-Item Env:LROTATE_NEEDED_PERCENTAGE -ErrorAction SilentlyContinue
    Remove-Item Env:LROTATE_EXTENDED_LOG -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
}

function Finish-Test {
    if (Test-Path -Path $TestDir -PathType Container) { Remove-Item -Path $TestDir -Recurse -Force }
    if (Test-Path -Path "backup" -PathType Container) { Remove-Item -Path "backup" -Recurse -Force }
    if (Test-Path -Path "extracted" -PathType Container) { Remove-Item -Path "extracted" -Recurse -Force }
}

function Run-Test($expected, $desc, $scriptArgs) {
    Write-Output ">>> $desc"
    try {
        $output = & $Script @scriptArgs 2>&1
        if ($expected) {
            if ($output -match [regex]::Escape($expected)) {
                Write-Output "PASSED"
            } else {
                Write-Output "FAILED"
                Write-Output "Got output:"
                Write-Output $output
                Clean-AndExit 1
            }
        } else {
            Write-Output "waiting for additional checks..."
        }
    } catch {
		if ($_.Exception.GetType().FullName -match [regex]::Escape($expected)) {
	        Write-Output "PASSED"
		}else{
            Write-Output "FAILED"
            Write-Output "Got output (from exception):"
		    Write-Output "$_ ($($_.Exception.GetType().FullName))"
		    Clean-AndExit 1
		}
    }
    Write-Output ""
}

# 3. Invalid LROTATE_NEEDED_PERCENTAGE
Init-Test
$Env:LROTATE_NEEDED_PERCENTAGE = "abc"
Run-Test "must be a positive integer" "Test 3: invalid environment variable" @($TestDir, 1000)
Finish-Test

# 4. Non-numeric size
Init-Test
Run-Test "ParameterBindingArgumentTransformationException" "Test 4: non-numeric size" @($TestDir, "abc")
Finish-Test

# 5. Zero size
Init-Test
Run-Test "ParameterBindingValidationException" "Test 5: zero as size" @($TestDir, 0)
Finish-Test

# 6. Empty path
Init-Test
Run-Test "ParameterBindingValidationException" "Test 6: empty path" @("", 1000)
Finish-Test

# 7. Non-existent path
Init-Test
Run-Test "ParameterBindingValidationException" "Test 7: non-existent path" @("/fake/path", 1000)
Finish-Test

# 8. Path is file, not directory
Init-Test
New-Item -Path "$TestDir/file.ext" -ItemType File -Force | Out-Null
Run-Test "ParameterBindingValidationException" "Test 8: path is a file" @("$TestDir/file.ext", 1000)
Finish-Test

# 9. Folder smaller than threshold
Init-Test
Set-Content -Path "$TestDir/smallfile" -Value (New-Object Byte[] 1024) -Encoding Byte
Run-Test "No archivation needed" "Test 9: directory smaller than threshold" @($TestDir, 100000)
Finish-Test

# 10. Folder exceeds threshold
Init-Test
Set-Content -Path "$TestDir/bigfile" -Value (New-Object Byte[] 1024) -Encoding Byte
Run-Test "Archivation needed" "Test 10: directory exceeds threshold" @($TestDir, 100)
Finish-Test

# 11. Folder size exactly equals threshold
Init-Test
Set-Content -Path "$TestDir/exact" -Value (New-Object Byte[] 1024) -Encoding Byte
$Env:LROTATE_NEEDED_PERCENTAGE = "10"
Run-Test "Archivation needed" "Test 11: size equals threshold" @($TestDir, 1024)
Finish-Test

# 12. Extended log message when env var unset
Init-Test
$Env:LROTATE_EXTENDED_LOG = "true"
Run-Test "ExtendedLog: LROTATE_NEEDED_PERCENTAGE is empty, using default percentage!" "Test 12: extended log message shown" @($TestDir, 1000)
Finish-Test

# 13. Valid custom percentage = 90 (no archivation)
Init-Test
Set-Content -Path "$TestDir/small" -Value (New-Object Byte[] 1500) -Encoding Byte
$Env:LROTATE_NEEDED_PERCENTAGE = "90"
Run-Test "No archivation needed" "Test 13: custom percentage = 90%" @($TestDir, 2000)
Finish-Test

# 14. Negative percentage
Init-Test
$Env:LROTATE_NEEDED_PERCENTAGE = "-5"
Run-Test "must be a positive integer" "Test 14: negative percentage value" @($TestDir, 2000)
Finish-Test

# 15. Empty folder
Init-Test
Run-Test "No archivation needed" "Test 15: empty folder" @($TestDir, 1)
Finish-Test

# 16. Check archive files and logs folder
Init-Test
Set-Content -Path "$TestDir/biglog1.txt" -Value (New-Object Byte[] 1024) -Encoding Byte
Set-Content -Path "$TestDir/biglog2.txt" -Value (New-Object Byte[] 1024) -Encoding Byte
Start-Sleep -Milliseconds 500
Set-Content -Path "$TestDir/biglog3.txt" -Value (New-Object Byte[] 1024) -Encoding Byte

$Env:LROTATE_NEEDED_PERCENTAGE = 50
Run-Test "" "Test 16: check archive files and logs folder" @($TestDir, 4096)

$archiveFile = Get-ChildItem -Path "backup" -Filter "*.zip" | Select-Object -First 1
if (-not $archiveFile) {
    Write-Host "FAILED: archive file not found!"
} else {
    New-Item -ItemType Directory -Path "extracted" -Force | Out-Null
    Expand-Archive -Path $archiveFile.FullName -DestinationPath "extracted" -Force
    if ((Test-Path "extracted/biglog1.txt") -and (Test-Path "extracted/biglog2.txt") -and
        -not (Test-Path "extracted/biglog3.txt") -and (Test-Path "$TestDir/biglog3.txt") -and
        -not (Test-Path "$TestDir/biglog1.txt") -and -not (Test-Path "$TestDir/biglog2.txt")) {
        Write-Host "PASSED"
    } else {
        Write-Host "FAILED: archive does not contain all original files or files are not removed properly!"
        Clean-AndExit 1
    }
}
Finish-Test

Clean-AndExit 0