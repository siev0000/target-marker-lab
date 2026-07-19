<template>
  <Teleport to="body">
    <BaseHudModal
      :frame-width="previewFullscreen ? 'calc(100vw - 4px)' : '720px'"
      :frame-height="previewFullscreen ? 'calc(100vh - 4px)' : '1280px'"
      frame-max-height="none"
      frame-overflow="hidden"
      :frame-scale="previewFullscreen ? 1 : modalScale"
      :close-on-overlay="false"
      @close="$emit('close')"
    >
      <div class="custom-marker-modal" :class="{ 'preview-fullscreen-mode': previewFullscreen }">
      <header class="modal-header">
        <div>
          <div class="modal-kicker">TARGET MARKER</div>
          <h2>作成</h2>
        </div>
        <button type="button" class="close-button" @click="$emit('close')">閉じる</button>
      </header>

      <section
        class="marker-preview"
        :style="previewBackgroundStyle"
        @click="movePreviewToPointer"
        @dblclick.stop.prevent="exitPreviewFullscreen"
        @pointermove="movePreviewWithCursor"
        @pointerleave="endPreviewCursorFollow"
      >
        <div class="preview-label">PREVIEW</div>
        <div v-if="previewFullscreen" class="fullscreen-return-hint">DOUBLE CLICK / ESC / F : RETURN</div>
        <div class="preview-controls">
          <span>{{ previewMoving ? '移動時' : '停止時' }}</span>
          <span v-if="draft.behavior.followCursor" :class="{ tracking: previewCursorFollowActive }">
            {{ previewCursorFollowActive ? '追従中' : 'クリックで追従' }}
          </span>
          <button type="button" @click.stop="movePreviewToCenter">中央に戻す</button>
        </div>
        <div class="preview-target" :style="previewTargetStyle">
          <TargetMarker
            generation="1"
            marker-type="custom"
            :custom-marker-settings="draft"
            :is-target-moving="previewMoving"
            :highlight-ring-id="highlightedRingId"
          />
        </div>
      </section>

      <section class="editor-layout">
        <div class="editor-state-tabs" aria-label="編集する状態">
          <span>EDIT STATE</span>
          <button type="button" :class="{ active: editingState === 'idle' }" @click="selectEditingState('idle')">停止時</button>
          <button type="button" :class="{ active: editingState === 'moving' }" @click="selectEditingState('moving')">移動時</button>
          <button type="button" class="state-copy-button" @click="copyEditingStateToOther">
            {{ editingState === 'idle' ? '停止→移動へコピー' : '移動→停止へコピー' }}
          </button>
        </div>
        <div class="ring-tabs" aria-label="編集するリング">
          <span class="ring-tabs-label">EDIT RING</span>
          <button
            type="button"
            class="ring-tab-add"
            :disabled="draft.rings.length >= MAX_RINGS"
            :title="draft.rings.length >= MAX_RINGS ? `レイヤーは${MAX_RINGS}個までです` : 'レイヤーを追加'"
            aria-label="リングを追加"
            @click="addRing"
          >
            ＋
          </button>
          <div class="ring-tabs-list">
            <button
              v-for="(ring, index) in draft.rings"
              :key="ring.id"
              type="button"
              :class="{ active: selectedRingId === ring.id, hidden: getRingAppearance(ring).visible === false }"
               :title="`${getRingName(ring, index)}を編集`"
              @click="selectRing(ring.id)"
            >
              <span class="ring-tab-color" :style="{ backgroundColor: getRingAppearance(ring).color }"></span>
               <span>{{ getRingName(ring, index) }}</span>
            </button>
          </div>
        </div>
        <nav class="setting-list" aria-label="ターゲットマーカー設定">
          <button
            v-for="section in sections"
            :key="section.key"
            type="button"
            :class="{ active: activeSection === section.key }"
            @click="activeSection = section.key"
          >
            {{ section.label }}
          </button>
        </nav>

        <div class="setting-content">
          <template v-if="activeSection === 'library'">
            <h3>保存マーカー</h3>
            <p>作成中のマーカーへ名前を付け、最大20件までこのブラウザに保存できます。</p>
            <label class="library-name-row">
              <span>保存名</span>
              <input v-model="libraryName" type="text" maxlength="32" placeholder="マーカー名" />
            </label>
            <div class="library-toolbar">
              <button type="button" :disabled="savedMarkers.length >= MAX_SAVED_MARKERS" @click="saveNewMarker">新規保存</button>
              <button type="button" :disabled="!selectedSavedMarkerId" @click="overwriteSavedMarker">選択中へ上書き</button>
              <button type="button" @click="exportMarkerSettings">JSON保存</button>
              <button type="button" @click="openMarkerSettingsFile">JSON読込</button>
            </div>
            <input ref="markerSettingsFileInput" class="marker-settings-file-input" type="file" accept="application/json,.json" @change="importMarkerSettings" />
            <p class="library-export-note">作成中の停止時・移動時設定をJSONとしてコピー・保存・読込できます。読込内容は決定するまで戦闘画面へ反映されません。</p>
            <div v-if="libraryNotice" class="library-notice">{{ libraryNotice }}</div>
            <div v-if="savedMarkers.length === 0" class="library-empty">保存されたマーカーはありません。</div>
            <div v-else class="marker-library-list">
              <article
                v-for="marker in savedMarkers"
                :key="marker.id"
                :class="{ active: selectedSavedMarkerId === marker.id }"
              >
                <button type="button" class="library-marker-summary" @click="selectSavedMarker(marker)">
                  <span class="library-marker-color" :style="{ backgroundColor: marker.settings?.color || '#8fefff' }"></span>
                  <span class="library-marker-name">{{ marker.name }}</span>
                  <span class="library-marker-meta">{{ marker.settings?.rings?.length || 0 }}リング</span>
                </button>
                <div class="library-marker-actions">
                  <button type="button" @click="loadSavedMarker(marker)">読込</button>
                  <button type="button" class="library-delete-button" @click="deleteSavedMarker(marker.id)">削除</button>
                </div>
              </article>
            </div>
          </template>

          <template v-else-if="activeSection === 'existing'">
            <h3>既存マーカー</h3>
            <p>選択したマーカーを、編集可能なリング設定として作成中データへ反映します。</p>
            <div class="preset-notice">現在のリング設定は選択したプリセットで置き換わります。</div>
            <div class="existing-preset-grid">
              <button
                v-for="preset in existingMarkerPresets"
                :key="preset.key"
                type="button"
                :class="{ active: appliedPresetKey === preset.key }"
                @click="applyExistingMarkerPreset(preset)"
              >
                <span class="preset-color" :style="{ backgroundColor: preset.color }"></span>
                <span>{{ preset.label }}</span>
              </button>
            </div>
          </template>

          <template v-else-if="activeSection === 'display'">
            <h3>表示設定</h3>
            <p>上部プレビューの背景と確認方法を設定します。</p>
            <label class="setting-row">
              <span>背景色</span>
              <input v-model="draft.behavior.previewBackgroundColor" type="color" />
              <code>{{ draft.behavior.previewBackgroundColor }}</code>
            </label>
            <label class="toggle-row">
              <input v-model="draft.behavior.previewGradientEnabled" type="checkbox" />
              <span>背景グラデーションを表示</span>
            </label>
            <label class="toggle-row">
              <input v-model="draft.behavior.followCursor" type="checkbox" @change="onFollowCursorSettingChange" />
              <span>上部プレビューでカーソル追従</span>
            </label>
            <label v-if="draft.behavior.followCursor" class="setting-row">
              <span>移動速度</span>
              <input v-model.number="draft.behavior.cursorFollowSpeed" type="range" min="10" max="300" step="5" />
              <output>{{ draft.behavior.cursorFollowSpeed }}%/秒</output>
            </label>
            <div class="setting-note">ON時は上部プレビューをクリックすると追従開始、もう一度クリックすると停止します。カーソル移動中は移動時設定を表示します。</div>
            <button type="button" class="preview-fullscreen-button" @click="enterPreviewFullscreen">プレビューを全面表示</button>
          </template>

          <template v-else-if="activeSection === 'overall'">
            <h3>全体設定</h3>
            <p>マーカー全体の形、サイズ、表示を設定します。</p>
            <details class="danger-settings">
              <summary>全リングの形状を一括変更</summary>
              <p>すべてのリング形状を書き換えます。個別に設定した形状は失われます。</p>
              <div class="choice-grid">
                <button
                  v-for="shape in shapes"
                  :key="shape.key"
                  type="button"
                  :class="{ active: selectedOverall.shape === shape.key }"
                  @click="requestOverallShapeChange(shape.key)"
                >
                  {{ shape.label }}
                </button>
              </div>
              <div v-if="pendingOverallShape" class="shape-confirmation">
                <strong>全リングを「{{ shapeLabel(pendingOverallShape) }}」へ変更しますか？</strong>
                <div>
                  <button type="button" @click="confirmOverallShapeChange">変更する</button>
                  <button type="button" @click="pendingOverallShape = null">キャンセル</button>
                </div>
              </div>
            </details>
            <label class="setting-row">
              <span>サイズ</span>
              <input v-model.number="selectedOverall.size" type="range" min="60" max="150" step="1" />
              <output>{{ selectedOverall.size }}%</output>
            </label>
            <label class="setting-row">
              <span>全体の透明度</span>
              <input v-model.number="selectedOverall.opacity" type="range" min="25" max="100" step="1" />
              <output>{{ selectedOverall.opacity }}%</output>
            </label>
            <label class="toggle-row">
              <input v-model="selectedOverall.showCenterDot" type="checkbox" />
              <span>中央点を表示</span>
            </label>
            <div class="transition-settings">
              <h3>移動変形</h3>
              <p>停止時と移動時の形状を切り替える順序と時間を設定します。</p>
              <label class="setting-row select-row">
                <span>実行順</span>
                <select v-model="draft.transition.sequence">
                  <option value="before">変形してから移動</option>
                  <option value="simultaneous">移動しながら変形</option>
                  <option value="after">移動してから変形</option>
                </select>
              </label>
              <label class="setting-row">
                <span>移動形状へ</span>
                <input v-model.number="draft.transition.morphInDuration" type="range" min="0" max="1500" step="50" />
                <output>{{ draft.transition.morphInDuration }}ms</output>
              </label>
              <label class="setting-row">
                <span>移動時間</span>
                <input v-model.number="draft.transition.moveDuration" type="range" min="100" max="2000" step="50" />
                <output>{{ draft.transition.moveDuration }}ms</output>
              </label>
              <label class="setting-row">
                <span>停止形状へ</span>
                <input v-model.number="draft.transition.morphOutDuration" type="range" min="0" max="1500" step="50" />
                <output>{{ draft.transition.morphOutDuration }}ms</output>
              </label>
              <label class="setting-row select-row">
                <span>変化方法</span>
                <select v-model="draft.transition.easing">
                  <option value="linear">一定</option>
                  <option value="ease-in-out">滑らか</option>
                  <option value="ease-in">加速</option>
                  <option value="ease-out">減速</option>
                </select>
              </label>
            </div>
          </template>

          <template v-else-if="activeSection === 'rings'">
            <div class="section-heading">
              <div>
                <h3>リング</h3>
                <p>追加したリングごとに表示設定を変更できます。</p>
              </div>
              <div class="ring-action-buttons">
                <button type="button" :disabled="draft.rings.length >= MAX_RINGS" @click="duplicateSelectedRing">複製</button>
                <button type="button" :disabled="selectedRingIndex <= 0" @click="moveSelectedRing(-1)">後ろへ</button>
                <button type="button" :disabled="selectedRingIndex >= draft.rings.length - 1" @click="moveSelectedRing(1)">前へ</button>
              </div>
            </div>
            <div class="render-mode-grid">
              <button
                v-for="mode in renderModes"
                :key="mode.key"
                type="button"
                :class="{ active: selectedRingAppearance.renderMode === mode.key }"
                @click="setRenderMode(mode.key)"
              >
                {{ mode.label }}
              </button>
            </div>
            <p class="render-mode-description">
              {{ renderModes.find(mode => mode.key === selectedRingAppearance.renderMode)?.description }}
            </p>
            <label v-if="!['segmentedArc', 'connection'].includes(selectedRingAppearance.renderMode)" class="setting-row select-row">
              <span>形状</span>
              <select v-model="selectedRingAppearance.shape" @change="onRingShapeChange">
                <option v-for="shape in shapes" :key="shape.key" :value="shape.key">{{ shape.label }}</option>
              </select>
            </label>
            <label class="setting-row">
              <span>色</span>
              <input v-model="selectedRingAppearance.color" type="color" />
              <code>{{ selectedRingAppearance.color }}</code>
            </label>
            <label v-if="selectedRingAppearance.renderMode !== 'textRing'" class="setting-row">
              <span>横幅</span>
              <input v-model.number="selectedRingAppearance.width" type="range" min="1" max="140" step="1" />
              <output>{{ selectedRingAppearance.width }}%</output>
            </label>
            <label v-if="selectedRingAppearance.renderMode !== 'textRing'" class="setting-row">
              <span>縦幅</span>
              <input v-model.number="selectedRingAppearance.height" type="range" min="1" max="140" step="1" />
              <output>{{ selectedRingAppearance.height }}%</output>
            </label>
            <label v-if="['segmentedArc', 'circumference', 'connection'].includes(selectedRingAppearance.renderMode) || (selectedRingAppearance.renderMode === 'textRing' && selectedRingAppearance.textMode === 'labels')" class="setting-row">
              <span>分割数</span>
              <input v-model.number="selectedRingAppearance.splitCount" type="range" :min="selectedRingAppearance.renderMode === 'connection' ? 2 : 1" :max="selectedRingAppearance.renderMode === 'textRing' ? 64 : 8" step="1" />
              <output>{{ selectedRingAppearance.splitCount }}</output>
            </label>
            <template v-if="selectedRingAppearance.renderMode === 'textRing'">
              <label class="setting-row select-row">
                <span>文字の入力方法</span>
                <select v-model="selectedRingAppearance.textMode">
                  <option value="string">連続文字列</option>
                  <option value="labels">個別ラベル</option>
                </select>
              </label>
              <label v-if="selectedRingAppearance.textMode === 'string'" class="setting-row text-setting-row">
                <span>文字列</span>
                <input v-model="selectedRingAppearance.textContent" class="text-value-input" type="text" maxlength="64" placeholder="TARGET LOCKED" />
                <output>{{ countTextCharacters(selectedRingAppearance.textContent) }}/64</output>
              </label>
              <label v-if="selectedRingAppearance.textMode === 'string'" class="setting-row">
                <span>文字の分割数</span>
                <input v-model.number="selectedRingAppearance.textDivisionCount" type="range" min="1" max="8" step="1" />
                <output>{{ selectedRingAppearance.textDivisionCount }}</output>
              </label>
              <p v-if="selectedRingAppearance.textMode === 'string' && selectedRingAppearance.textDivisionCount > 1" class="setting-hint">文字列を分割片ごとに割り当て、選択した形状の輪郭に沿って配置します。</p>
              <div v-if="selectedRingAppearance.textMode === 'labels'" class="segment-label-grid">
                <label v-for="index in selectedRingItemCount" :key="index">
                  <span>{{ index }}</span>
                  <input v-model="selectedRingAppearance.segmentLabels[index - 1]" type="text" maxlength="8" />
                </label>
              </div>
              <label class="setting-row select-row">
                <span>文字の配置</span>
                <select v-model="selectedRingAppearance.textLayout">
                  <option value="circle">円周</option>
                  <option value="shape">形状に沿う</option>
                </select>
              </label>
              <label class="setting-row select-row">
                <span>配置基準リング</span>
                <select v-model="selectedRingAppearance.textReferenceRingId">
                  <option value="self">この文字リング</option>
                  <option
                    v-for="(ring, index) in draft.rings"
                    :key="ring.id"
                    :value="ring.id"
                    :disabled="ring.id === selectedRing.id"
                  >{{ getRingName(ring, index) }}</option>
                </select>
              </label>
              <p v-if="selectedRingAppearance.textReferenceRingId !== 'self'" class="setting-hint">選択したリングの形・縦横比・角度・位置に文字を合わせます。</p>
              <label v-if="selectedRingAppearance.textReferenceRingId !== 'self'" class="setting-row">
                <span>基準からの大きさ</span>
                <input v-model.number="selectedRingAppearance.textReferenceScale" type="range" min="50" max="160" step="1" />
                <output>{{ selectedRingAppearance.textReferenceScale }}%</output>
              </label>
              <p v-if="selectedRingAppearance.textLayout === 'shape'" class="setting-hint">円・四角・三角・菱形・星・G5オービットの輪郭に沿って配置します。</p>
              <label v-if="selectedRingAppearance.textLayout !== 'shape'" class="setting-row">
                <span>配置半径</span>
                <input v-model.number="selectedRingAppearance.textRadius" type="range" min="0" max="70" step="1" />
                <output>{{ selectedRingAppearance.textRadius }}%</output>
              </label>
              <label v-if="!selectedRingAppearance.textEvenSpacing" class="setting-row">
                <span>文字間隔</span>
                <input v-model.number="selectedRingAppearance.textSpacing" type="range" min="25" max="200" step="5" />
                <output>{{ selectedRingAppearance.textSpacing }}%</output>
              </label>
              <label class="toggle-row">
                <input v-model="selectedRingAppearance.textEvenSpacing" type="checkbox" />
                <span>文字を均等配置する</span>
              </label>
              <label v-if="selectedRingAppearance.textEvenSpacing" class="setting-row">
                <span>配置範囲</span>
                <input v-model.number="selectedRingAppearance.textArcSpread" type="range" min="1" max="360" step="1" />
                <output>{{ selectedRingAppearance.textLayout === 'shape' ? Math.round(selectedRingAppearance.textArcSpread / 360 * 100) + '%' : selectedRingAppearance.textArcSpread + '°' }}</output>
              </label>
              <label class="setting-row">
                <span>{{ selectedRingAppearance.textLayout === 'shape' ? '開始位置' : '開始角度' }}</span>
                <input v-model.number="selectedRingAppearance.arcAngle" type="range" min="0" max="359" step="1" />
                <output>{{ selectedRingAppearance.textLayout === 'shape' ? Math.round(selectedRingAppearance.arcAngle / 359 * 100) + '%' : selectedRingAppearance.arcAngle + '°' }}</output>
              </label>
              <label class="setting-row">
                <span>文字サイズ</span>
                <input v-model.number="selectedRingAppearance.textSize" type="range" min="6" max="40" step="1" />
                <output>{{ selectedRingAppearance.textSize }}px</output>
              </label>
              <label class="setting-row select-row">
                <span>文字の太さ</span>
                <select v-model="selectedRingAppearance.textWeight">
                  <option value="normal">標準</option>
                  <option value="bold">太字</option>
                </select>
              </label>
              <label class="setting-row select-row">
                <span>配置方向</span>
                <select v-model="selectedRingAppearance.textDirection">
                  <option value="clockwise">時計回り</option>
                  <option value="counterclockwise">反時計回り</option>
                </select>
              </label>
              <label class="setting-row select-row">
                <span>文字の向き</span>
                <select v-model="selectedRingAppearance.textOrientation">
                  <option value="outward">外向き</option>
                  <option value="inward">内向き</option>
                  <option value="centerFacing">中央へ頭を向ける</option>
                  <option value="upright">常に正立</option>
                  <option value="tangent">輪郭に沿う</option>
                </select>
              </label>
            </template>
            <label v-if="selectedRingAppearance.renderMode === 'circumference' && selectedRingAppearance.splitCount > 1" class="toggle-row">
              <input v-model="selectedRingAppearance.equalizeSegments" type="checkbox" />
              <span>分割片を正形にする</span>
            </label>
            <label v-if="selectedRingAppearance.renderMode === 'circumference' && selectedRingAppearance.splitCount > 1" class="toggle-row">
              <input v-model="selectedRingAppearance.evenSpacing" type="checkbox" />
              <span>分割片を均等配置する</span>
            </label>
            <label v-if="selectedRingAppearance.renderMode === 'segmentedArc'" class="setting-row">
              <span>円弧間隔</span>
              <input v-model.number="selectedRingAppearance.splitGap" type="range" min="0" max="20" step="1" />
              <output>{{ selectedRingAppearance.splitGap }}</output>
            </label>
            <label v-if="selectedRingAppearance.renderMode === 'circumference' && !selectedRingAppearance.evenSpacing" class="setting-row">
              <span>円弧角度</span>
              <input v-model.number="selectedRingAppearance.arcSpread" type="range" min="0" max="360" step="1" />
              <output>{{ selectedRingAppearance.arcSpread }}°</output>
            </label>
            <label v-if="['circumference', 'connection'].includes(selectedRingAppearance.renderMode)" class="setting-row">
              <span>{{ selectedRingAppearance.renderMode === 'connection' ? '接続半径' : '軌道半径' }}</span>
              <input v-model.number="selectedRingAppearance.arcRadius" type="range" min="0" max="70" step="1" />
              <output>{{ selectedRingAppearance.arcRadius }}%</output>
            </label>
            <label v-if="['circumference', 'connection'].includes(selectedRingAppearance.renderMode)" class="setting-row">
              <span>配置角度</span>
              <input v-model.number="selectedRingAppearance.arcAngle" type="range" min="0" max="359" step="1" />
              <output>{{ selectedRingAppearance.arcAngle }}°</output>
            </label>
            <label v-if="selectedRingAppearance.renderMode === 'circumference'" class="setting-row select-row">
              <span>円弧の向き</span>
              <select v-model="selectedRingAppearance.arcOrientation">
                <option value="tangent">接線方向</option>
                <option value="radial">中央方向</option>
                <option value="fixed">角度固定</option>
              </select>
            </label>
            <label v-if="!['connection', 'textRing'].includes(selectedRingAppearance.renderMode)" class="setting-row">
              <span>角度</span>
              <input v-model.number="selectedRingAppearance.angle" type="range" min="0" max="359" step="1" />
              <output>{{ selectedRingAppearance.angle }}°</output>
            </label>
            <template v-if="selectedRingAppearance.shape === 'magitechWave'">
              <p class="setting-group-label">G4ウェーブ</p>
              <label class="setting-row">
                <span>ブレ幅</span>
                <input v-model.number="selectedRingAppearance.waveAmplitude" type="range" min="0" max="10" step="0.5" />
                <output>{{ selectedRingAppearance.waveAmplitude }}</output>
              </label>
              <label class="setting-row">
                <span>波の数</span>
                <input v-model.number="selectedRingAppearance.waveCount" type="range" min="1" max="24" step="1" />
                <output>{{ selectedRingAppearance.waveCount }}</output>
              </label>
              <label class="setting-row">
                <span>ランダムさ</span>
                <input v-model.number="selectedRingAppearance.waveRandomness" type="range" min="0" max="100" step="1" />
                <output>{{ selectedRingAppearance.waveRandomness }}%</output>
              </label>
              <label class="setting-row">
                <span>揺れ速度</span>
                <input v-model.number="selectedRingAppearance.waveSpeed" type="range" min="0" max="3" step="0.1" />
                <output>{{ selectedRingAppearance.waveSpeed.toFixed(1) }}x</output>
              </label>
            </template>
            <label v-if="selectedRingAppearance.renderMode === 'connection'" class="toggle-row">
              <input v-model="selectedRingAppearance.connectionClosed" type="checkbox" />
              <span>最後の点を最初の点へ接続</span>
            </label>
            <label v-if="selectedRingAppearance.renderMode !== 'textRing'" class="setting-row select-row">
              <span>線種</span>
              <select v-model="selectedRingAppearance.lineStyle">
                <option value="solid">実線</option>
                <option value="dashed">破線</option>
                <option value="dotted">点線</option>
                <option value="double">二重線</option>
              </select>
            </label>
            <label v-if="selectedRingAppearance.renderMode !== 'textRing'" class="setting-row">
              <span>線の太さ</span>
              <input v-model.number="selectedRingAppearance.lineWidth" type="range" min="1" max="8" step="1" />
              <output>{{ selectedRingAppearance.lineWidth }}px</output>
            </label>
            <label class="setting-row">
              <span>透明度</span>
              <input v-model.number="selectedRingAppearance.opacity" type="range" min="10" max="100" step="1" />
              <output>{{ selectedRingAppearance.opacity }}%</output>
            </label>
            <label class="setting-row">
              <span>発光</span>
              <input v-model.number="selectedRingAppearance.glow" type="range" min="0" max="30" step="1" />
              <output>{{ selectedRingAppearance.glow }}</output>
            </label>
            <label class="setting-row">
              <span>発光色</span>
              <input v-model="selectedRingAppearance.glowColor" type="color" />
              <code>{{ selectedRingAppearance.glowColor }}</code>
            </label>
            <label v-if="!['segmentedArc', 'textRing'].includes(selectedRingAppearance.renderMode)" class="toggle-row">
              <input v-model="selectedRingAppearance.fillEnabled" type="checkbox" />
              <span>内側を塗る</span>
            </label>
            <template v-if="!['segmentedArc', 'textRing'].includes(selectedRingAppearance.renderMode) && selectedRingAppearance.fillEnabled">
              <label class="setting-row">
                <span>塗り色</span>
                <input v-model="selectedRingAppearance.fillColor" type="color" />
                <code>{{ selectedRingAppearance.fillColor }}</code>
              </label>
              <label class="setting-row">
                <span>塗り透明度</span>
                <input v-model.number="selectedRingAppearance.fillOpacity" type="range" min="0" max="100" step="1" />
                <output>{{ selectedRingAppearance.fillOpacity }}%</output>
              </label>
            </template>
            <label v-if="['circumference', 'textRing'].includes(selectedRingAppearance.renderMode) && selectedRingItemCount > 1" class="toggle-row">
              <input v-model="selectedRingAppearance.useSegmentColors" type="checkbox" />
              <span>分割片ごとに色を設定</span>
            </label>
            <div v-if="['circumference', 'textRing'].includes(selectedRingAppearance.renderMode) && selectedRingItemCount > 1 && selectedRingAppearance.useSegmentColors" class="segment-color-grid">
              <label v-for="index in selectedRingItemCount" :key="index">
                <span>{{ index }}</span>
                <input v-model="selectedRingAppearance.segmentColors[index - 1]" type="color" />
              </label>
            </div>
            <details class="ring-advanced-settings">
              <summary>詳細設定</summary>
              <p>このリングだけに適用する名前、位置、反転、重なり方、線の見た目を設定します。</p>
              <label class="setting-row text-setting-row">
                <span>リング名</span>
                <input v-model="selectedRing.name" class="text-value-input" type="text" maxlength="20" placeholder="リング名" />
              </label>
              <label class="setting-row">
                <span>横位置</span>
                <input v-model.number="selectedRingAppearance.offsetX" type="range" min="-50" max="50" step="1" />
                <output>{{ selectedRingAppearance.offsetX }}%</output>
              </label>
              <label class="setting-row">
                <span>縦位置</span>
                <input v-model.number="selectedRingAppearance.offsetY" type="range" min="-50" max="50" step="1" />
                <output>{{ selectedRingAppearance.offsetY }}%</output>
              </label>
              <label class="setting-row">
                <span>重なり順</span>
                <input v-model.number="selectedRingAppearance.zIndex" type="range" min="0" max="32" step="1" />
                <output>{{ selectedRingAppearance.zIndex }}</output>
              </label>
              <label class="setting-row select-row">
                <span>合成方法</span>
                <select v-model="selectedRingAppearance.blendMode">
                  <option value="normal">通常</option>
                  <option value="screen">スクリーン</option>
                  <option value="plus-lighter">加算</option>
                  <option value="lighten">比較（明）</option>
                </select>
              </label>
              <div class="advanced-toggle-pair">
                <label class="toggle-row"><input v-model="selectedRingAppearance.flipX" type="checkbox" /><span>左右反転</span></label>
                <label class="toggle-row"><input v-model="selectedRingAppearance.flipY" type="checkbox" /><span>上下反転</span></label>
              </div>
              <template v-if="selectedRingAppearance.renderMode !== 'textRing'">
                <label class="setting-row select-row">
                  <span>線端</span>
                  <select v-model="selectedRingAppearance.lineCap">
                    <option value="butt">平坦</option>
                    <option value="round">丸</option>
                    <option value="square">四角</option>
                  </select>
                </label>
                <label class="setting-row select-row">
                  <span>線の角</span>
                  <select v-model="selectedRingAppearance.lineJoin">
                    <option value="miter">尖り</option>
                    <option value="round">丸</option>
                    <option value="bevel">面取り</option>
                  </select>
                </label>
                <label v-if="selectedRingAppearance.lineJoin === 'miter'" class="setting-row">
                  <span>角の鋭さ</span>
                  <input v-model.number="selectedRingAppearance.miterLimit" type="range" min="1" max="20" step="1" />
                  <output>{{ selectedRingAppearance.miterLimit }}</output>
                </label>
                <label v-if="selectedRingAppearance.lineStyle !== 'solid'" class="setting-row">
                  <span>破線の開始位置</span>
                  <input v-model.number="selectedRingAppearance.dashOffset" type="range" min="-40" max="40" step="1" />
                  <output>{{ selectedRingAppearance.dashOffset }}</output>
                </label>
                <label v-if="selectedRingAppearance.lineStyle === 'double'" class="setting-row">
                  <span>二重線の間隔</span>
                  <input v-model.number="selectedRingAppearance.doubleLineGap" type="range" min="0" max="100" step="1" />
                  <output>{{ selectedRingAppearance.doubleLineGap }}%</output>
                </label>
              </template>
            </details>
            <label class="toggle-row">
              <input v-model="selectedRingAppearance.visible" type="checkbox" />
              <span>このリングを表示</span>
            </label>
            <button
              type="button"
              class="remove-ring-button"
              :disabled="draft.rings.length <= 1"
              @click="removeSelectedRing"
            >
              選択中のリングを削除
            </button>
          </template>

          <template v-else-if="activeSection === 'motion'">
            <h3>動き</h3>
            <p>リング {{ selectedRingIndex + 1 }} の停止時と移動時を個別に設定します。</p>
            <label class="toggle-row state-enabled-toggle">
              <input v-model="selectedMotion.enabled" type="checkbox" />
              <span>この状態でアニメーションする</span>
            </label>
            <section class="motion-block">
              <label class="toggle-row motion-toggle">
                <input v-model="selectedMotion.rotateEnabled" type="checkbox" :disabled="!selectedMotion.enabled" />
                <span>回転</span>
              </label>
              <label v-if="selectedMotion.rotateEnabled" class="setting-row">
                <span>回転速度</span>
                <input v-model.number="selectedMotion.rotateDuration" type="range" min="1" max="20" step="1" :disabled="!selectedMotion.enabled" />
                <output>{{ selectedMotion.rotateDuration }}秒</output>
              </label>
              <label v-if="selectedMotion.rotateEnabled" class="setting-row select-row">
                <span>回転方向</span>
                <select v-model="selectedMotion.direction" :disabled="!selectedMotion.enabled">
                  <option value="normal">時計回り</option>
                  <option value="reverse">反時計回り</option>
                </select>
              </label>
              <label v-if="selectedMotion.rotateEnabled && selectedRingAppearance.renderMode === 'textRing'" class="setting-row select-row">
                <span>回転対象</span>
                <select v-model="selectedMotion.rotateTarget" :disabled="!selectedMotion.enabled">
                  <option value="whole">全体（文字位置も回転）</option>
                  <option value="text">文字だけ（位置は固定）</option>
                </select>
              </label>
            </section>
            <section class="motion-block">
              <label class="toggle-row motion-toggle">
                <input v-model="selectedMotion.pulseEnabled" type="checkbox" :disabled="!selectedMotion.enabled" />
                <span>縮小・拡大</span>
              </label>
              <label v-if="selectedMotion.pulseEnabled" class="setting-row">
                <span>伸縮速度</span>
                <input v-model.number="selectedMotion.pulseDuration" type="range" min="1" max="20" step="1" :disabled="!selectedMotion.enabled" />
                <output>{{ selectedMotion.pulseDuration }}秒</output>
              </label>
              <label v-if="selectedMotion.pulseEnabled" class="setting-row">
                <span>伸縮量</span>
                <input v-model.number="selectedMotion.pulseAmount" type="range" min="2" max="45" step="1" :disabled="!selectedMotion.enabled" />
                <output>{{ selectedMotion.pulseAmount }}%</output>
              </label>
            </section>
            <section class="motion-block">
              <label class="toggle-row motion-toggle">
                <input v-model="selectedMotion.glowEnabled" type="checkbox" :disabled="!selectedMotion.enabled" />
                <span>発光を動かす</span>
              </label>
              <label v-if="selectedMotion.glowEnabled" class="setting-row">
                <span>最小発光</span>
                <input v-model.number="selectedMotion.glowMin" type="range" min="0" max="30" step="1" :disabled="!selectedMotion.enabled" />
                <output>{{ selectedMotion.glowMin }}</output>
              </label>
              <label v-if="selectedMotion.glowEnabled" class="setting-row">
                <span>最大発光</span>
                <input v-model.number="selectedMotion.glowMax" type="range" min="0" max="40" step="1" :disabled="!selectedMotion.enabled" />
                <output>{{ selectedMotion.glowMax }}</output>
              </label>
              <label v-if="selectedMotion.glowEnabled" class="setting-row">
                <span>発光速度</span>
                <input v-model.number="selectedMotion.glowDuration" type="range" min="0.5" max="10" step="0.5" :disabled="!selectedMotion.enabled" />
                <output>{{ selectedMotion.glowDuration }}秒</output>
              </label>
            </section>
            <section class="motion-block">
              <label class="toggle-row motion-toggle">
                <input v-model="selectedMotion.segmentSequenceEnabled" type="checkbox" :disabled="!selectedMotion.enabled || selectedRingItemCount <= 1" />
                <span>分割片を順番に点灯</span>
              </label>
              <label v-if="selectedMotion.segmentSequenceEnabled" class="setting-row">
                <span>点灯周期</span>
                <input v-model.number="selectedMotion.segmentSequenceDuration" type="range" min="0.5" max="10" step="0.5" :disabled="!selectedMotion.enabled" />
                <output>{{ selectedMotion.segmentSequenceDuration }}秒</output>
              </label>
              <label class="toggle-row">
                <input v-model="selectedMotion.lineFlowEnabled" type="checkbox" :disabled="!selectedMotion.enabled" />
                <span>線を流す</span>
              </label>
              <label v-if="selectedMotion.lineFlowEnabled" class="setting-row">
                <span>線の速度</span>
                <input v-model.number="selectedMotion.lineFlowDuration" type="range" min="0.5" max="10" step="0.5" :disabled="!selectedMotion.enabled" />
                <output>{{ selectedMotion.lineFlowDuration }}秒</output>
              </label>
              <label class="toggle-row">
                <input v-model="selectedMotion.fillPulseEnabled" type="checkbox" :disabled="!selectedMotion.enabled || !selectedRingAppearance.fillEnabled" />
                <span>塗りを明滅</span>
              </label>
              <label v-if="selectedMotion.fillPulseEnabled" class="setting-row">
                <span>明滅速度</span>
                <input v-model.number="selectedMotion.fillPulseDuration" type="range" min="0.5" max="10" step="0.5" :disabled="!selectedMotion.enabled" />
                <output>{{ selectedMotion.fillPulseDuration }}秒</output>
              </label>
              <label v-if="selectedMotion.fillPulseEnabled" class="setting-row">
                <span>最小濃度</span>
                <input v-model.number="selectedMotion.fillPulseMin" type="range" min="0" max="100" step="5" :disabled="!selectedMotion.enabled" />
                <output>{{ selectedMotion.fillPulseMin }}%</output>
              </label>
            </section>
            <label class="setting-row">
              <span>開始遅延</span>
              <input v-model.number="selectedMotion.delay" type="range" min="0" max="10" step="0.5" :disabled="!selectedMotion.enabled" />
              <output>{{ selectedMotion.delay }}秒</output>
            </label>
            <label class="toggle-row">
              <input v-model="selectedMotion.repeat" type="checkbox" :disabled="!selectedMotion.enabled" />
              <span>縮小・拡大／回転を繰り返す</span>
            </label>
          </template>
        </div>
      </section>

      <footer class="modal-footer">
        <button type="button" class="secondary-button" @click="reset">初期化</button>
        <button type="button" class="save-button" @click="save">決定</button>
      </footer>
      </div>
    </BaseHudModal>
  </Teleport>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { getCurrentScale } from '../useScale.js'
