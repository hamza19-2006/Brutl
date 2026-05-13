$root = "D:\Projects\Vs_Projects\Flutter_Projects\Burtl_App"
$libPath = "$root\lib"
$files = Get-ChildItem -Path $libPath -Filter "*.dart" -Recurse | Where-Object { $_.FullName -notmatch "(\.g\.dart|\.freezed\.dart|generated|build|main\.dart$)" }
$filePaths = $files.FullName
$incomingCounts = @{}
foreach ($f in $filePaths) { $incomingCounts[$f] = 0 }

foreach ($f in (Get-ChildItem -Path $libPath -Filter "*.dart" -Recurse).FullName) {
    Try {
        $content = Get-Content $f -ErrorAction SilentlyContinue
        foreach ($line in $content) {
            if ($line -match "(import|export|part)\s+['""]([^'"" ]+)['""]") {
                $ref = $Matches[2]
                $resolvedPath = $null
                if ($ref -like "package:burtl_app/*") {
                    $rel = $ref -replace "package:burtl_app/", ""
                    $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path $libPath $rel))
                } elseif ($ref -notmatch "^(package|dart):") {
                    $dir = Split-Path $f
                    $resolvedPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($dir, $ref))
                }
                if ($resolvedPath -and $incomingCounts.ContainsKey($resolvedPath)) { $incomingCounts[$resolvedPath]++ }
            }
        }
    } Catch {}
}

$results = @()
foreach ($key in $incomingCounts.Keys) {
    if ($incomingCounts[$key] -eq 0) {
        $path = $key
        $fileName = Split-Path $path -LeafBase
        $pascalName = ($fileName -split '[-_]' | ForEach-Object { if ($_) { $_.Substring(0,1).ToUpper() + $_.Substring(1) } }) -join ''
        $otherRefs = 0
        foreach ($f in (Get-ChildItem -Path $libPath -Filter "*.dart" -Recurse).FullName) {
            if ($f -ne $path) {
                if (Select-String -Path $f -SimpleMatch -Pattern $pascalName -Quiet) { $otherRefs++ }
            }
        }
        $results += [PSCustomObject]@{ Path = $path.Replace("$root\", ""); Imports = 0; ClassUsage = $otherRefs }
    }
}
$results | Sort-Object Path | Format-Table -AutoSize
