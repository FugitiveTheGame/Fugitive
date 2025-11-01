# Updates the version information inside export_presets.cfg
# ---------------------------------------------------------
# • Prompts for a SemVer value (MAJOR.MINOR.PATCH)
# • Validates the format
# • Writes the value (plus .0 for Windows) into the proper keys
# • Increments Android version/code

Param ()

# --- 1) Get and validate the version ----------------------------------------
$version = Read-Host "Enter new semantic version (e.g. 1.2.3)"
if ($version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') {
    Write-Error "ERROR: '$version' is not a valid semantic version (MAJOR.MINOR.PATCH)."
    exit 1
}

# --- 2) Load export_presets.cfg ---------------------------------------------
$cfgPath = Join-Path $PSScriptRoot '../export_presets.cfg'
if (-not (Test-Path $cfgPath)) {
    Write-Error "ERROR: export_presets.cfg was not found at '$cfgPath'."
    exit 1
}
$content = [System.IO.File]::ReadAllText($cfgPath)

# --- 3) Prepare replacements -------------------------------------------------
$winVersion    = "$version.0"                     # 4-part version for Windows
$androidCodeRx = 'version/code=(\d+)'             # capture current code

# bump Android version/code by 1
if ($content -match $androidCodeRx) {
    $newCode = ([int]$Matches[1]) + 1
    $content = [regex]::Replace($content, $androidCodeRx, "version/code=$newCode", 1)
}

# perform the string replacements
$content = $content `
    -replace 'application/file_version="[^"]*"',    "application/file_version=`"$winVersion`"" `
    -replace 'application/product_version="[^"]*"', "application/product_version=`"$winVersion`"" `
    -replace 'version/name="[^"]*"',                "version/name=`"$version`"" `
    -replace 'application/short_version="[^"]*"',   "application/short_version=`"$version`"" `
    -replace 'application/version="[^"]*"',         "application/version=`"$version`""

# --- 4) Save the updated file ------------------------------------------------
[System.IO.File]::WriteAllText($cfgPath, $content, [System.Text.UTF8Encoding]::new($false))
Write-Host "export_presets.cfg successfully updated to version $version."