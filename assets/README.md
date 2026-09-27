# 游戏素材

以下 PNG 使用 Codex 内置 `image_gen` 生成。地表、石材和 HUD 图标已接入 3D 主场景。角色图目前是建模参考，尚不是可在 Godot 中操控的 3D 模型。无外部图库素材。

| 文件 | 用途 |
| --- | --- |
| `textures/forest_floor.png` | 森林地表纹理，重复铺设 |
| `textures/ruin_stone.png` | 遗迹石柱、石台纹理 |
| `ui/signal_shard.png` | HUD 三格信号石收集指示，透明背景 |
| `characters/explorer_concept.png` | 主角完整服装与气质设定图 |
| `characters/explorer_lowpoly_reference.png` | 与 Demo 风格更接近的低多边形角色建模参考 |

## 生成提示词

### forest_floor.png

> Asset type: tileable game texture for a Godot 3D low-poly survival exploration game. Primary request: an orthographic, perfectly flat top-down seamless forest floor material. Muted deep moss green base, broad subtle hand-painted patches of short grass and moss, a few tiny desaturated leaf flecks, quiet painterly low-poly aesthetic. Even ambient illumination. The image must fill edge to edge with no border and have no focal object, no cast shadow, no perspective, no horizon, no text, no watermark. Square texture; opposing edges must match for repeat tiling.

### ruin_stone.png

> Asset type: tileable game texture for a Godot 3D low-poly survival exploration game. Primary request: orthographic, perfectly flat top-down seamless ancient ruin stone material. Muted blue-gray weathered rock, subtle angular chips, pale mineral grain and moss trapped in shallow cracks. Restrained hand-painted low-poly look, readable but not busy from a third-person camera. Even ambient illumination. Fill edge to edge, no border, no individual tile slabs, no perspective, no cast shadow, no text, no watermark. Square texture; opposing edges must match for repeat tiling.

### signal_shard.png

> Asset type: game HUD icon for a Godot 3D low-poly survival exploration game. Primary request: a single luminous cyan signal stone shard, faceted crystal with a simple strong silhouette and a tiny warm golden inner spark. Centered, square composition with generous clear padding. Polished hand-painted low-poly fantasy game icon, colors teal, sea-glass cyan, muted amber; restrained glow. Genuinely transparent background with preserved alpha, no frame, no text, no logo, no watermark.

### explorer_concept.png

> Use case: stylized-concept
> Asset type: full-body playable protagonist character concept art for the 3D Godot game Emergent: The Last Signal
> Primary request: one original forest explorer, an androgynous young adult survivor who searches ancient ruins for luminous signal stones
> Subject: full body visible, human proportions suitable for a third-person game; short dark hair, warm skin tone, practical muted teal jacket over a simple tan undershirt, dark rugged trousers, sturdy boots, small weathered crossbody satchel, one subtle cyan signal-stone pendant. Calm, alert expression; grounded and resourceful, not a superhero.
> Style/medium: polished hand-painted stylized low-poly game character concept, clear large shapes and readable silhouette, restrained painterly material detail that matches a muted moss-green forest and blue-gray ruins.
> Composition/framing: single character standing in relaxed three-quarter view, head to boots fully in frame, centered with generous breathing room; neutral soft warm-gray studio background, no scenery, no panels.
> Lighting/mood: soft daylight with a gentle cyan accent reflected from pendant.
> Constraints: one person only, no weapons, no text, no logos, no watermark, no cut-off limbs, anatomically coherent hands.

### explorer_lowpoly_reference.png

The image above was used as an edit target. Final prompt:

> Use case: style-transfer
> Image 1: character design reference. Keep the same single forest explorer's identity, hairstyle, teal jacket, tan undershirt, dark trousers, boots, crossbody satchel, and cyan pendant. Change only the rendering style and simplify surface detail.
> Create a full-body stylized low-poly 3D game character render suitable as a visual target for a Godot third-person game: clear chunky geometry, large planar shapes, hand-painted flat color blocks, intentionally simplified seams and pockets, expressive but simple face, game-readable silhouette at medium distance. Standing neutral in three-quarter front view, entire figure including boots in frame, centered on a clean warm-gray studio backdrop. Muted moss/teal/stone palette with a small cyan pendant accent. No realistic fabric grain, no photoreal skin, no concept sheet panels, no scenery, no weapon, no text, no watermark.
