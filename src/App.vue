<script setup>
import { ref } from 'vue'
import CustomMarkerModal from './components/CustomMarkerModal.vue'
import TargetMarker from './components/TargetMarker.vue'
import magicCircle from './data/targetMarkerPresets/magic-circle.json'
import symbolMagicCircle from './data/targetMarkerPresets/symbol-magic-circle.json'

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
const editorOpen = ref(false)
const importError = ref('')
const fileInput = ref(null)
const mobileMenuOpen = ref(false)
const activePublicTab = ref('about')

const publicNav = [
  { id: 'about', label: '説明' },
  { id: 'how-to-use', label: '使い方' },
  { id: 'examples', label: '作成例' },
  { id: 'faq', label: 'FAQ' },
  { id: 'privacy', label: 'プライバシー' }
]

const examples = [
  { title: '魔法陣', description: '複数のリングと発光で、詠唱や範囲攻撃の予兆を表現。', settings: magicCircle.settings },
  { title: '記号魔法陣', description: '記号・文字・アニメーションを重ねた、情報量の多いマーカー。', settings: symbolMagicCircle.settings }
]

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

function openEditor() {
  mobileMenuOpen.value = false
  editorOpen.value = true
}

function selectPublicTab(id) {
  mobileMenuOpen.value = false
  activePublicTab.value = id
}
</script>

<template>
  <main class="lab-shell">
    <section v-if="!editorOpen" class="lab-home">
      <div class="public-topbar">
        <header class="public-header">
          <div class="brand-block">
            <p class="eyebrow">STANDALONE EDITOR</p>
            <h1>Target Marker Lab</h1>
            <p>ゲーム本体と切り離したターゲットマーカー作成・検証ツールです。</p>
          </div>
          <button class="header-editor-cta" type="button" @click="openEditor">エディタを開く</button>
        </header>

        <div class="public-tabs" role="tablist" aria-label="サイト情報">
          <button v-for="item in publicNav" :key="item.id" type="button" role="tab" :aria-selected="activePublicTab === item.id" :class="{ active: activePublicTab === item.id }" @click="selectPublicTab(item.id)">{{ item.label }}</button>
        </div>
      </div>

      <section v-if="activePublicTab === 'about'" class="public-hero" aria-labelledby="hero-title">
        <div>
          <p class="eyebrow">DESIGN / PREVIEW / EXPORT</p>
          <h2 id="hero-title">ゲームに使うターゲットマーカーを、ブラウザで作る。</h2>
          <p>リング、形状、色、発光、分割、移動時の状態までを確認しながら、使いたい見た目を組み立てられます。</p>
          <button class="primary hero-cta" type="button" @click="openEditor">無料で作成を始める</button>
        </div>
        <div class="home-preview hero-preview" aria-label="現在のマーカープレビュー">
          <TargetMarker marker-type="custom" :custom-marker-settings="markerSettings" />
        </div>
      </section>

      <div v-if="activePublicTab === 'about'" class="home-actions">
        <button type="button" @click="exportSettings">JSONを書き出す</button>
        <button type="button" @click="fileInput?.click()">JSONを読み込む</button>
        <button type="button" @click="clearSettings">ローカル設定を初期化</button>
        <input ref="fileInput" type="file" accept="application/json" hidden @change="importSettings" />
      </div>
      <p v-if="importError && activePublicTab === 'about'" class="import-error">{{ importError }}</p>

      <section v-if="activePublicTab === 'about'" id="about" class="public-section" role="tabpanel">
        <p class="eyebrow">ABOUT</p>
        <h2>Target Marker Labの説明</h2>
        <p>Target Marker Labは、ゲーム画面に表示するターゲットマーカーを単体でデザインするためのツールです。作った設定はブラウザに保存でき、JSONとして持ち出せます。</p>
        <div class="feature-grid"><article><strong>細かく編集</strong><span>リングごとの形状・色・発光・文字を調整。</span></article><article><strong>状態を比較</strong><span>停止時と移動時の見た目を切り替えて確認。</span></article><article><strong>データを持ち出す</strong><span>JSON保存で別プロジェクトへ移行。</span></article></div>
      </section>

      <section v-else-if="activePublicTab === 'how-to-use'" id="how-to-use" class="public-section" role="tabpanel">
        <p class="eyebrow">HOW TO USE</p>
        <h2>使い方</h2>
        <ol class="step-list"><li><strong>エディタを開く</strong><span>「無料で作成を始める」から編集画面へ進みます。</span></li><li><strong>マーカーを調整する</strong><span>レイヤーを追加し、色・形・動き・表示状態を編集します。</span></li><li><strong>保存・書き出しする</strong><span>ブラウザ保存またはJSON保存で設定を残します。</span></li></ol>
      </section>

      <section v-else-if="activePublicTab === 'examples'" id="examples" class="public-section" role="tabpanel">
        <p class="eyebrow">EXAMPLES</p>
        <h2>作成例</h2>
        <div class="example-grid"><article v-for="example in examples" :key="example.title" class="example-card"><div class="example-preview"><TargetMarker marker-type="custom" :custom-marker-settings="example.settings" /></div><h3>{{ example.title }}</h3><p>{{ example.description }}</p></article></div>
      </section>

      <section v-else-if="activePublicTab === 'faq'" id="faq" class="public-section faq-section" role="tabpanel">
        <p class="eyebrow">FAQ</p>
        <h2>よくある質問</h2>
        <details><summary>無料で使えますか？</summary><p>現在の機能は無料で利用できます。広告掲載など、公開後の運営方法は変更される場合があります。</p></details>
        <details><summary>作ったデータはどこに保存されますか？</summary><p>通常はこのブラウザのlocalStorageに保存されます。大切な設定はJSONを書き出して保管してください。</p></details>
        <details><summary>スマートフォンでも使えますか？</summary><p>スマートフォンでは、画面幅に合わせた編集画面とタッチ操作向けのメニューが表示されます。</p></details>
      </section>

      <section v-else-if="activePublicTab === 'privacy'" id="privacy" class="public-section privacy-section" role="tabpanel">
        <p class="eyebrow">PRIVACY POLICY</p>
        <h2>プライバシーポリシー</h2>
        <p>Target Marker Labは、マーカー設定を主に利用者のブラウザ内へ保存します。運営者が設定内容をサーバーへ送信・収集することはありません。</p>
        <p>広告を掲載する場合は、広告配信事業者がCookie等を利用して広告を配信することがあります。掲載開始前に、利用する事業者名、Cookieの扱い、問い合わせ先をこのページへ追記します。</p>
        <p class="policy-note">※公開前に運営者情報・問い合わせ先・広告サービスの正式な利用規約を確認して完成させてください。</p>
      </section>

      <footer class="public-footer"><span>Target Marker Lab</span><button type="button" @click="openEditor">エディタを開く</button></footer>
    </section>

    <CustomMarkerModal
      v-if="editorOpen"
      :settings="markerSettings"
      @save="saveSettings"
      @close="editorOpen = false"
    />
  </main>
</template>
