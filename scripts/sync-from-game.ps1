$ErrorActionPreference = 'Stop'

$labRoot = Split-Path -Parent $PSScriptRoot
$gameRoot = Join-Path (Split-Path -Parent $labRoot) 'game-project'

$sources = @{
  'src/components/modals/robot/TargetMarker.vue' = 'src/components/TargetMarker.vue'
  'src/components/modals/robot/CustomMarkerModal.vue' = 'src/components/CustomMarkerModal.vue'
  'src/components/modals/robot/BaseHudModal.vue' = 'src/components/BaseHudModal.vue'
  'src/components/useScale.js' = 'src/useScale.js'
}

foreach ($entry in $sources.GetEnumerator()) {
  $source = Join-Path $gameRoot $entry.Key
  $destination = Join-Path $labRoot $entry.Value
  if (-not (Test-Path -LiteralPath $source)) {
    throw "Source file was not found: $source"
  }

  Copy-Item -LiteralPath $source -Destination $destination -Force
  Write-Host "Copied $($entry.Key)"
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

Write-Host 'Removed game-only imports and adjusted standalone paths.'
