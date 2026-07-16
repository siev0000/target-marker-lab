<script setup>
import { ref } from 'vue'
import CustomMarkerModal from './components/CustomMarkerModal.vue'
import TargetMarker from './components/TargetMarker.vue'

const STORAGE_KEY = 'target-marker-lab-settings-v1'

function loadSettings() {
  try {
    const stored = localStorage.getItem(STORAGE_KEY)
    return stored ? JSON.parse(stored) : {}
  } catch {
    return {}
  }
}

const markerSettings = ref(loadSettings())
const editorOpen = ref(true)
const importError = ref('')
const fileInput = ref(null)

function saveSettings(settings) {
  markerSettings.value = settings
  localStorage.setItem(STORAGE_KEY, JSON.stringify(settings))
}

function exportSettings() {
  const blob = new Blob([JSON.stringify(markerSettings.value, null, 2)], {
    type: 'application/json'
  })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = 'target-marker-settings.json'
  link.click()
  URL.revokeObjectURL(url)
}

async function importSettings(event) {
  const [file] = event.target.files
  if (!file) return

  try {
    const imported = JSON.parse(await file.text())
    if (!imported || typeof imported !== 'object' || Array.isArray(imported)) {
      throw new Error('invalid settings')
    }
    saveSettings(imported)
    editorOpen.value = true
    importError.value = ''
  } catch {
    importError.value = '設定JSONを読み込めませんでした。'
  } finally {
    event.target.value = ''
  }
}

function clearSettings() {
  markerSettings.value = {}
  localStorage.removeItem(STORAGE_KEY)
  editorOpen.value = true
}
</script>

<template>
  <main class="lab-shell">
    <section v-if="!editorOpen" class="lab-home">
      <header>
        <p class="eyebrow">STANDALONE EDITOR</p>
        <h1>Target Marker Lab</h1>
        <p>ゲーム本体と切り離したターゲットマーカー作成・検証ツールです。</p>
      </header>

      <div class="home-actions">
        <button class="primary" type="button" @click="editorOpen = true">エディタを開く</button>
        <button type="button" @click="exportSettings">JSONを書き出す</button>
        <button type="button" @click="fileInput?.click()">JSONを読み込む</button>
        <button type="button" @click="clearSettings">ローカル設定を初期化</button>
        <input ref="fileInput" type="file" accept="application/json" hidden @change="importSettings" />
      </div>
      <p v-if="importError" class="import-error">{{ importError }}</p>

      <section class="home-preview" aria-label="現在のマーカープレビュー">
        <TargetMarker marker-type="custom" :custom-marker-settings="markerSettings" />
      </section>
    </section>

    <CustomMarkerModal
      v-if="editorOpen"
      :settings="markerSettings"
      @save="saveSettings"
      @close="editorOpen = false"
    />
  </main>
</template>
