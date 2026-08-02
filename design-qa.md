# Poco Character & Reward Set — Design QA

- Source visual truth: 24 transparent runtime PNGs, 2 transparent source layers, and 5 portrait JPEG backgrounds supplied on 2026-08-01
- Source pixels: character/reward artwork 1024 × 1024; backgrounds 590 × 1280
- Intended viewport: iPhone portrait, iOS 17+
- States: Welcome, common/rare puyo, Q&A, login bonus, Pro, onboarding, creator heart, achievements, Star Shop, project backgrounds

## Static asset comparison

The character sources were imported without resampling. The 10 reward sources were
downsampled to 512 × 512 for their small UI slots. Transparent edges, lavender outlines,
pink highlights, facial expressions, props, and glow effects are preserved. The Pro source
contained a half-transparent full-canvas gray layer; that layer was removed while the crown
and local gold glow were retained. The original file is archived.

The imported set was reviewed together on an off-white canvas. No opaque boxes, clipped
ears, props, text, or missing artwork were found after the Pro alpha correction.

The five portrait watercolor backgrounds are imported as opaque JPEG assets without
resampling. Their pale centers remain clear for bubbles and text, while the motifs stay near
the outer edges of the phone viewport.

## Integration checks

- Common SpriteKit companion: `PocoCharacterDefault`
- Rare merge result: `PocoCharacterRare`
- Welcome / Q&A / login bonus / Pro / onboarding / creator heart: assigned by state
- Achievement stamps: six supplied medallions assigned to their existing conditions
- Star Shop: two supplied medallions assigned to existing catalog IDs; Poco Heart reuses the creator-heart medallion
- Star currency and creator-heart notification: supplied standalone artwork assigned
- Star states: normal, earned, large reward burst, and bundle artwork assigned; the white mask remains archived as a source layer
- Project background catalog: five existing SKU IDs assigned to the supplied watercolor assets
- Previous common character: archived outside `Assets.xcassets`
- Reduce Motion: existing SwiftUI and SpriteKit fallbacks remain unchanged
- Swift 6, iOS 17 Debug build: passed
- Swift 6, iOS 17 Release build: passed

## Remaining visual check

CoreSimulatorService is unavailable in the execution environment, so apparent size and
motion inside the final iPhone viewport still require one simulator or physical-device pass.

final result: blocked
