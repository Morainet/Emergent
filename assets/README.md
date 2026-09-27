# 游戏素材

以下 PNG 使用 Codex 内置 `image_gen` 生成；狼的 GLB 则由 Godot 原生网格代码生成并导出，并非图片转 3D。地表、树冠、石材、角色外套材质和 HUD 图标已接入 3D 主场景。角色概念图仍是建模参考；当前主角与营地同伴 Ari 共用 `scripts/explorer_avatar.gd` 的程序化几何体，以不同材质和配色区分，而不是直接加载概念图作为 3D 模型。无外部图库素材。

| 文件 | 用途 |
| --- | --- |
| `textures/forest_floor.png` | 森林地表纹理，重复铺设 |
| `textures/ruin_stone.png` | 遗迹石柱、石台纹理 |
| `textures/trail_earth.png` | 三条探索小径的泥土落叶纹理 |
| `textures/moss_bark.png` | 树干与倒木的苔藓树皮纹理 |
| `textures/pine_canopy.png` | 松树树冠针叶纹理 |
| `characters/explorer_canvas.png` | 主角青色外套织物纹理 |
| `characters/ari_canvas.png` | Ari 暖棕色外套织物纹理 |
| `models/wolf_lowpoly.glb` | Godot 原生网格生成的静态低多边形狼模型，可独立预览；游戏内动画由 `scenes/wolf_avatar.tscn` 驱动 |
| `ui/signal_shard.png` | HUD 三格信号石收集指示，透明背景 |
| `characters/explorer_concept.png` | 主角完整服装与气质设定图 |
| `characters/explorer_lowpoly_reference.png` | 与 Demo 风格更接近的低多边形角色建模参考 |

## 生成提示词

### forest_floor.png

> Asset type: tileable game texture for a Godot 3D low-poly survival exploration game. Primary request: an orthographic, perfectly flat top-down seamless forest floor material. Muted deep moss green base, broad subtle hand-painted patches of short grass and moss, a few tiny desaturated leaf flecks, quiet painterly low-poly aesthetic. Even ambient illumination. The image must fill edge to edge with no border and have no focal object, no cast shadow, no perspective, no horizon, no text, no watermark. Square texture; opposing edges must match for repeat tiling.

### ruin_stone.png

> Asset type: tileable game texture for a Godot 3D low-poly survival exploration game. Primary request: orthographic, perfectly flat top-down seamless ancient ruin stone material. Muted blue-gray weathered rock, subtle angular chips, pale mineral grain and moss trapped in shallow cracks. Restrained hand-painted low-poly look, readable but not busy from a third-person camera. Even ambient illumination. Fill edge to edge, no border, no individual tile slabs, no perspective, no cast shadow, no text, no watermark. Square texture; opposing edges must match for repeat tiling.

### trail_earth.png

> Use case: stylized-concept. Asset type: seamless tileable ground texture for a Godot low-poly third-person forest exploration game, used on narrow walking trails. Orthographic perfectly flat top-down view of compacted warm umber soil, subtle sparse golden dry leaf flecks, tiny muted pebbles, soft painterly variation, coherent with an existing moss-green forest floor and blue-gray ruins. Even ambient illumination. Square, fill edge to edge, opposing edges should match for tiling. No large objects, no path outline, no border, no shadows, no perspective, no text, no watermark.

### moss_bark.png

> Use case: stylized-concept. Asset type: seamless tileable bark texture for cylindrical and box-shaped low-poly forest trees and fallen logs in a Godot third-person game. Orthographic flat material swatch, vertical dark umber bark striations with restrained gray-green moss in crevices, chunky hand-painted shapes, readable at medium distance, muted natural palette. Even ambient illumination. Square, fill edge to edge, opposing edges should match for tiling. No trunk silhouette, no leaves, no scene, no cast shadow, no text, no border, no watermark.

### pine_canopy.png

> Use case: stylized-concept. Asset type: square seamless tileable low-poly forest canopy texture for cone-shaped pine tree foliage in a Godot 3D exploration game. Flat orthographic material swatch only: muted pine green and sage needle clusters, hand-painted angular foliage patches, gentle tonal variation and sparse moss hints, designed to be readable from a third-person camera. Even neutral lighting, fill edge to edge, opposing edges visually match. No complete tree, no trunk, no scene, no horizon, no cast shadow, no text, border or watermark.

### explorer_canvas.png

> Use case: stylized-concept. Asset type: square seamless tileable material texture for the playable explorer's muted teal jacket in a Godot 3D low-poly survival exploration game. Flat orthographic fabric swatch only: restrained hand-painted woven canvas with subtle faded teal panels, a few darker worn threads and soft desaturated highlights; medium-scale broad shapes readable from a third-person camera, not photoreal. Even neutral ambient lighting, fill edge to edge, opposing edges visually match. No garment silhouette, buttons, seams, logo, text, border, shadow, perspective or watermark.

### ari_canvas.png

> Use case: stylized-concept. Asset type: square seamless tileable material texture for Ari, the AI companion's warm ochre-brown field jacket in a low-poly Godot forest exploration game. Flat orthographic fabric swatch only: hand-painted rugged woven canvas, muted copper-brown and warm tan threads with subtle faded patches; broad understated shapes readable at third-person camera distance. Visually distinct from the playable explorer's cool teal jacket but the same art style. Even neutral ambient lighting, fill edge to edge, opposing edges visually match. No garment silhouette, buttons, seams, symbols, logo, text, border, shadow, perspective or watermark.

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