import BaseHudModal from './BaseHudModal.vue'
import TargetMarker from './TargetMarker.vue'
import magicCircleExport from '../../../../memo/target-markers/魔法陣.json'

const makeMotionState = overrides => ({
  enabled: true,
  rotateEnabled: true,
  rotateTarget: 'whole',
  pulseEnabled: false,
  rotateDuration: 8,
  pulseDuration: 3,
  direction: 'normal',
  delay: 0,
  pulseAmount: 18,
  repeat: true,
  glowEnabled: false,
  glowMin: 4,
  glowMax: 14,
  glowDuration: 2,
  segmentSequenceEnabled: false,
  segmentSequenceDuration: 2,
  lineFlowEnabled: false,
  lineFlowDuration: 2,
  fillPulseEnabled: false,
  fillPulseDuration: 2,
  fillPulseMin: 20,
  ...overrides
})
const makeOverallAppearance = overrides => ({
  shape: 'circle',
  size: 100,
  opacity: 88,
  showCenterDot: true,
  ...overrides
})
const TEXT_ITEM_LIMIT = 64
const makeTextItemArray = value => Array.from({ length: TEXT_ITEM_LIMIT }, (_, index) => value?.[index] || '')
const countTextCharacters = value => {
  const text = String(value || '')
  if (typeof Intl !== 'undefined' && Intl.Segmenter) {
    return Math.min(TEXT_ITEM_LIMIT, Array.from(new Intl.Segmenter('ja', { granularity: 'grapheme' }).segment(text)).length)
  }
  return Math.min(TEXT_ITEM_LIMIT, Array.from(text).length)
}
const makeRingAppearance = overrides => ({
  renderMode: 'continuous',
  color: '#8fefff',
  width: 100,
  height: 100,
  splitCount: 1,
  splitGap: 0,
  equalizeSegments: false,
  evenSpacing: false,
  spacingRatio: 20,
  layout: 'straight',
  arcSpread: 90,
  arcRadius: 45,
  arcAngle: 270,
  arcOrientation: 'tangent',
  connectionClosed: true,
  angle: 0,
  offsetX: 0,
  offsetY: 0,
  opacity: 100,
  lineWidth: 2,
  shape: 'circle',
  lineStyle: 'solid',
  glow: 8,
  glowColor: '#8fefff',
  fillEnabled: false,
  fillColor: '#8fefff',
  fillOpacity: 30,
  useSegmentColors: false,
  segmentColors: Array(TEXT_ITEM_LIMIT).fill('#8fefff'),
  zIndex: 0,
  blendMode: 'normal',
  flipX: false,
  flipY: false,
  lineCap: 'butt',
  lineJoin: 'miter',
  miterLimit: 4,
  dashOffset: 0,
  doubleLineGap: 18,
  waveAmplitude: 4,
  waveCount: 12,
  waveRandomness: 55,
  waveSpeed: 1,
  textMode: 'string',
  textLayout: 'circle',
  textReferenceRingId: 'self',
  textReferenceScale: 100,
  textContent: 'TARGET LOCKED',
  textDivisionCount: 1,
  segmentLabels: Array(TEXT_ITEM_LIMIT).fill(''),
  textRadius: 45,
  textSpacing: 100,
  textEvenSpacing: false,
  textArcSpread: 360,
  textSize: 14,
  textWeight: 'bold',
  textDirection: 'clockwise',
  textOrientation: 'outward',
  visible: true,
  ...overrides
})

