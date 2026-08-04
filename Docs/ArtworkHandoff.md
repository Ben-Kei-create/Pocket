# Poco Artwork Handoff

デザイン素材をSwiftUIへ安全に差し替えるための受け渡し表です。
標準操作（戻る、閉じる、検索、共有、通知、タブ）はSF Symbolsを維持します。

## 共通仕様

- PNG、sRGB、文字なし
- キャラクター／アイコン／バッジは透過背景
- 外周に約10%の余白
- 影は素材内へ強く焼き込まず、必要な場合はSwiftUI側で付与
- ファイル名は下表のまま。日本語・空白・連番だけの名前は使わない
- アニメーションは静止画1枚をSwiftUI／SpriteKitで変形する

## Priority A: Pocoキャラクター

推奨サイズ: 1024×1024 px

| Asset名 | 用途 |
|---|---|
| `PocoCharacterDefault` | Welcome、プロフィール、通常ぷよ |
| `PocoCharacterHappy` | 投稿完了、ログインボーナス |
| `PocoCharacterHeart` | 作者❤️、共感 |
| `PocoCharacterStar` | スター獲得、ショップ |
| `PocoCharacterQuestion` | Q&A |
| `PocoCharacterLetter` | Poco Letter |
| `PocoCharacterSleep` | 空状態、利用終了 |
| `PocoCharacterSorry` | エラー、通信失敗 |
| `PocoCharacterPro` | Pro案内 |
| `PocoCharacterRare` | Pro限定レア誕生 |

## Priority A: スターと作者❤️

推奨サイズ: 512×512 px

| Asset名 | 用途 |
|---|---|
| `PocoStarCoin` | 通常のスター表示 |
| `PocoStarCoinEarned` | 獲得時 |
| `PocoStarCoinBurst` | 大きな獲得時 |
| `PocoStarCoinBundle` | スター袋、作品枠の解放 |
| `PocoStarCoinSpent` | 使用確認（未受領） |
| `PocoCreatorHeart` | フキダシ詳細 |
| `PocoCreatorHeartReceived` | 作者❤️受信 |
| `PocoCreatorHeartNotification` | 通知一覧 |

## Priority A: バッジ

推奨サイズ: 512×512 px

達成スタンプは54種類へ拡張済みです。全Asset名と条件は
`Docs/AchievementStampCatalog.md`を正とします。

| Asset名 | 表示名 | 種別 |
|---|---|---|
| `BadgeFirstFeedback` | はじめのことば | 達成 |
| `BadgeThreeFeedbacks` | ことばの花束 | 達成 |
| `BadgeFirstProject` | はじめての感想箱 | 達成 |
| `BadgeFirstLike` | はじめての共感 | 達成 |
| `BadgeCreatorHeart` | 作者に届いた！ | 達成 |
| `BadgeSevenDayStreak` | Pocoな一週間 | 達成 |
| `BadgeFirstLight` | はじめの灯り | ショップ |
| `BadgeWordBouquet` | ことばの花束 | ショップ |
| `BadgePocoHeart` | Pocoハート | ショップ |

達成バッジとショップバッジは、形・縁・台座のいずれかで見分けられるようにします。

## Priority B: オンボーディング

推奨サイズ: 1200×900 px

| Asset名 | 用途 |
|---|---|
| `OnboardingDrop` | フキダシを落とす |
| `OnboardingReaction` | 反応を受け取る |
| `OnboardingCreate` | 作品を作る |
| `OnboardingProPhysics` | Proの合体・レア |
| `OnboardingProAnalytics` | Pro分析 |
| `OnboardingProLetter` | Poco Letter |

## Priority B: カテゴリの代替表紙

推奨サイズ: 1200×900 px、角丸なし

| Asset名 | 用途 |
|---|---|
| `ProjectFallbackBook` | 本 |
| `ProjectFallbackGame` | ゲーム |
| `ProjectFallbackManga` | マンガ |
| `ProjectFallbackAnime` | アニメ |
| `ProjectFallbackOther` | その他 |

## Priority B: 空状態・完了状態

推奨サイズ: 1024×768 px

| Asset名 | 用途 |
|---|---|
| `EmptyHome` | 検索結果なし |
| `EmptyNotifications` | 通知なし |
| `EmptyQAndA` | Q&Aなし |
| `EmptyProjects` | 自作品なし |
| `EmptyFeedbacks` | 感想なし |
| `FeedbackDelivered` | フキダシ着地完了 |
| `DailyLoginBonus` | ログインボーナス |

## Priority C: 作品背景

推奨サイズ: 1290×2796 px。中央付近へ文字や主要モチーフを置かない。

| Asset名 | 用途 |
|---|---|
| `ProjectBackgroundSakura` | さくら |
| `ProjectBackgroundLemon` | レモン |
| `ProjectBackgroundSky` | そら |
| `ProjectBackgroundMint` | ミント |
| `ProjectBackgroundLavender` | ラベンダー |

## 受け渡し順

最初は次の15点だけで、主要画面の印象をほぼ置換できます。

1. Pocoキャラクター10種
2. `PocoCreatorHeart`
3. `PocoStarCoin`
4. `BadgeFirstFeedback`
5. `BadgeWordBouquet`
6. `BadgePocoHeart`

受領後は元素材を`Archive/`へ保存し、Asset Catalog名を保ったまま差し替えます。

## 2026-08-01 受領済み

- Pocoキャラクター10種: `Default` / `Happy` / `Heart` / `Star` / `Question` / `Letter` / `Sleep` / `Sorry` / `Pro` / `Rare`
- スター: `PocoStarCoin` / `PocoStarCoinEarned` / `PocoStarCoinBurst` / `PocoStarCoinBundle`
- 作者❤️: `PocoCreatorHeart` / `PocoCreatorHeartReceived`
- 達成バッジ6種: `BadgeFirstFeedback` / `BadgeThreeFeedbacks` / `BadgeFirstProject` / `BadgeFirstLike` / `BadgeCreatorHeart` / `BadgeSevenDayStreak`
- ショップバッジ2種: `BadgeFirstLight` / `BadgeWordBouquet`
- 作品背景5種: `ProjectBackgroundSakura` / `ProjectBackgroundLemon` / `ProjectBackgroundSky` / `ProjectBackgroundMint` / `ProjectBackgroundLavender`
- `BadgePocoHeart`は、専用素材を受領するまで`PocoCreatorHeartReceived`を使用
- 旧キャラクター: `Archive/Characters/Previous/`へ保存
- 背景一覧3枚とバッジ見本シートは参照用。アプリには個別の縦長背景と既存の個別バッジ素材を使用

スターの白い形状レイヤーは`Archive/Rewards/SourceLayers/`へ保存し、画面には表示しません。

現在のPriority A残りは、スター使用確認と、作者❤️通知・Pocoハート専用素材です。
