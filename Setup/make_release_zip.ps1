$ErrorActionPreference = 'Stop'

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$pluginDir = 'C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter'
$pluginFile = Join-Path $pluginDir 'Aul2AudioFilter.auf2'
$readmeFile = Join-Path $projectRoot 'README.md'
$tailNoiseName = ([string][char]0x7121) + ([string][char]0x97f3) + '_' +
  ([string][char]0x6975) + ([string][char]0x5c0f) +
  ([string][char]0x30ce) + ([string][char]0x30a4) + ([string][char]0x30ba) + '_' +
  ([string][char]0x30eb) + ([string][char]0x30fc) + ([string][char]0x30d7) +
  ([string][char]0x63a8) + ([string][char]0x5968) + '.wav'
$tailNoiseFile = Join-Path (Join-Path $projectRoot 'Sample') $tailNoiseName
$packageName = 'Aul2AudioFilter'
$workDir = Join-Path $PSScriptRoot $packageName
$zipFile = Join-Path $PSScriptRoot "$packageName.zip"

if (-not (Test-Path -LiteralPath $pluginFile)) {
  Write-Host 'Plugin file not found:'
  Write-Host "  $pluginFile"
  Write-Host 'Build the project first, then run this batch again.'
  exit 1
}

if (-not (Test-Path -LiteralPath $readmeFile)) {
  Write-Host 'README not found:'
  Write-Host "  $readmeFile"
  exit 1
}

if (-not (Test-Path -LiteralPath $tailNoiseFile)) {
  Write-Host 'Silent noise tail WAV not found:'
  Write-Host "  $tailNoiseFile"
  exit 1
}

if (Test-Path -LiteralPath $workDir) {
  Remove-Item -LiteralPath $workDir -Recurse -Force
}

if (Test-Path -LiteralPath $zipFile) {
  Remove-Item -LiteralPath $zipFile -Force
}

$sampleDir = Join-Path $workDir 'Sample'
New-Item -ItemType Directory -Path $sampleDir -Force | Out-Null
Copy-Item -LiteralPath $pluginFile -Destination (Join-Path $workDir 'Aul2AudioFilter.auf2') -Force
Copy-Item -LiteralPath $readmeFile -Destination (Join-Path $workDir 'README.md') -Force
Copy-Item -LiteralPath $tailNoiseFile -Destination (Join-Path $sampleDir $tailNoiseName) -Force

Compress-Archive -Path $workDir -DestinationPath $zipFile -Force
Remove-Item -LiteralPath $workDir -Recurse -Force

Write-Host 'Created:'
Write-Host "  $zipFile"
