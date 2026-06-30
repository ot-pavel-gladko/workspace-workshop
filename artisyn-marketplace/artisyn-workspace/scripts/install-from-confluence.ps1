# Artisyn Delivery Workspace — bootstrap install from Confluence (Windows PowerShell).
#
# Pulls the catalog-schema wheel from a Confluence release page,
# uv-tool-installs it, and (unless -NoChain) chains into
# `artisyn-workspace install`.
#
# Usage:
#   $env:ARTISYN_CONFLUENCE_TOKEN = "<your Confluence PAT>"
#   iwr -useb https://conf.dataart.com/.../install-from-confluence.ps1 -OutFile install.ps1
#   .\install.ps1                       # latest artisyn-stable
#   .\install.ps1 0.2.0                 # pin a version
#   .\install.ps1 0.2.0 -NoChain        # just install the CLI
#   .\install.ps1 -Here                 # artisyn-workspace install --here after

param(
    [Parameter(Position=0)][string]$Version = "",
    [switch]$NoChain,
    [switch]$Here,
    [string]$Name = "",
    [string]$Skills = ""
)

$ErrorActionPreference = "Stop"

if ($Version.StartsWith("v")) { $Version = $Version.Substring(1) }

# New ARTISYN_ names preferred; legacy AILA_ / CONFLUENCE_PERSONAL_TOKEN still honoured.
$Token = if ($env:ARTISYN_CONFLUENCE_TOKEN) { $env:ARTISYN_CONFLUENCE_TOKEN }
         elseif ($env:AILA_CONFLUENCE_TOKEN) { $env:AILA_CONFLUENCE_TOKEN }
         else                                { $env:CONFLUENCE_PERSONAL_TOKEN }
if (-not $Token) {
    Write-Error "Set `$env:ARTISYN_CONFLUENCE_TOKEN (or legacy `$env:AILA_CONFLUENCE_TOKEN / `$env:CONFLUENCE_PERSONAL_TOKEN) first."
    exit 3
}
$BaseUrl = if ($env:ARTISYN_CONFLUENCE_URL) { $env:ARTISYN_CONFLUENCE_URL.TrimEnd('/') }
           elseif ($env:AILA_CONFLUENCE_URL) { $env:AILA_CONFLUENCE_URL.TrimEnd('/') }
           else                              { "https://conf.dataart.com" }
$Space   = if ($env:ARTISYN_CONFLUENCE_SPACE) { $env:ARTISYN_CONFLUENCE_SPACE }
           elseif ($env:AILA_CONFLUENCE_SPACE) { $env:AILA_CONFLUENCE_SPACE }
           else                                { "SRD" }

# DataArt internal CA — skip cert checks like the .sh version (-k).
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $SkipCert = @{ SkipCertificateCheck = $true }
} else {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    $SkipCert = @{}
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "==> uv not found; installing via the official installer..."
    Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
    $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
}

$Headers = @{ Authorization = "Bearer $Token"; Accept = "application/json" }

# --- Find release page ---
if ($Version) {
    Write-Host "==> Looking up release page v$Version on $BaseUrl ..."
    $resp = Invoke-RestMethod -Method Get `
        -Uri "$BaseUrl/rest/api/content?type=page&title=v$Version&spaceKey=$Space" `
        -Headers $Headers @SkipCert
} else {
    Write-Host "==> Looking up current artisyn-stable release on $BaseUrl ..."
    $cql = [System.Web.HttpUtility]::UrlEncode('label in ("artisyn-stable", "aila-stable") AND space = "' + $Space + '" AND type = page')
    $resp = Invoke-RestMethod -Method Get `
        -Uri "$BaseUrl/rest/api/content/search?cql=$cql&limit=1" `
        -Headers $Headers @SkipCert
}

$node = if ($resp.results -and $resp.results.Count -gt 0) {
    if ($resp.results[0].content) { $resp.results[0].content } else { $resp.results[0] }
} else { $null }

if (-not $node) {
    if ($Version) { Write-Error "No release page titled `"v$Version`" in space $Space." }
    else          { Write-Error "No page labelled artisyn-stable (or legacy aila-stable) in space $Space." }
    exit 5
}
$PageId = $node.id
Write-Host "    page id: $PageId"

# --- List attachments + download ALL wheels ---
# The CLI lives in catalog-schema, but since STORY-0005b artisyn-catalog-schema
# declares a real dependency on artisyn-skill-sdk (and neither inter-package
# wheel is on a public registry). So download every wheel on the page and
# `uv tool install` the catalog-schema wheel with --find-links pointing at the
# local dir, so the sibling deps resolve offline.
Write-Host "==> Listing attachments..."
$atts = Invoke-RestMethod -Method Get `
    -Uri "$BaseUrl/rest/api/content/$PageId/child/attachment?limit=200" `
    -Headers $Headers @SkipCert

$wheels = $atts.results | Where-Object { $_.title -like '*.whl' }
if (-not $wheels) {
    Write-Error "No *.whl attachments on page $PageId."
    exit 6
}

# --- Download every wheel to a temp dir; remember the catalog-schema one ---
$Tmp = Join-Path $env:TEMP ("artisyn-bootstrap-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $Tmp | Out-Null
$WheelPath = $null
foreach ($w in $wheels) {
    $dest = Join-Path $Tmp $w.title
    Write-Host "==> Downloading $($w.title) ..."
    Invoke-WebRequest -Uri "$BaseUrl$($w._links.download)" -Headers $Headers -OutFile $dest @SkipCert
    if ($w.title -like 'artisyn_catalog_schema-*.whl' -or $w.title -like 'aila_catalog_schema-*.whl') {
        $WheelPath = $dest
    }
}

if (-not $WheelPath) {
    Write-Error "No (artisyn|aila)_catalog_schema-*.whl among attachments on page $PageId."
    exit 6
}
Write-Host "    CLI wheel: $(Split-Path $WheelPath -Leaf)"

# --- uv tool install (resolve sibling wheels from the downloaded dir) ---
Write-Host "==> uv tool install $(Split-Path $WheelPath -Leaf) (--find-links $Tmp) ..."
& uv tool install --force --find-links "$Tmp" "$WheelPath"

if (-not $NoChain) {
    $args = @("install")
    if ($Version) { $args += @("--version", $Version) }
    if ($Here)    { $args += "--here" }
    if ($Name)    { $args += @("--name", $Name) }
    if ($Skills)  { $args += @("--skills", $Skills) }
    Write-Host "==> artisyn-workspace $($args -join ' ')"
    & artisyn-workspace @args
} else {
    Write-Host ""
    Write-Host "✓ CLI installed.  Run: artisyn-workspace install --version $Version"
}