const DEFAULT_SETTINGS = {
  shape: 'circle',
  color: '#8fefff',
  size: 100,
  opacity: 88,
  ringCount: 2,
  lineWidth: 2,
  rotationSeconds: 8,
  showCenterDot: true,
  behavior: {
    previewBackgroundColor: '#071722',
    previewGradientEnabled: true,
    followCursor: false,
    cursorFollowDuration: 80,
    cursorFollowSpeed: 90
  },
  appearance: {
    idle: makeOverallAppearance(),
    moving: makeOverallAppearance()
  },
  transition: {
    sequence: 'before',
    morphInDuration: 250,
    moveDuration: 350,
    morphOutDuration: 250,
    easing: 'ease-in-out'
  },
  rings: [
    { id: 'ring-1', appearance: { idle: makeRingAppearance(), moving: makeRingAppearance() }, motion: { idle: makeMotionState(), moving: makeMotionState() } },
    { id: 'ring-2', appearance: { idle: makeRingAppearance({ width: 78, height: 78, opacity: 80, lineStyle: 'dashed', glow: 5 }), moving: makeRingAppearance({ width: 78, height: 78, opacity: 80, lineStyle: 'dashed', glow: 5 }) }, motion: { idle: makeMotionState({ rotateEnabled: false, pulseEnabled: true }), moving: makeMotionState({ rotateEnabled: false, pulseEnabled: true }) } }
  ]
}

const props = defineProps({
  settings: {
    type: Object,
    default: () => ({})
  }
})

const emit = defineEmits(['close', 'save'])
const MAX_RINGS = 16
const MODAL_BASE_WIDTH = 720
const MODAL_BASE_HEIGHT = 1280
const modalScale = ref(1)
const previewMoving = ref(false)
const previewPosition = ref({ x: 50, y: 50 })
const editingState = ref('idle')
const highlightedRingId = ref(null)
const pendingOverallShape = ref(null)
const previewCursorFollowActive = ref(false)
const previewFullscreen = ref(false)
let previewMoveTimer = null
let previewMoveToken = 0
let ringHighlightTimer = null
let previewCursorAnimationFrame = null
let previewCursorLastFrame = null
let previewCursorTarget = { x: 50, y: 50 }
const updateModalScale = () => {
  if (typeof window === 'undefined') return
  const viewportScale = Math.min(
    (window.innerWidth - 24) / MODAL_BASE_WIDTH,
    (window.innerHeight - 24) / MODAL_BASE_HEIGHT
  )
  modalScale.value = Math.max(0.1, Math.min(getCurrentScale(), viewportScale))
}
const exitPreviewFullscreen = () => {
  previewFullscreen.value = false
}
const enterPreviewFullscreen = () => {
  previewFullscreen.value = true
}
const onPreviewFullscreenKeydown = event => {
  if (!previewFullscreen.value || !['Escape', 'f', 'F'].includes(event.key)) return
  event.preventDefault()
  exitPreviewFullscreen()
}

onMounted(() => {
  window.addEventListener('resize', updateModalScale)
  window.addEventListener('keydown', onPreviewFullscreenKeydown)
  updateModalScale()
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', updateModalScale)
  window.removeEventListener('keydown', onPreviewFullscreenKeydown)
  if (previewMoveTimer) clearTimeout(previewMoveTimer)
  if (ringHighlightTimer) clearTimeout(ringHighlightTimer)
  if (previewCursorAnimationFrame != null) cancelAnimationFrame(previewCursorAnimationFrame)
})

