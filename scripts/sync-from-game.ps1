$ErrorActionPreference = 'Stop'

$labRoot = Split-Path -Parent $PSScriptRoot
$gameRoot = Join-Path (Split-Path -Parent $labRoot) 'game-project'

$sources = @{
  'src/components/modals/robot/TargetMarker.vue' = 'src/components/TargetMarker.vue'
  'src/components/modals/robot/CustomMarkerModal.vue' = 'src/components/CustomMarkerModal.vue'
  'src/components/modals/robot/FontSelectModal.vue' = 'src/components/FontSelectModal.vue'
  'src/components/modals/robot/BaseHudModal.vue' = 'src/components/BaseHudModal.vue'
  'src/components/modals/data/textFontPresets.js' = 'src/data/textFontPresets.js'
  'src/components/useScale.js' = 'src/useScale.js'
  'src/assets/fonts/markerFonts.css' = 'src/assets/fonts/markerFonts.css'
  'src/assets/fonts/magic-ring.ttf' = 'src/assets/fonts/magic-ring.ttf'
  'src/assets/fonts/alien-script.ttf' = 'src/assets/fonts/alien-script.ttf'
  'src/assets/fonts/isekai-Regular.otf' = 'src/assets/fonts/isekai-Regular.otf'
  'src/assets/fonts/Neko_no_Mezame.ttf' = 'src/assets/fonts/Neko_no_Mezame.ttf'
  'src/assets/fonts/TECHNOID.TTF' = 'src/assets/fonts/TECHNOID.TTF'
  'src/assets/fonts/TechVermin-Regular.otf' = 'src/assets/fonts/TechVermin-Regular.otf'
  'src/assets/fonts/TechVermin-Italic.otf' = 'src/assets/fonts/TechVermin-Italic.otf'
}

foreach ($entry in $sources.GetEnumerator()) {
  $source = Join-Path $gameRoot $entry.Key
  $destination = Join-Path $labRoot $entry.Value
  if (-not (Test-Path -LiteralPath $source)) {
    throw "Source file was not found: $source"
  }

  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath $source -Destination $destination -Force
  Write-Host "Copied $($entry.Key)"
}

$presetSource = Join-Path $gameRoot 'src/components/modals/data/targetMarkerPresets'
$presetDestination = Join-Path $labRoot 'src/data/targetMarkerPresets'
if (-not (Test-Path -LiteralPath $presetSource)) {
  throw "Target marker preset directory was not found: $presetSource"
}

New-Item -ItemType Directory -Path $presetDestination -Force | Out-Null
$presetFiles = Get-ChildItem -LiteralPath $presetSource -File -Filter '*.json'
if ($presetFiles.Count -eq 0) {
  throw "No target marker preset JSON files were found: $presetSource"
}

foreach ($presetFile in $presetFiles) {
  Copy-Item -LiteralPath $presetFile.FullName -Destination (Join-Path $presetDestination $presetFile.Name) -Force
  Write-Host "Copied target marker preset $($presetFile.Name)"
}

$utf8 = [System.Text.UTF8Encoding]::new($false)
$targetMarkerPath = Join-Path $labRoot 'src/components/TargetMarker.vue'
$targetMarker = [System.IO.File]::ReadAllText($targetMarkerPath, $utf8)
$spMarkerPattern = '(?s)\s*<div v-if="generation === 9" class="genSp-illust-wrap">.*?</div>\s*(?=<div class="tri-frame")'

if ($targetMarker -notmatch $spMarkerPattern) {
  throw 'Could not remove the game-only SP marker template. Update this sync script for the changed source markup.'
}

$targetMarker = [regex]::Replace($targetMarker, $spMarkerPattern, "`n    ", 1)
$targetMarker = $targetMarker -replace "\r?\nimport \{ getUillust \} from '@/constants/statData\.js'", ''
[System.IO.File]::WriteAllText($targetMarkerPath, $targetMarker, $utf8)

$modalPath = Join-Path $labRoot 'src/components/CustomMarkerModal.vue'
$modal = [System.IO.File]::ReadAllText($modalPath, $utf8)
$modal = $modal -replace "@/components/useScale\.js", '../useScale.js'
[System.IO.File]::WriteAllText($modalPath, $modal, $utf8)

$mainPath = Join-Path $labRoot 'src/main.js'
$main = [System.IO.File]::ReadAllText($mainPath, $utf8)
if ($main -notmatch "assets/fonts/markerFonts\.css") {
  $main = $main -replace "import './style\.css'", "import './style.css'`r`nimport './assets/fonts/markerFonts.css'"
  [System.IO.File]::WriteAllText($mainPath, $main, $utf8)
}

Write-Host 'Removed game-only imports and adjusted standalone paths.'
