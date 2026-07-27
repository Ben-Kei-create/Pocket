# Bubble artwork styles

`BubbleArtworkStyle.active` controls the artwork used by both SwiftUI and SpriteKit bubbles.

- `standardCapsule`: current tail-less capsule based on the July 2026 reference sheet.
- `classicSpeech`: archived glossy speech bubble with a bottom-right tail.

The classic `BubbleTexture.imageset` and `SpeechBubbleShape` remain in the project so the previous look can be restored by changing only `BubbleArtworkStyle.active`.

The premium reference sheet is reserved for future subscriber styles such as cloud, wave, slim, rounded capsule, and double-line. Those styles should receive separate assets before being added to the enum.