const makeRing = index => ({
  id: `ring-${Date.now()}-${index}`,
  name: `リング ${index}`,
  appearance: {
    idle: makeRingAppearance({ width: Math.max(20, 100 - index * 14), height: Math.max(20, 100 - index * 14) }),
    moving: makeRingAppearance({ width: Math.max(20, 100 - index * 14), height: Math.max(20, 100 - index * 14) })
  },
  motion: {
    idle: makeMotionState(),
    moving: makeMotionState()
  }
})
const normalizeRingMotion = ring => {
  const legacyState = makeMotionState({
    rotateEnabled: typeof ring.rotateEnabled === 'boolean' ? ring.rotateEnabled : ring.animationType === 'rotate',
    pulseEnabled: typeof ring.pulseEnabled === 'boolean' ? ring.pulseEnabled : ring.animationType === 'pulse',
    rotateDuration: Number(ring.rotateDuration) || Number(ring.duration) || 8,
    pulseDuration: Number(ring.pulseDuration) || Number(ring.duration) || 3,
    direction: ring.direction === 'reverse' ? 'reverse' : 'normal',
    delay: Number(ring.delay) || 0,
    pulseAmount: Number(ring.pulseAmount) || 18,
    repeat: ring.repeat !== false
  })
  const trigger = ring.animationTrigger || 'always'
  return {
    idle: {
      ...legacyState,
      enabled: trigger === 'always',
      ...(ring.motion?.idle || {})
    },
    moving: {
      ...legacyState,
      enabled: trigger === 'always' || trigger === 'moving',
      ...(ring.motion?.moving || {})
    }
  }
}
const normalizeRingAppearance = ring => {
  const legacySize = Number(ring.size) || 100
  const legacy = makeRingAppearance({
    renderMode: ring.renderMode || (ring.layout === 'arc' ? 'circumference' : 'continuous'),
    color: ring.color || '#8fefff',
    width: Number(ring.width) || legacySize,
    height: Number(ring.height) || legacySize,
    splitCount: Number(ring.splitCount) || 1,
    splitGap: Number(ring.splitGap) || 0,
    equalizeSegments: ring.equalizeSegments === true,
    evenSpacing: ring.evenSpacing === true,
    spacingRatio: Number(ring.spacingRatio) || 20,
    layout: ring.layout || 'straight',
    arcSpread: Number(ring.arcSpread) || 90,
    arcRadius: Number(ring.arcRadius) || 45,
    arcAngle: Number(ring.arcAngle) || 270,
    arcOrientation: ring.arcOrientation || 'tangent',
    angle: Number(ring.angle) || 0,
    offsetX: Number(ring.offsetX) || 0,
    offsetY: Number(ring.offsetY) || 0,
    opacity: Number(ring.opacity) || 100,
    lineWidth: Number(ring.lineWidth) || 2,
    shape: ring.shape || 'circle',
    lineStyle: ring.lineStyle || 'solid',
    doubleLineGap: Number.isFinite(Number(ring.doubleLineGap)) ? Number(ring.doubleLineGap) : 18,
    waveAmplitude: Number.isFinite(Number(ring.waveAmplitude)) ? Number(ring.waveAmplitude) : 4,
    waveCount: Number.isFinite(Number(ring.waveCount)) ? Number(ring.waveCount) : 12,
    waveRandomness: Number.isFinite(Number(ring.waveRandomness)) ? Number(ring.waveRandomness) : 55,
    waveSpeed: Number.isFinite(Number(ring.waveSpeed)) ? Number(ring.waveSpeed) : 1,
    glow: Number(ring.glow) || 0,
    glowColor: ring.glowColor || ring.color || '#8fefff',
    fillEnabled: ring.fillEnabled === true,
    fillColor: ring.fillColor || ring.color || '#8fefff',
    fillOpacity: Number(ring.fillOpacity) || 30,
    useSegmentColors: ring.useSegmentColors === true,
    segmentColors: Array.from({ length: TEXT_ITEM_LIMIT }, (_, index) => ring.segmentColors?.[index] || ring.color || '#8fefff'),
    textMode: ring.textMode === 'labels' ? 'labels' : 'string',
    textLayout: ring.textLayout === 'shape' ? 'shape' : 'circle',
    textReferenceRingId: typeof ring.textReferenceRingId === 'string' && ring.textReferenceRingId ? ring.textReferenceRingId : 'self',
    textReferenceScale: Number.isFinite(Number(ring.textReferenceScale)) ? Number(ring.textReferenceScale) : 100,
    textContent: String(ring.textContent || 'TARGET LOCKED').slice(0, TEXT_ITEM_LIMIT),
    textDivisionCount: Math.min(8, Math.max(1, Number(ring.textDivisionCount) || 1)),
    segmentLabels: makeTextItemArray(ring.segmentLabels),
    textRadius: Number(ring.textRadius) || 45,
    textSpacing: Number(ring.textSpacing) || 100,
    textEvenSpacing: ring.textEvenSpacing === true,
    textArcSpread: Number(ring.textArcSpread) || 360,
    textSize: Number(ring.textSize) || 14,
    textWeight: ring.textWeight === 'normal' ? 'normal' : 'bold',
    textDirection: ring.textDirection === 'counterclockwise' ? 'counterclockwise' : 'clockwise',
    textOrientation: ['outward', 'inward', 'centerFacing', 'upright', 'tangent'].includes(ring.textOrientation) ? ring.textOrientation : 'outward',
    visible: ring.visible !== false
  })
  const idleState = ring.appearance?.idle || {}
  const movingState = ring.appearance?.moving || {}
  return {
    idle: {
      ...legacy,
      ...idleState,
      renderMode: idleState.renderMode || (idleState.layout === 'arc' ? 'circumference' : legacy.renderMode),
      segmentColors: Array.from({ length: TEXT_ITEM_LIMIT }, (_, index) => idleState.segmentColors?.[index] || legacy.segmentColors[index]),
      segmentLabels: makeTextItemArray(idleState.segmentLabels || legacy.segmentLabels)
    },
    moving: {
      ...legacy,
      ...movingState,
      renderMode: movingState.renderMode || (movingState.layout === 'arc' ? 'circumference' : legacy.renderMode),
      segmentColors: Array.from({ length: TEXT_ITEM_LIMIT }, (_, index) => movingState.segmentColors?.[index] || legacy.segmentColors[index]),
      segmentLabels: makeTextItemArray(movingState.segmentLabels || legacy.segmentLabels)
    }
  }
}
const cloneRing = ring => ({
  ...ring,
  appearance: {
    idle: {
      ...ring.appearance.idle,
      segmentColors: [...ring.appearance.idle.segmentColors],
      segmentLabels: [...ring.appearance.idle.segmentLabels]
    },
    moving: {
      ...ring.appearance.moving,
      segmentColors: [...ring.appearance.moving.segmentColors],
      segmentLabels: [...ring.appearance.moving.segmentLabels]
    }
  },
  motion: {
    idle: { ...ring.motion.idle },
    moving: { ...ring.motion.moving }
  }
})
const createDraftFromSettings = settings => {
  const source = settings || {}
  const rings = Array.isArray(source.rings) && source.rings.length > 0
    ? source.rings.map((ring, index) => {
      return {
        ...makeRing(index + 1),
        ...ring,
        appearance: normalizeRingAppearance(ring),
        motion: normalizeRingMotion(ring)
      }
    })
    : DEFAULT_SETTINGS.rings.map(cloneRing)
  const legacyOverall = makeOverallAppearance({
    shape: source.shape || DEFAULT_SETTINGS.shape,
    size: Number(source.size) || DEFAULT_SETTINGS.size,
    opacity: Number(source.opacity) || DEFAULT_SETTINGS.opacity,
    showCenterDot: source.showCenterDot !== false
  })
  return {
    ...DEFAULT_SETTINGS,
    ...source,
    appearance: {
      idle: { ...legacyOverall, ...(source.appearance?.idle || {}) },
      moving: { ...legacyOverall, ...(source.appearance?.moving || {}) }
    },
    transition: { ...DEFAULT_SETTINGS.transition, ...(source.transition || {}) },
    behavior: { ...DEFAULT_SETTINGS.behavior, ...(source.behavior || {}) },
    rings
  }
}
const draft = ref(createDraftFromSettings(props.settings))
const MARKER_LIBRARY_STORAGE_KEY = 'battle-custom-target-marker-library-v1'
const MAX_SAVED_MARKERS = 20
const readMarkerLibrary = () => {
  try {
    const parsed = JSON.parse(localStorage.getItem(MARKER_LIBRARY_STORAGE_KEY) || '[]')
    if (!Array.isArray(parsed)) return []
    return parsed
      .filter(marker => marker && typeof marker.id === 'string' && marker.settings && typeof marker.settings === 'object')
      .slice(0, MAX_SAVED_MARKERS)
  } catch {
    return []
  }
}
const savedMarkers = ref(readMarkerLibrary())
const selectedSavedMarkerId = ref(null)
const libraryName = ref('')
const libraryNotice = ref('')
const markerSettingsFileInput = ref(null)
const activeSection = ref('rings')
const appliedPresetKey = ref(null)
const selectedRingId = ref(draft.value.rings[0].id)
const selectedRingIndex = computed(() => Math.max(0, draft.value.rings.findIndex(ring => ring.id === selectedRingId.value)))
const selectedRing = computed(() => draft.value.rings[selectedRingIndex.value])
const selectedOverall = computed(() => draft.value.appearance[editingState.value])
const selectedRingAppearance = computed(() => selectedRing.value.appearance[editingState.value])
const selectedMotion = computed(() => selectedRing.value.motion[editingState.value])
const selectedRingItemCount = computed(() => {
  const appearance = selectedRingAppearance.value
  if (appearance.renderMode === 'textRing') {
    return appearance.textMode === 'labels'
      ? Math.min(TEXT_ITEM_LIMIT, Math.max(1, Number(appearance.splitCount) || 1))
      : countTextCharacters(appearance.textContent)
  }
  return Math.min(8, Math.max(1, Number(appearance.splitCount) || 1))
})
const getRingAppearance = ring => ring.appearance[editingState.value]
const getRingName = (ring, index) => ring.name?.trim() || `リング ${index + 1}`
const selectRing = ringId => {
  selectedRingId.value = ringId
  highlightedRingId.value = null
  if (ringHighlightTimer) clearTimeout(ringHighlightTimer)
  ringHighlightTimer = setTimeout(() => {
    highlightedRingId.value = ringId
    ringHighlightTimer = setTimeout(() => {
      highlightedRingId.value = null
      ringHighlightTimer = null
    }, 850)
  }, 20)
}
const cloneMarkerSettings = settings => JSON.parse(JSON.stringify(settings))
const persistMarkerLibrary = () => {
  try {
    localStorage.setItem(MARKER_LIBRARY_STORAGE_KEY, JSON.stringify(savedMarkers.value))
    return true
  } catch {
    libraryNotice.value = '保存できませんでした。ブラウザの保存領域を確認してください。'
    return false
  }
}
const markerNameForSave = () => libraryName.value.trim().slice(0, 32) || `マーカー ${savedMarkers.value.length + 1}`
const markerSettingsJson = () => JSON.stringify({
  version: 1,
  name: markerNameForSave(),
  exportedAt: new Date().toISOString(),
  settings: cloneMarkerSettings(draft.value)
}, null, 2)
const exportMarkerSettings = () => {
  const json = markerSettingsJson()
  const fileName = markerNameForSave().replace(/[\\/:*?"<>|]/g, '_')
  const blob = new Blob([json], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = `${fileName || 'target-marker'}.json`
  document.body.append(link)
  link.click()
  link.remove()
  URL.revokeObjectURL(url)
  libraryNotice.value = '作成中の設定JSONを保存しました。'
}
const openMarkerSettingsFile = () => markerSettingsFileInput.value?.click()
const importMarkerSettings = async event => {
  const input = event.target
  const file = input.files?.[0]
  input.value = ''
  if (!file) return

  try {
    const parsed = JSON.parse(await file.text())
    const settings = parsed?.settings && typeof parsed.settings === 'object' ? parsed.settings : parsed
    if (!settings || typeof settings !== 'object' || Array.isArray(settings)) throw new Error('invalid settings')

    draft.value = createDraftFromSettings(cloneMarkerSettings(settings))
    selectedSavedMarkerId.value = null
    libraryName.value = typeof parsed?.name === 'string' ? parsed.name.slice(0, 32) : file.name.replace(/\.json$/i, '').slice(0, 32)
    selectedRingId.value = draft.value.rings[0].id
    appliedPresetKey.value = null
    pendingOverallShape.value = null
    previewPosition.value = { x: 50, y: 50 }
    selectEditingState('idle')
    selectRing(selectedRingId.value)
    libraryNotice.value = `「${file.name}」を読み込みました。決定するまで戦闘画面には反映されません。`
  } catch {
    libraryNotice.value = '設定JSONを読み込めませんでした。JSON保存で出力したファイルを選択してください。'
  }
}
const selectSavedMarker = marker => {
  selectedSavedMarkerId.value = marker.id
  libraryName.value = marker.name
  libraryNotice.value = `「${marker.name}」を選択しました。`
}
const saveNewMarker = () => {
  if (savedMarkers.value.length >= MAX_SAVED_MARKERS) {
    libraryNotice.value = `保存できるマーカーは${MAX_SAVED_MARKERS}件までです。`
    return
  }
  const marker = {
    id: `marker-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    name: markerNameForSave(),
    updatedAt: Date.now(),
    settings: cloneMarkerSettings(draft.value)
  }
  savedMarkers.value.unshift(marker)
  selectedSavedMarkerId.value = marker.id
  libraryName.value = marker.name
  if (persistMarkerLibrary()) libraryNotice.value = `「${marker.name}」を保存しました。`
}
const overwriteSavedMarker = () => {
  const index = savedMarkers.value.findIndex(marker => marker.id === selectedSavedMarkerId.value)
  if (index < 0) return
  const current = savedMarkers.value[index]
  const updated = {
    ...current,
    name: markerNameForSave(),
    updatedAt: Date.now(),
    settings: cloneMarkerSettings(draft.value)
  }
  savedMarkers.value.splice(index, 1)
  savedMarkers.value.unshift(updated)
  libraryName.value = updated.name
  if (persistMarkerLibrary()) libraryNotice.value = `「${updated.name}」を上書きしました。`
}
const loadSavedMarker = marker => {
  draft.value = createDraftFromSettings(cloneMarkerSettings(marker.settings))
  selectedSavedMarkerId.value = marker.id
  libraryName.value = marker.name
  selectedRingId.value = draft.value.rings[0].id
  appliedPresetKey.value = null
  pendingOverallShape.value = null
  previewPosition.value = { x: 50, y: 50 }
  selectEditingState('idle')
  selectRing(selectedRingId.value)
  libraryNotice.value = `「${marker.name}」を読み込みました。決定するまで戦闘画面には反映されません。`
}
const deleteSavedMarker = markerId => {
  const marker = savedMarkers.value.find(item => item.id === markerId)
  if (!marker) return
  savedMarkers.value = savedMarkers.value.filter(item => item.id !== markerId)
  if (selectedSavedMarkerId.value === markerId) {
    selectedSavedMarkerId.value = null
    libraryName.value = ''
  }
  if (persistMarkerLibrary()) libraryNotice.value = `「${marker.name}」を削除しました。`
}
const setOverallShape = shape => {
  selectedOverall.value.shape = shape
  draft.value.rings.forEach(ring => {
    const appearance = ring.appearance[editingState.value]
    appearance.shape = shape
    if (shape === 'point') {
      appearance.fillEnabled = true
      appearance.fillOpacity = 100
    }
  })
}
const onRingShapeChange = () => {
  if (selectedRingAppearance.value.shape !== 'point') return
  selectedRingAppearance.value.fillEnabled = true
  selectedRingAppearance.value.fillOpacity = 100
}
const requestOverallShapeChange = shape => {
  if (shape === selectedOverall.value.shape) return
  pendingOverallShape.value = shape
}
const shapeLabel = shapeKey => shapes.find(shape => shape.key === shapeKey)?.label || shapeKey
const confirmOverallShapeChange = () => {
  if (!pendingOverallShape.value) return
  setOverallShape(pendingOverallShape.value)
  pendingOverallShape.value = null
}
const setRenderMode = mode => {
  const appearance = selectedRingAppearance.value
  appearance.renderMode = mode
  if (mode === 'circumference') {
    appearance.layout = 'arc'
    appearance.evenSpacing = true
    appearance.splitCount = Math.max(3, Number(appearance.splitCount) || 1)
  } else if (mode === 'segmentedArc') {
    appearance.layout = 'straight'
    appearance.splitCount = Math.max(2, Number(appearance.splitCount) || 1)
    appearance.splitGap = Math.max(2, Number(appearance.splitGap) || 0)
  } else if (mode === 'connection') {
    appearance.layout = 'straight'
    appearance.splitCount = Math.max(3, Number(appearance.splitCount) || 1)
    appearance.connectionClosed = true
  } else if (mode === 'textRing') {
    appearance.layout = 'straight'
    appearance.textMode = appearance.textMode === 'labels' ? 'labels' : 'string'
    appearance.textLayout = appearance.textLayout === 'shape' ? 'shape' : 'circle'
    appearance.textContent ||= 'TARGET LOCKED'
    appearance.textRadius ||= 45
    appearance.textSpacing ||= 100
    appearance.textArcSpread ||= 360
    appearance.textSize ||= 14
  } else {
    appearance.layout = 'straight'
  }
  if (mode === 'center') {
    appearance.offsetX = 0
    appearance.offsetY = 0
  }
}
const previewTargetStyle = computed(() => {
  const transition = draft.value.transition
  const easing = ['linear', 'ease-in', 'ease-out', 'ease-in-out'].includes(transition.easing)
    ? transition.easing
    : 'ease-in-out'
  const duration = Math.max(100, Number(transition.moveDuration) || 350)
  return {
    left: `${previewPosition.value.x}%`,
    top: `${previewPosition.value.y}%`,
    transition: previewCursorFollowActive.value
      ? 'none'
      : `left ${duration}ms ${easing}, top ${duration}ms ${easing}`
  }
})
const previewBackgroundStyle = computed(() => ({
  '--preview-background': draft.value.behavior.previewBackgroundColor || DEFAULT_SETTINGS.behavior.previewBackgroundColor,
  backgroundImage: draft.value.behavior.previewGradientEnabled === false ? 'none' : undefined
}))

const sections = [
  { key: 'rings', label: 'リング' },
  { key: 'motion', label: '動き' },
  { key: 'overall', label: '全体設定' },
  { key: 'display', label: '表示設定' },
  { key: 'existing', label: '既存' },
  { key: 'library', label: '保存' }
]

const shapes = [
  { key: 'circle', label: '円' },
  { key: 'point', label: '点' },
  { key: 'square', label: '四角' },
  { key: 'triangle', label: '三角' },
  { key: 'diamond', label: '菱形' },
  { key: 'line', label: '直線' },
  { key: 'cross', label: '十字' },
  { key: 'corner', label: 'L字枠' },
  { key: 'cornerFrame', label: '四隅枠' },
  { key: 'arc', label: '円弧' },
  { key: 'tick', label: '目盛り' },
  { key: 'star', label: '星' },
  { key: 'hexagram', label: '六芒星' },
  { key: 'octagram', label: '八芒星' },
  { key: 'sparkle', label: '十字星' },
  { key: 'arrow', label: '矢印 ⇒' },
  { key: 'arrowhead', label: '矢じり ➤' },
  { key: 'sector', label: '扇形' },
  { key: 'wave', label: 'G5オービット' },
  { key: 'magitechWave', label: 'G4ウェーブ' }
]

const renderModes = [
  { key: 'continuous', label: '連続リング', description: '中心を基準に、切れ目のない形を1つ描画します。' },
  { key: 'segmentedArc', label: '分割円弧', description: '1本の円周を指定数の円弧へ均等に分割します。' },
  { key: 'circumference', label: '円周配置', description: '同じ部品を中心点の周囲へ均等に配置します。' },
  { key: 'free', label: '自由配置', description: '中心からXY位置をずらして部品を配置します。' },
  { key: 'center', label: '中央部品', description: '中心位置へ照準点や十字などを固定します。' },
  { key: 'connection', label: '接続線', description: '中心周囲の頂点を線で結びます。' },
  { key: 'textRing', label: '円周文字', description: '文字列または個別ラベルを中心の周囲へ最大64個まで配置します。' }
]

const staticMotion = overrides => makeMotionState({
  enabled: false,
  rotateEnabled: false,
  pulseEnabled: false,
  ...overrides
})
const presetRing = (appearance, motion = {}, movingAppearance = {}, movingMotion = {}) => ({
  appearance,
  motion,
  movingAppearance,
  movingMotion
})
const nodeColors = ['#63f58c', '#ffe45c', '#5faeff', '#ffffff', '#b8ff62', '#63f58c', '#ffe45c', '#5faeff']
const g45NodeColors = ['#63f58c', '#ffe45c', '#5faeff', '#ffffff', '#b8ff62']
const existingMarkerPresets = [
  {
    key: 1,
    label: 'G1',
    color: '#dcdcdc',
    rings: [
      presetRing({ shape: 'circle', width: 100, height: 100, lineWidth: 3 }, { enabled: true, pulseEnabled: true, pulseDuration: 1.6, pulseAmount: 8 }),
      presetRing({ shape: 'circle', width: 64, height: 64, lineStyle: 'dashed' }, { enabled: true, rotateEnabled: true, rotateDuration: 6 }),
      presetRing({ shape: 'cross', width: 62, height: 62, lineWidth: 2 }),
      presetRing({ shape: 'circle', width: 14, height: 14, lineWidth: 2 })
    ]
  },
  {
    key: 1.5,
    label: 'G1.5',
    color: '#e58a36',
    rings: [
      presetRing({ renderMode: 'segmentedArc', shape: 'circle', width: 92, height: 92, splitCount: 8, splitGap: 7, lineWidth: 1, opacity: 62 }),
      presetRing({ shape: 'circle', width: 64, height: 64, lineStyle: 'dashed', lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 6 }),
      presetRing({ renderMode: 'center', shape: 'cornerFrame', width: 100, height: 100, lineWidth: 3 }),
      presetRing({ renderMode: 'center', shape: 'cross', width: 58, height: 58, lineWidth: 2 }),
      presetRing({ shape: 'circle', width: 28, height: 28, lineWidth: 1, opacity: 82 })
    ]
  },
  {
    key: 2,
    label: 'G2',
    color: '#5cff8a',
    rings: [
      presetRing({ shape: 'circle', width: 96, height: 96, lineWidth: 2 }),
      presetRing({ shape: 'tick', width: 72, height: 16, splitCount: 8, equalizeSegments: true, layout: 'arc', evenSpacing: true, arcRadius: 51, arcOrientation: 'radial', lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 9 }),
      presetRing({ renderMode: 'center', shape: 'cornerFrame', width: 100, height: 100, lineWidth: 2 }),
      presetRing({ shape: 'cross', width: 70, height: 70, lineWidth: 2 })
    ]
  },
  {
    key: 2.5,
    label: 'G2.5',
    color: '#21dce5',
    rings: [
      presetRing({ shape: 'tick', width: 92, height: 12, splitCount: 8, equalizeSegments: true, layout: 'arc', evenSpacing: true, arcRadius: 54, arcOrientation: 'radial', opacity: 80 }, { enabled: true, rotateEnabled: true, rotateDuration: 14 }),
      presetRing({ shape: 'arc', width: 82, height: 36, splitCount: 3, equalizeSegments: true, layout: 'arc', evenSpacing: true, arcRadius: 30, arcOrientation: 'tangent', lineStyle: 'dashed', lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 7, direction: 'reverse' }),
      presetRing({ shape: 'arrowhead', width: 48, height: 18, splitCount: 4, equalizeSegments: true, layout: 'arc', evenSpacing: true, arcRadius: 39, arcOrientation: 'radial', angle: 180, fillEnabled: true, fillOpacity: 55 }, {}, { arcRadius: 52 }, {}),
      presetRing({ shape: 'circle', width: 9, height: 9, fillEnabled: true, fillOpacity: 100 })
    ]
  },
  {
    key: 3,
    label: 'G3',
    color: '#b7ceff',
    rings: [
      presetRing({ shape: 'circle', width: 100, height: 100, lineWidth: 2 }),
      presetRing({ shape: 'circle', width: 66, height: 66, lineWidth: 3, lineStyle: 'dashed', opacity: 72 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }),
      presetRing({ shape: 'arrowhead', width: 50, height: 20, splitCount: 4, equalizeSegments: true, layout: 'arc', evenSpacing: true, arcRadius: 38, arcOrientation: 'radial', angle: 180, fillEnabled: true, fillOpacity: 76 }),
      presetRing({ shape: 'cross', width: 28, height: 28, lineWidth: 2 })
    ]
  },
  {
    key: 3.5,
    label: 'G3.5',
    color: '#a9d8ff',
    rings: [
      presetRing({ shape: 'circle', width: 106, height: 106, lineWidth: 3 }, { enabled: true, rotateEnabled: true, rotateDuration: 12 }),
      presetRing({ shape: 'tick', width: 92, height: 13, splitCount: 8, equalizeSegments: true, layout: 'arc', evenSpacing: true, arcRadius: 51, arcOrientation: 'radial', opacity: 75 }, { enabled: true, rotateEnabled: true, rotateDuration: 9, direction: 'reverse' }),
      presetRing({ shape: 'circle', width: 72, height: 72, lineStyle: 'dashed', lineWidth: 3 }, { enabled: true, rotateEnabled: true, rotateDuration: 6 }),
      presetRing({ shape: 'arrowhead', width: 46, height: 17, splitCount: 4, equalizeSegments: true, layout: 'arc', evenSpacing: true, arcRadius: 40, arcOrientation: 'radial', angle: 180, fillEnabled: true, fillOpacity: 70 }),
      presetRing({ shape: 'sparkle', width: 15, height: 15, fillEnabled: true, fillOpacity: 75 })
    ]
  },
  {
    key: 4,
    label: 'G4',
    color: '#39c6d8',
    rings: [
      presetRing({ shape: 'magitechWave', width: 96, height: 96, lineWidth: 2, opacity: 90 }, { enabled: true, rotateEnabled: true, rotateDuration: 10 }),
      presetRing({ shape: 'circle', width: 72, height: 72, lineWidth: 1, opacity: 78 }),
      presetRing({ renderMode: 'connection', width: 100, height: 100, splitCount: 3, arcRadius: 47, lineWidth: 2, opacity: 72 }, { enabled: true, rotateEnabled: true, rotateDuration: 9, glowEnabled: true, glowMin: 3, glowMax: 9 }),
      presetRing({ shape: 'circle', width: 56, height: 18, splitCount: 3, equalizeSegments: true, layout: 'arc', evenSpacing: true, arcRadius: 47, arcOrientation: 'fixed', fillEnabled: true, fillOpacity: 75, useSegmentColors: true, segmentColors: nodeColors }, { enabled: true, rotateEnabled: true, rotateDuration: 9, glowEnabled: true, glowMin: 5, glowMax: 12 }),
      presetRing({ shape: 'sparkle', width: 12, height: 12, fillEnabled: true, fillOpacity: 70 })
    ]
  },
  {
    key: 4.5,
    label: 'G4.5',
    color: '#7064dc',
    behavior: { followCursor: true, cursorFollowDuration: 30, cursorFollowSpeed: 90 },
    rings: [
      presetRing({ shape: 'magitechWave', width: 124, height: 114, lineWidth: 2, waveAmplitude: 1.5, waveCount: 24, waveRandomness: 81 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }, { waveAmplitude: 4, waveCount: 12, waveRandomness: 55, waveSpeed: 1 }, { rotateDuration: 1 }),
      presetRing({ shape: 'circle', width: 85, height: 85, lineWidth: 1, opacity: 78 }, staticMotion(), {}, { enabled: true, rotateEnabled: true, rotateDuration: 1 }),
      presetRing({ renderMode: 'connection', width: 117, height: 117, splitCount: 5, arcRadius: 49, lineWidth: 2, opacity: 76 }, { enabled: true, rotateEnabled: true, rotateDuration: 8, glowEnabled: true, glowMin: 4, glowMax: 11 }, { width: 100, height: 100 }, { rotateDuration: 1 }),
      presetRing({ shape: 'circle', width: 64, height: 18, splitCount: 5, equalizeSegments: true, layout: 'arc', evenSpacing: true, arcRadius: 49, arcOrientation: 'fixed', fillEnabled: true, fillOpacity: 80, useSegmentColors: true, segmentColors: g45NodeColors, lineStyle: 'double', doubleLineGap: 40, glow: 14, glowColor: '#c28cf8', blendMode: 'screen' }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }, { lineStyle: 'solid', doubleLineGap: 18, glow: 8, glowColor: '#7064dc', blendMode: 'normal' }, { rotateDuration: 1 }),
      presetRing({ shape: 'arrowhead', width: 62, height: 15, splitCount: 4, equalizeSegments: true, layout: 'arc', evenSpacing: true, arcRadius: 70, arcOrientation: 'radial', fillEnabled: true, fillOpacity: 65 }, { enabled: true, rotateEnabled: false, rotateDuration: 12, direction: 'reverse' }, { angle: 178 }),
      presetRing({ shape: 'circle', width: 24, height: 12, lineWidth: 2, opacity: 55 }),
      presetRing({ shape: 'diamond', width: 8, height: 14, color: '#6a6572', fillEnabled: true, fillOpacity: 65 }),
      presetRing({ shape: 'circle', width: 128, height: 128, color: '#722aac', glowColor: '#ae00ff' }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }, {}, { rotateDuration: 1 }),
      presetRing({ renderMode: 'circumference', shape: 'point', width: 10, height: 10, splitCount: 5, equalizeSegments: true, layout: 'arc', evenSpacing: true, arcSpread: 288, arcRadius: 49, lineWidth: 1, color: '#8fefff', glowColor: '#8fefff', fillColor: '#8fefff', fillEnabled: true, fillOpacity: 100 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }, { renderMode: 'continuous', shape: 'circle', width: 20, height: 20, splitCount: 1, equalizeSegments: false, evenSpacing: false, arcSpread: 90, arcRadius: 45, lineWidth: 2, fillEnabled: false, fillOpacity: 30 })
    ]
  },
  {
    key: 5,
    label: 'G5',
    color: '#fff0a6',
    size: 85,
    rings: [
      presetRing({ shape: 'wave', width: 120, height: 120, lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 13 }),
      presetRing({ shape: 'wave', width: 96, height: 96, lineWidth: 2, opacity: 82 }, { enabled: true, rotateEnabled: true, rotateDuration: 9, direction: 'reverse' }),
      presetRing({ shape: 'circle', width: 72, height: 72, lineWidth: 1, opacity: 40 }),
      presetRing({ shape: 'circle', width: 46, height: 46, lineWidth: 3, opacity: 36 }),
      presetRing({ shape: 'circle', width: 126, height: 126, lineStyle: 'dotted', opacity: 62 }, { enabled: true, rotateEnabled: true, rotateDuration: 16 })
    ]
  },
  {
    key: 5.5,
    label: 'G5.5',
    color: '#9be7ff',
    rings: [
      presetRing({ renderMode: 'segmentedArc', shape: 'circle', width: 92, height: 92, splitCount: 4, splitGap: 8, lineWidth: 4, opacity: 75 }, { enabled: true, rotateEnabled: true, rotateDuration: 12 }),
      presetRing({ shape: 'cross', width: 72, height: 72, angle: 45, lineStyle: 'dotted', lineWidth: 3, opacity: 42 }),
      presetRing({ renderMode: 'center', shape: 'cornerFrame', width: 100, height: 100, lineWidth: 3, opacity: 78 }, { enabled: true, pulseEnabled: true, pulseDuration: 2.6, pulseAmount: 8 }),
      presetRing({ shape: 'circle', width: 74, height: 74, lineWidth: 1, opacity: 88 })
    ]
  },
  {
    key: 'magic-circle-json',
    label: '魔法陣',
    color: magicCircleExport.settings?.color || '#8fefff',
    settings: magicCircleExport.settings
  },
  {
    key: 'magic-star-ring',
    label: '魔法陣・星環',
    color: '#8fefff',
    rings: [
      presetRing({ shape: 'circle', width: 140, height: 140, lineStyle: 'double', lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }, { width: 58, height: 58, lineStyle: 'solid' }),
      presetRing({ renderMode: 'textRing', shape: 'circle', textLayout: 'shape', textContent: '1234512345123451234512345123451234512345', textReferenceScale: 90, textEvenSpacing: true, arcAngle: 359, textSize: 13, textOrientation: 'centerFacing', glow: 0 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }, { renderMode: 'continuous', shape: 'circle', width: 58, height: 58 }),
      presetRing({ shape: 'square', width: 100, height: 100, lineStyle: 'double', doubleLineGap: 45, lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }, { shape: 'circle', width: 30, height: 30, lineStyle: 'solid' }),
      presetRing({ shape: 'square', width: 100, height: 100, angle: 45, lineStyle: 'double', doubleLineGap: 45, lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }, { shape: 'circle', width: 30, height: 30, lineStyle: 'solid' }),
      presetRing({ renderMode: 'circumference', shape: 'diamond', width: 5, height: 58, splitCount: 8, evenSpacing: true, arcRadius: 30, arcOrientation: 'radial', fillEnabled: true, fillOpacity: 100, lineWidth: 1 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }),
      presetRing({ renderMode: 'circumference', shape: 'diamond', width: 3, height: 35, splitCount: 8, evenSpacing: true, arcRadius: 25, arcAngle: 23, arcOrientation: 'radial', fillEnabled: true, fillOpacity: 100, lineWidth: 1 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }),
      presetRing({ shape: 'circle', width: 96, height: 96, lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }, { width: 20, height: 20 }),
      presetRing({ renderMode: 'circumference', shape: 'circle', width: 14, height: 9, splitCount: 8, evenSpacing: true, arcRadius: 49, arcAngle: 67, arcOrientation: 'tangent', lineStyle: 'double', doubleLineGap: 25, lineWidth: 2, fillEnabled: true, fillOpacity: 100 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }),
      presetRing({ renderMode: 'circumference', shape: 'line', width: 33, height: 140, splitCount: 8, evenSpacing: true, arcRadius: 50, arcAngle: 45, arcOrientation: 'radial', angle: 90, lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }),
      presetRing({ renderMode: 'circumference', shape: 'diamond', width: 4, height: 58, splitCount: 8, evenSpacing: true, arcRadius: 49, arcAngle: 45, arcOrientation: 'radial', fillEnabled: true, fillOpacity: 100, lineWidth: 1 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }),
      presetRing({ shape: 'circle', width: 80, height: 80, lineStyle: 'double', lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }, { width: 20, height: 20 }),
      presetRing({ shape: 'point', width: 42, height: 42, lineWidth: 5, fillEnabled: true, fillOpacity: 14 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }, { shape: 'circle', width: 20, height: 20 }),
      presetRing({ shape: 'sparkle', width: 53, height: 53, lineStyle: 'double', doubleLineGap: 50, lineWidth: 2, fillEnabled: true, fillOpacity: 9 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }, { shape: 'circle', width: 20, height: 20 })
    ]
  },
  {
    key: 'magic-hexagram',
    label: '魔法陣・六芒',
    color: '#ffcf78',
    rings: [
      presetRing({ shape: 'circle', width: 126, height: 126, lineStyle: 'double', doubleLineGap: 28, lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 16 }),
      presetRing({ shape: 'circle', width: 104, height: 104, lineStyle: 'dashed', lineWidth: 2, opacity: 78 }, { enabled: true, rotateEnabled: true, rotateDuration: 10, direction: 'reverse' }),
      presetRing({ shape: 'hexagram', width: 88, height: 88, lineWidth: 3 }, { enabled: true, rotateEnabled: true, rotateDuration: 14 }),
      presetRing({ shape: 'hexagram', width: 57, height: 57, angle: 30, lineStyle: 'dashed', lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 9, direction: 'reverse' }),
      presetRing({ renderMode: 'circumference', shape: 'diamond', width: 9, height: 15, splitCount: 6, evenSpacing: true, arcRadius: 47, arcOrientation: 'radial', fillEnabled: true, fillOpacity: 80 }, { enabled: true, rotateEnabled: true, rotateDuration: 12 }),
      presetRing({ shape: 'circle', width: 38, height: 38, lineStyle: 'double', doubleLineGap: 36, lineWidth: 2 }),
      presetRing({ shape: 'sparkle', width: 18, height: 18, fillEnabled: true, fillOpacity: 85 }, { enabled: true, glowEnabled: true, glowMin: 4, glowMax: 16, glowDuration: 2 })
    ]
  },
  {
    key: 'magic-octagram',
    label: '魔法陣・八方',
    color: '#d59cff',
    rings: [
      presetRing({ renderMode: 'segmentedArc', shape: 'circle', width: 132, height: 132, splitCount: 8, splitGap: 4, lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 18 }),
      presetRing({ shape: 'circle', width: 112, height: 112, lineStyle: 'double', doubleLineGap: 34, lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 12, direction: 'reverse' }),
      presetRing({ shape: 'octagram', width: 88, height: 88, lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 14 }),
      presetRing({ shape: 'octagram', width: 58, height: 58, angle: 22, lineStyle: 'dashed', lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 8, direction: 'reverse' }),
      presetRing({ renderMode: 'circumference', shape: 'tick', width: 11, height: 28, splitCount: 8, evenSpacing: true, arcRadius: 52, arcOrientation: 'radial', lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 11 }),
      presetRing({ renderMode: 'circumference', shape: 'point', width: 8, height: 8, splitCount: 8, evenSpacing: true, arcRadius: 38, fillEnabled: true, fillOpacity: 100 }, { enabled: true, rotateEnabled: true, rotateDuration: 8, direction: 'reverse' }),
      presetRing({ shape: 'cross', width: 38, height: 38, lineWidth: 2 }),
      presetRing({ shape: 'circle', width: 10, height: 10, fillEnabled: true, fillOpacity: 100 })
    ]
  },
  {
    key: 'angel',
    label: '天使',
    color: '#dff7ff',
    rings: [
      presetRing({ shape: 'circle', width: 104, height: 84, lineWidth: 3 }, { enabled: true, rotateEnabled: true, rotateDuration: 10 }),
      presetRing({ shape: 'circle', width: 90, height: 72, lineStyle: 'dashed', opacity: 72 }, { enabled: true, rotateEnabled: true, rotateDuration: 7, direction: 'reverse' }),
      presetRing({ shape: 'arc', width: 86, height: 34, splitCount: 3, equalizeSegments: true, layout: 'arc', evenSpacing: true, arcRadius: 34, arcOrientation: 'tangent', lineWidth: 3, opacity: 88 }),
      presetRing({ shape: 'sparkle', width: 25, height: 25, fillEnabled: true, fillColor: '#fff6d6', fillOpacity: 75 }),
      presetRing({ shape: 'circle', width: 7, height: 7, fillEnabled: true, fillOpacity: 100 })
    ]
  },
  {
    key: 'seraph',
    label: '熾天使',
    color: '#fff2c0',
    rings: [
      presetRing({ shape: 'circle', width: 112, height: 88, lineWidth: 3 }, { enabled: true, rotateEnabled: true, rotateDuration: 8 }),
      presetRing({ shape: 'circle', width: 98, height: 76, lineStyle: 'dashed', opacity: 78 }, { enabled: true, rotateEnabled: true, rotateDuration: 6, direction: 'reverse' }),
      presetRing({ shape: 'arc', width: 92, height: 38, splitCount: 6, equalizeSegments: true, layout: 'arc', evenSpacing: true, arcRadius: 36, arcOrientation: 'tangent', lineWidth: 3 }),
      presetRing({ shape: 'tick', width: 82, height: 14, splitCount: 8, equalizeSegments: true, layout: 'arc', evenSpacing: true, arcRadius: 53, arcOrientation: 'radial', lineWidth: 2 }),
      presetRing({ shape: 'sparkle', width: 30, height: 30, fillEnabled: true, fillOpacity: 82 }, { enabled: true, glowEnabled: true, glowMin: 6, glowMax: 18, glowDuration: 2.4 }),
      presetRing({ shape: 'circle', width: 8, height: 8, fillEnabled: true, fillOpacity: 100 })
    ]
  },
  {
    key: 'tactical',
    label: '戦術',
    color: '#93ffb9',
    rings: [
      presetRing({ renderMode: 'center', shape: 'cornerFrame', width: 100, height: 100, lineWidth: 3 }),
      presetRing({ shape: 'tick', width: 62, height: 13, splitCount: 8, equalizeSegments: true, layout: 'arc', arcSpread: 145, arcAngle: 270, arcRadius: 36, arcOrientation: 'radial' }),
      presetRing({ shape: 'cross', width: 42, height: 42, lineWidth: 2 })
    ]
  },
  {
    key: 'diamond',
    label: '菱形',
    color: '#ff9fe8',
    rings: [
      presetRing({ shape: 'diamond', width: 76, height: 76, lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 11 }),
      presetRing({ shape: 'diamond', width: 40, height: 40, lineStyle: 'dashed', lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 6, direction: 'reverse' }),
      presetRing({ shape: 'diamond', width: 52, height: 13, splitCount: 4, equalizeSegments: true, layout: 'arc', evenSpacing: true, arcRadius: 51, arcOrientation: 'fixed', fillEnabled: true, fillOpacity: 90 }),
      presetRing({ shape: 'diamond', width: 10, height: 10, fillEnabled: true, fillColor: '#fff5fc', fillOpacity: 100 })
    ]
  },
  {
    key: 'radar',
    label: 'レーダー',
    color: '#6ee8ff',
    rings: [
      presetRing({ shape: 'circle', width: 86, height: 86, lineStyle: 'dashed' }),
      presetRing({ shape: 'circle', width: 47, height: 47, opacity: 72 }),
      presetRing({ shape: 'cross', width: 86, height: 86, lineWidth: 1, opacity: 42 }),
      presetRing({ renderMode: 'free', shape: 'line', width: 39, height: 10, offsetX: 19, lineWidth: 2 }, { enabled: true, rotateEnabled: true, rotateDuration: 3.8 }),
      presetRing({ shape: 'circle', width: 7, height: 7, fillEnabled: true, fillOpacity: 100 })
    ]
  },
  {
    key: 'rift',
    label: '裂け目',
    color: '#b592ff',
    rings: [
      presetRing({ shape: 'diamond', width: 84, height: 84, lineWidth: 3 }, { enabled: true, pulseEnabled: true, pulseDuration: 2.8, pulseAmount: 11 }),
      presetRing({ shape: 'diamond', width: 49, height: 49, angle: 22, lineStyle: 'dashed' }, { enabled: true, rotateEnabled: true, rotateDuration: 8, direction: 'reverse' }),
      presetRing({ shape: 'triangle', width: 54, height: 18, splitCount: 4, equalizeSegments: true, layout: 'arc', evenSpacing: true, arcRadius: 58, arcOrientation: 'radial', fillEnabled: true, fillOpacity: 82 }),
      presetRing({ shape: 'diamond', width: 14, height: 14, fillEnabled: true, fillOpacity: 80 })
    ]
  }
]

const addRing = () => {
  if (draft.value.rings.length >= MAX_RINGS) return
  const ring = makeRing(draft.value.rings.length + 1)
  draft.value.rings.push(ring)
  selectRing(ring.id)
}
const duplicateSelectedRing = () => {
  if (draft.value.rings.length >= MAX_RINGS) return
  const index = selectedRingIndex.value
  const ring = {
    ...cloneRing(selectedRing.value),
    id: `ring-${Date.now()}-copy`
  }
  draft.value.rings.splice(index + 1, 0, ring)
  selectRing(ring.id)
}
const moveSelectedRing = direction => {
  const from = selectedRingIndex.value
  const to = from + direction
  if (to < 0 || to >= draft.value.rings.length) return
  const [ring] = draft.value.rings.splice(from, 1)
  draft.value.rings.splice(to, 0, ring)
}
const removeSelectedRing = () => {
  if (draft.value.rings.length <= 1) return
  const index = selectedRingIndex.value
  draft.value.rings.splice(index, 1)
  selectedRingId.value = draft.value.rings[Math.max(0, index - 1)].id
}

const materializePresetRing = (preset, index, color) => {
  const idleAppearance = makeRingAppearance({
    color,
    glowColor: color,
    fillColor: color,
    renderMode: preset.appearance.renderMode || (preset.appearance.layout === 'arc' ? 'circumference' : 'continuous'),
    ...preset.appearance
  })
  idleAppearance.segmentColors = [...(preset.appearance.segmentColors || idleAppearance.segmentColors)]
  idleAppearance.segmentLabels = [...(preset.appearance.segmentLabels || idleAppearance.segmentLabels)]
  const movingAppearance = makeRingAppearance({
    ...idleAppearance,
    ...preset.movingAppearance
  })
  movingAppearance.segmentColors = [...(preset.movingAppearance.segmentColors || idleAppearance.segmentColors)]
  movingAppearance.segmentLabels = [...(preset.movingAppearance.segmentLabels || idleAppearance.segmentLabels)]
  return {
    id: `preset-${Date.now()}-${index}`,
    appearance: {
      idle: idleAppearance,
      moving: movingAppearance
    },
    motion: {
      idle: staticMotion(preset.motion),
      moving: staticMotion({ ...preset.motion, ...preset.movingMotion })
    }
  }
}
const applyExistingMarkerPreset = preset => {
  if (preset.settings) {
    draft.value = createDraftFromSettings(cloneMarkerSettings(preset.settings))
    selectedRingId.value = draft.value.rings[0].id
    appliedPresetKey.value = preset.key
    pendingOverallShape.value = null
    previewPosition.value = { x: 50, y: 50 }
    selectEditingState('idle')
    selectRing(selectedRingId.value)
    return
  }
  const overall = makeOverallAppearance({
    shape: 'circle',
    size: preset.size || 100,
    opacity: 100,
    showCenterDot: false
  })
  const rings = preset.rings.map((ring, index) => materializePresetRing(ring, index, preset.color))
  draft.value = {
    ...DEFAULT_SETTINGS,
    color: preset.color,
    size: overall.size,
    opacity: overall.opacity,
    showCenterDot: false,
    appearance: {
      idle: { ...overall },
      moving: { ...overall }
    },
    transition: { ...DEFAULT_SETTINGS.transition },
    behavior: { ...DEFAULT_SETTINGS.behavior, ...(preset.behavior || {}) },
    rings
  }
  appliedPresetKey.value = preset.key
  selectRing(rings[0].id)
  selectEditingState('idle')
}

const reset = () => {
  draft.value = {
    ...DEFAULT_SETTINGS,
    appearance: {
      idle: { ...DEFAULT_SETTINGS.appearance.idle },
      moving: { ...DEFAULT_SETTINGS.appearance.moving }
    },
    transition: { ...DEFAULT_SETTINGS.transition },
    behavior: { ...DEFAULT_SETTINGS.behavior },
    rings: DEFAULT_SETTINGS.rings.map(cloneRing)
  }
  selectedRingId.value = draft.value.rings[0].id
  appliedPresetKey.value = null
  pendingOverallShape.value = null
  previewCursorFollowActive.value = false
  previewFullscreen.value = false
  selectEditingState('idle')
}

const selectEditingState = state => {
  editingState.value = state
  // 編集中は対象状態の形状を固定表示し、位置移動はプレビュークリック時だけ行う。
  previewMoving.value = state === 'moving'
}
const copyEditingStateToOther = () => {
  const source = editingState.value
  const destination = source === 'idle' ? 'moving' : 'idle'
  draft.value.appearance[destination] = { ...draft.value.appearance[source] }
  draft.value.rings.forEach(ring => {
    ring.appearance[destination] = {
      ...ring.appearance[source],
      segmentColors: [...ring.appearance[source].segmentColors],
      segmentLabels: [...ring.appearance[source].segmentLabels]
    }
    ring.motion[destination] = { ...ring.motion[source] }
  })
}

const schedulePreviewStep = (callback, duration, token) => {
  if (previewMoveTimer) clearTimeout(previewMoveTimer)
  previewMoveTimer = setTimeout(() => {
    if (token !== previewMoveToken) return
    previewMoveTimer = null
    callback()
  }, duration)
}
const runPreviewMove = position => {
  previewMoveToken += 1
  const token = previewMoveToken
  if (previewMoveTimer) clearTimeout(previewMoveTimer)
  const transition = draft.value.transition
  const sequence = ['before', 'simultaneous', 'after'].includes(transition.sequence)
    ? transition.sequence
    : 'before'
  const morphInDuration = Math.max(0, Number(transition.morphInDuration) || 0)
  const moveDuration = Math.max(100, Number(transition.moveDuration) || 350)
  const morphOutDuration = Math.max(0, Number(transition.morphOutDuration) || 0)
  const restore = () => {
    previewMoving.value = editingState.value === 'moving'
    schedulePreviewStep(() => {}, morphOutDuration, token)
  }
  const move = () => {
    previewPosition.value = position
    schedulePreviewStep(restore, moveDuration, token)
  }

  if (sequence === 'simultaneous') {
    previewMoving.value = true
    move()
    return
  }
  if (sequence === 'after') {
    previewMoving.value = false
    previewPosition.value = position
    schedulePreviewStep(() => {
      previewMoving.value = true
      schedulePreviewStep(restore, morphInDuration, token)
    }, moveDuration, token)
    return
  }

  previewMoving.value = true
  schedulePreviewStep(move, morphInDuration, token)
}
const movePreviewToPointer = event => {
  if (draft.value.behavior.followCursor) {
    previewCursorFollowActive.value = !previewCursorFollowActive.value
    if (previewCursorFollowActive.value) {
      movePreviewWithCursor(event)
    } else {
      endPreviewCursorFollow()
    }
    return
  }
  const rect = event.currentTarget.getBoundingClientRect()
  const x = Math.min(92, Math.max(8, (event.clientX - rect.left) / rect.width * 100))
  const y = Math.min(88, Math.max(12, (event.clientY - rect.top) / rect.height * 100))
  runPreviewMove({ x, y })
}
const endPreviewCursorFollow = () => {
  if (previewCursorAnimationFrame != null) cancelAnimationFrame(previewCursorAnimationFrame)
  previewCursorAnimationFrame = null
  previewCursorLastFrame = null
  previewCursorTarget = { ...previewPosition.value }
  previewMoving.value = editingState.value === 'moving'
}
const animatePreviewCursor = timestamp => {
  if (!draft.value.behavior.followCursor || !previewCursorFollowActive.value) {
    endPreviewCursorFollow()
    return
  }
  if (previewCursorLastFrame == null) previewCursorLastFrame = timestamp
  const elapsed = Math.min(50, Math.max(0, timestamp - previewCursorLastFrame))
  previewCursorLastFrame = timestamp
  const dx = previewCursorTarget.x - previewPosition.value.x
  const dy = previewCursorTarget.y - previewPosition.value.y
  const distance = Math.hypot(dx, dy)
  if (distance <= 0.05) {
    previewPosition.value = { ...previewCursorTarget }
    previewCursorAnimationFrame = null
    previewCursorLastFrame = null
    previewMoving.value = editingState.value === 'moving'
    return
  }
  const speed = Math.min(300, Math.max(10, Number(draft.value.behavior.cursorFollowSpeed) || 90))
  const movement = Math.min(distance, speed * elapsed / 1000)
  const ratio = movement / distance
  previewPosition.value = {
    x: previewPosition.value.x + dx * ratio,
    y: previewPosition.value.y + dy * ratio
  }
  previewMoving.value = true
  previewCursorAnimationFrame = requestAnimationFrame(animatePreviewCursor)
}
const startPreviewCursorMovement = () => {
  if (previewCursorAnimationFrame != null) return
  previewCursorLastFrame = null
  previewCursorAnimationFrame = requestAnimationFrame(animatePreviewCursor)
}
const movePreviewWithCursor = event => {
  if (!draft.value.behavior.followCursor || !previewCursorFollowActive.value) return
  const rect = event.currentTarget.getBoundingClientRect()
  previewCursorTarget = {
    x: Math.min(92, Math.max(8, (event.clientX - rect.left) / rect.width * 100)),
    y: Math.min(88, Math.max(12, (event.clientY - rect.top) / rect.height * 100))
  }
  startPreviewCursorMovement()
}
const onFollowCursorSettingChange = () => {
  if (draft.value.behavior.followCursor) return
  previewCursorFollowActive.value = false
  endPreviewCursorFollow()
}
const movePreviewToCenter = () => {
  if (draft.value.behavior.followCursor && previewCursorFollowActive.value) {
    previewCursorTarget = { x: 50, y: 50 }
    startPreviewCursorMovement()
    return
  }
  runPreviewMove({ x: 50, y: 50 })
}

const save = () => {
  emit('save', { ...draft.value })
}
</script>

<style scoped>
.custom-marker-modal {
  box-sizing: border-box;
  display: grid;
  grid-template-rows: auto 360px 1fr auto;
  gap: 16px;
  width: 720px;
  height: 1280px;
  padding: 18px;
  color: #d7f7ff;
  font-family: Consolas, monospace;
  font-size: 20px;
  scrollbar-color: #55dff5 rgba(3, 18, 28, 0.92);
  scrollbar-width: thin;
}

.custom-marker-modal.preview-fullscreen-mode {
  grid-template-rows: 1fr;
  gap: 0;
  width: 100%;
  height: 100%;
  padding: 0;
}
.preview-fullscreen-mode > .modal-header,
.preview-fullscreen-mode > .editor-layout,
.preview-fullscreen-mode > .modal-footer,
.preview-fullscreen-mode .preview-label,
.preview-fullscreen-mode .preview-controls {
  display: none;
}
.preview-fullscreen-mode .marker-preview {
  width: 100%;
  height: 100%;
  border: 0;
}

.custom-marker-modal button,
.custom-marker-modal input,
.custom-marker-modal select,
.custom-marker-modal output,
.custom-marker-modal code {
  font-family: inherit;
  font-size: inherit;
}

.custom-marker-modal *::-webkit-scrollbar {
  width: 10px;
  height: 9px;
}

.custom-marker-modal *::-webkit-scrollbar-track {
  border: 1px solid rgba(78, 199, 225, 0.22);
  background:
    repeating-linear-gradient(90deg, rgba(67, 204, 232, 0.08) 0 1px, transparent 1px 6px),
    rgba(2, 14, 23, 0.94);
  box-shadow: inset 0 0 7px rgba(22, 122, 148, 0.28);
}

.custom-marker-modal *::-webkit-scrollbar-thumb {
  border: 2px solid rgba(2, 17, 27, 0.95);
  border-radius: 1px;
  background: linear-gradient(90deg, #238ca8, #76efff 48%, #238ca8);
  box-shadow: 0 0 7px rgba(93, 229, 255, 0.72);
}

.custom-marker-modal *::-webkit-scrollbar-thumb:hover {
  background: linear-gradient(90deg, #39b5d0, #c5faff 48%, #39b5d0);
}

.custom-marker-modal *::-webkit-scrollbar-corner {
  background: #03131d;
}

.modal-header,
.modal-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-kicker {
  color: #71dff4;
  font-size: 20px;
  letter-spacing: 0.18em;
}

h2,
h3,
p { margin: 0; }
h2 { font-size: 28px; letter-spacing: 0.12em; }
h3 { font-size: 22px; letter-spacing: 0.08em; }
p { margin-top: 8px; color: rgba(200, 240, 250, 0.72); font-size: 20px; line-height: 1.45; }

.close-button,
.secondary-button,
.save-button,
.setting-list button,
.choice-grid button {
  border: 1px solid rgba(126, 224, 245, 0.5);
  background: rgba(8, 28, 40, 0.88);
  color: #d7f7ff;
  cursor: pointer;
}

.close-button,
.secondary-button,
.save-button { padding: 7px 12px; }
.close-button { width: auto; flex: 0 0 auto; }
.save-button { border-color: #aef6ff; background: rgba(30, 97, 115, 0.95); }

.marker-preview {
  position: relative;
  display: grid;
  place-items: center;
  height: 360px;
  overflow: hidden;
  border: 1px solid rgba(116, 220, 245, 0.3);
  background-color: var(--preview-background, #071722);
  background-image: radial-gradient(circle at center, rgba(80, 180, 210, 0.28), transparent 72%);
  cursor: crosshair;
}

.preview-label {
  position: absolute;
  top: 10px;
  left: 12px;
  color: rgba(180, 240, 250, 0.66);
  font-size: 20px;
  letter-spacing: 0.14em;
}
.fullscreen-return-hint {
  position: absolute;
  top: 18px;
  left: 50%;
  z-index: 4;
  padding: 8px 14px;
  border: 1px solid rgba(142, 238, 255, 0.45);
  background: rgba(3, 18, 28, 0.82);
  color: rgba(215, 247, 255, 0.84);
  letter-spacing: 0.08em;
  translate: -50% 0;
  pointer-events: none;
  animation: fullscreenHintFade 3s ease-out forwards;
}

.preview-controls {
  position: absolute;
  top: 10px;
  right: 12px;
  z-index: 2;
  display: flex;
  align-items: center;
  gap: 6px;
}
.preview-controls > span {
  padding: 6px 10px;
  color: #9fefff;
  background: rgba(4, 22, 33, 0.78);
}
.preview-controls > span.tracking {
  color: #fff5bb;
  border: 1px solid rgba(255, 228, 123, 0.58);
  box-shadow: 0 0 8px rgba(255, 222, 108, 0.3);
}
.preview-controls button {
  width: auto;
  padding: 6px 12px;
  border: 1px solid rgba(126, 224, 245, 0.42);
  background: rgba(4, 22, 33, 0.86);
  color: rgba(215, 247, 255, 0.72);
  cursor: pointer;
}
.preview-controls button:hover {
  border-color: #bdf7ff;
  background: rgba(34, 112, 134, 0.94);
  color: #fff;
  box-shadow: 0 0 8px rgba(89, 220, 250, 0.35);
}
.preview-target {
  position: absolute;
  z-index: 1;
  transform: translate(-50%, -50%);
  pointer-events: none;
}

.editor-layout {
  display: grid;
  grid-template-columns: 142px 1fr;
  grid-template-rows: auto auto minmax(0, 1fr);
  min-height: 0;
  border: 1px solid rgba(116, 220, 245, 0.3);
}

.editor-state-tabs {
  display: flex;
  grid-column: 1 / -1;
  align-items: center;
  gap: 8px;
  padding: 9px 10px;
  border-bottom: 1px solid rgba(116, 220, 245, 0.3);
  background: rgba(4, 20, 30, 0.96);
}
.editor-state-tabs > span {
  margin-right: auto;
  color: rgba(158, 239, 255, 0.68);
  letter-spacing: 0.1em;
}
.editor-state-tabs button {
  width: auto;
  min-width: 120px;
  padding: 8px 14px;
  border: 1px solid rgba(126, 224, 245, 0.42);
  background: rgba(5, 23, 34, 0.8);
  color: rgba(215, 247, 255, 0.72);
  cursor: pointer;
}
.editor-state-tabs button.active {
  border-color: #bdf7ff;
  background: rgba(34, 112, 134, 0.94);
  color: #fff;
  box-shadow: 0 0 8px rgba(89, 220, 250, 0.35);
}
.editor-state-tabs .state-copy-button {
  min-width: 0;
  color: #ffe9a6;
  border-color: rgba(255, 222, 130, 0.5);
}

.ring-tabs {
  display: flex;
  grid-column: 1 / -1;
  align-items: center;
  gap: 12px;
  min-width: 0;
  padding: 8px 10px 0;
  border-bottom: 1px solid rgba(116, 220, 245, 0.3);
  background: rgba(2, 12, 21, 0.92);
}

.ring-tabs-label {
  flex: 0 0 auto;
  padding-bottom: 8px;
  color: rgba(158, 239, 255, 0.68);
  font-size: 20px;
  letter-spacing: 0.14em;
}

.ring-tabs-list {
  display: flex;
  flex: 1 1 auto;
  min-width: 0;
  gap: 4px;
  overflow-x: auto;
}

.ring-tabs-list button {
  display: flex;
  align-items: center;
  gap: 6px;
  flex: 0 0 auto;
  justify-content: center;
  min-width: 0;
  width: max-content;
  padding: 9px 18px;
  border: 1px solid rgba(126, 224, 245, 0.28);
  border-bottom: 0;
  border-radius: 5px 5px 0 0;
  background: rgba(8, 28, 40, 0.72);
  color: rgba(215, 247, 255, 0.68);
  cursor: pointer;
}

.ring-tabs-list button.active {
  border-color: #bdf7ff;
  background: rgba(34, 112, 134, 0.96);
  color: #fff;
  box-shadow: 0 -3px 10px rgba(89, 220, 250, 0.3);
}

.ring-tabs-list button.hidden { opacity: 0.48; }
.ring-tabs-list button.active.hidden { opacity: 0.78; }
.ring-tabs .ring-tab-add {
  flex: 0 0 38px;
  width: 38px;
  height: 35px;
  padding: 0;
  border: 1px solid rgba(126, 224, 245, 0.5);
  border-radius: 4px;
  background: rgba(8, 28, 40, 0.88);
  color: #8defff;
  font-size: 24px;
  line-height: 1;
  cursor: pointer;
}
.ring-tabs .ring-tab-add:hover:not(:disabled) {
  border-color: #bdf7ff;
  background: rgba(34, 112, 134, 0.72);
  color: #fff;
}
.ring-tabs .ring-tab-add:disabled {
  cursor: not-allowed;
  opacity: 0.35;
}
.ring-tab-color {
  width: 9px;
  height: 9px;
  flex: 0 0 auto;
  border: 1px solid rgba(255, 255, 255, 0.75);
  border-radius: 50%;
  box-shadow: 0 0 5px currentColor;
}

.setting-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 10px;
  border-right: 1px solid rgba(116, 220, 245, 0.22);
  background: rgba(3, 14, 24, 0.65);
}

.setting-list button { padding: 10px; text-align: left; }
.setting-list button.active,
.choice-grid button.active { border-color: #c4faff; background: rgba(34, 112, 134, 0.9); box-shadow: 0 0 9px rgba(89, 220, 250, 0.32); }

.setting-content { padding: 16px; overflow-y: auto; }
.render-mode-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  margin-top: 16px;
}
.render-mode-grid button {
  min-height: 48px;
  padding: 8px 10px;
  border: 1px solid rgba(126, 224, 245, 0.42);
  background: rgba(8, 28, 40, 0.88);
  color: #d7f7ff;
  cursor: pointer;
}
.ring-advanced-settings {
  margin-top: 14px;
  padding: 10px;
  border: 1px solid rgba(126, 224, 245, 0.34);
  background: rgba(5, 22, 34, 0.58);
}
.ring-advanced-settings summary {
  color: #bdf7ff;
  font-weight: 700;
  cursor: pointer;
}
.ring-advanced-settings > p {
  margin: 9px 0 12px;
  color: rgba(205, 238, 247, 0.68);
  font-size: 12px;
  line-height: 1.5;
}
.advanced-toggle-pair {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  margin: 10px 0;
}
.render-mode-grid button.active {
  border-color: #c4faff;
  background: rgba(34, 112, 134, 0.9);
  box-shadow: 0 0 9px rgba(89, 220, 250, 0.32);
}
.render-mode-description {
  min-height: 58px;
  padding: 8px 10px;
  border-bottom: 1px solid rgba(126, 224, 245, 0.22);
}
.danger-settings {
  margin-top: 18px;
  padding: 12px;
  border: 1px solid rgba(255, 174, 112, 0.4);
  background: rgba(62, 25, 14, 0.24);
}
.danger-settings summary {
  color: #ffd09b;
  font-weight: 700;
  cursor: pointer;
}
.shape-confirmation {
  margin-top: 14px;
  padding: 12px;
  border: 1px solid rgba(255, 210, 122, 0.55);
  background: rgba(91, 53, 12, 0.46);
  color: #fff0bd;
}
.shape-confirmation > div {
  display: flex;
  gap: 8px;
  margin-top: 10px;
}
.shape-confirmation button {
  width: auto;
  padding: 7px 12px;
  border: 1px solid rgba(255, 220, 142, 0.6);
  background: rgba(52, 28, 9, 0.9);
  color: #fff2c9;
  cursor: pointer;
}
.setting-note {
  margin-top: 18px;
  padding: 10px 12px;
  border-left: 3px solid #71dff4;
  background: rgba(20, 67, 82, 0.32);
  color: rgba(215, 247, 255, 0.82);
}
.preview-fullscreen-button {
  width: 100%;
  margin-top: 18px;
  padding: 12px;
  border: 1px solid rgba(126, 224, 245, 0.55);
  background: rgba(21, 78, 94, 0.72);
  color: #e2faff;
  cursor: pointer;
}
.preview-fullscreen-button:hover {
  border-color: #c4faff;
  background: rgba(34, 112, 134, 0.9);
}
.preset-notice {
  margin-top: 16px;
  padding: 10px 12px;
  border-left: 3px solid #f0c96b;
  background: rgba(101, 74, 20, 0.24);
  color: #ffe6a3;
}
.existing-preset-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
  margin-top: 18px;
}
.existing-preset-grid button {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 52px;
  padding: 10px 14px;
  border: 1px solid rgba(126, 224, 245, 0.42);
  background: rgba(8, 28, 40, 0.88);
  color: #d7f7ff;
  text-align: left;
  cursor: pointer;
}
.existing-preset-grid button:hover,
.existing-preset-grid button.active {
  border-color: #c4faff;
  background: rgba(34, 112, 134, 0.9);
  box-shadow: 0 0 9px rgba(89, 220, 250, 0.32);
}
.library-name-row {
  display: grid;
  grid-template-columns: 120px minmax(0, 1fr);
  align-items: center;
  gap: 10px;
  margin-top: 18px;
  font-size: 20px;
}
.library-name-row input {
  min-width: 0;
  border: 1px solid rgba(126, 224, 245, 0.5);
  background: rgba(4, 19, 29, 0.92);
  color: #e3fbff;
  padding: 8px 10px;
}
.library-toolbar {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  margin-top: 14px;
}
.library-toolbar button,
.library-marker-actions button,
.library-marker-summary {
  border: 1px solid rgba(126, 224, 245, 0.48);
  background: rgba(8, 28, 40, 0.88);
  color: #d7f7ff;
  cursor: pointer;
}
.library-toolbar button { padding: 9px 10px; }
.library-toolbar button:disabled { cursor: not-allowed; opacity: 0.4; }
.marker-settings-file-input { display: none; }
.library-export-note {
  margin: 10px 0 0;
  color: rgba(201, 248, 255, 0.72);
  font-size: 18px;
  line-height: 1.45;
}
.library-notice,
.library-empty {
  margin-top: 14px;
  padding: 10px 12px;
  border-left: 3px solid #71dff4;
  background: rgba(20, 67, 82, 0.32);
  color: #c9f8ff;
  font-size: 20px;
  line-height: 1.4;
}
.library-empty { color: rgba(200, 240, 250, 0.62); }
.marker-library-list {
  display: grid;
  gap: 8px;
  margin-top: 14px;
}
.marker-library-list article {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 8px;
  padding: 7px;
  border: 1px solid rgba(126, 224, 245, 0.24);
  background: rgba(4, 18, 28, 0.72);
}
.marker-library-list article.active {
  border-color: #9ef2ff;
  box-shadow: inset 3px 0 #71dff4, 0 0 8px rgba(89, 220, 250, 0.24);
}
.library-marker-summary {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  align-items: center;
  gap: 9px;
  min-width: 0;
  padding: 8px 10px;
  text-align: left;
}
.library-marker-color {
  width: 14px;
  height: 14px;
  border: 1px solid #e7fcff;
  border-radius: 50%;
  box-shadow: 0 0 7px currentColor;
}
.library-marker-name { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.library-marker-meta { color: #8ddfed; font-size: 20px; white-space: nowrap; }
.library-marker-actions { display: flex; align-items: stretch; gap: 5px; }
.library-marker-actions button { padding: 7px 9px; }
.library-marker-actions .library-delete-button { border-color: rgba(255, 146, 146, 0.55); color: #ffb7b7; }
.preset-color {
  width: 13px;
  height: 13px;
  flex: 0 0 13px;
  border: 1px solid rgba(255, 255, 255, 0.85);
  border-radius: 50%;
  box-shadow: 0 0 8px currentColor;
}
.section-heading { display: flex; align-items: start; justify-content: space-between; gap: 16px; }
.ring-action-buttons { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 6px; }
.ring-action-buttons button {
  width: auto;
  padding: 6px 9px;
  border: 1px solid rgba(126, 224, 245, 0.5);
  background: rgba(8, 28, 40, 0.88);
  color: #d7f7ff;
  cursor: pointer;
}
.ring-action-buttons button:disabled { cursor: not-allowed; opacity: 0.38; }
.segment-color-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 8px;
  margin-top: 14px;
}
.segment-color-grid label {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 5px;
  padding: 6px;
  border: 1px solid rgba(126, 224, 245, 0.28);
  background: rgba(5, 23, 34, 0.72);
}
.segment-color-grid input[type='color'] {
  width: 34px;
  height: 28px;
  padding: 0;
  border: 0;
}
.text-setting-row {
  grid-template-columns: 132px minmax(0, 1fr) auto;
}
.text-value-input,
.segment-label-grid input[type='text'] {
  min-width: 0;
  border: 1px solid rgba(126, 224, 245, 0.42);
  background: rgba(4, 19, 29, 0.92);
  color: #e3fbff;
  padding: 7px 9px;
}
.segment-label-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 8px;
  margin: 14px 0;
}
.segment-label-grid label {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  align-items: center;
  gap: 6px;
  padding: 6px;
  border: 1px solid rgba(126, 224, 245, 0.28);
  background: rgba(5, 23, 34, 0.72);
}
.add-ring-button,
.remove-ring-button {
  border: 1px solid rgba(126, 224, 245, 0.5);
  background: rgba(8, 28, 40, 0.88);
  color: #d7f7ff;
  cursor: pointer;
}
.add-ring-button { padding: 7px 10px; white-space: nowrap; }
.add-ring-button,
.remove-ring-button { width: auto; }
.remove-ring-button { margin-top: 18px; padding: 7px 10px; color: #ffb7b7; border-color: rgba(255, 146, 146, 0.55); }
.remove-ring-button:disabled { cursor: not-allowed; opacity: 0.4; }
.choice-grid { display: flex; flex-wrap: wrap; gap: 7px; margin-top: 15px; }
.choice-grid button { width: auto; min-width: 70px; padding: 8px 12px; }

.setting-row {
  display: grid;
  grid-template-columns: 130px 1fr auto;
  gap: 10px;
  align-items: center;
  margin-top: 18px;
  font-size: 20px;
}

.setting-row input[type='range'] { width: 100%; }
.setting-row output { min-width: 42px; text-align: right; color: #9fefff; }
.color-row input[type='color'] { width: 40px; height: 28px; padding: 0; border: 0; background: transparent; }
.color-row code { color: #9fefff; font-family: inherit; }
.setting-row input[type='color'] { width: 40px; height: 28px; padding: 0; border: 0; background: transparent; }
.setting-row code { color: #9fefff; font-family: inherit; }
.select-row select { grid-column: 2 / 4; min-height: 30px; border: 1px solid rgba(126, 224, 245, 0.5); background: #081c28; color: #d7f7ff; }
.select-row select:disabled,
.setting-row input:disabled,
.toggle-row input:disabled { opacity: 0.45; cursor: not-allowed; }

.toggle-row { display: flex; gap: 9px; align-items: center; margin-top: 18px; font-size: 20px; }
.toggle-row input[type='checkbox'] { width: 20px; height: 20px; flex: 0 0 20px; }
.motion-block {
  margin-top: 18px;
  padding: 14px;
  border: 1px solid rgba(126, 224, 245, 0.3);
  background: rgba(5, 23, 34, 0.68);
}
.motion-block .motion-toggle { margin-top: 0; color: #bdf7ff; font-weight: 700; }
.state-enabled-toggle {
  padding: 10px 12px;
  border-left: 3px solid #71dff4;
  background: rgba(20, 67, 82, 0.32);
}
.transition-settings {
  margin-top: 24px;
  padding-top: 18px;
  border-top: 1px solid rgba(126, 224, 245, 0.3);
}
.modal-footer { margin: 0; }
.modal-footer > button { width: auto; flex: 1 1 0; }

@keyframes fullscreenHintFade {
  0%, 65% { opacity: 1; }
  100% { opacity: 0; }
}

@media (max-width: 640px) {
  .editor-layout { grid-template-columns: 108px 1fr; }
  .setting-row { grid-template-columns: 1fr; gap: 5px; }
}
</style>
