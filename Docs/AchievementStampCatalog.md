# Poco 達成スタンプ一覧

達成スタンプは54種類です。条件はSupabase側で判定し、初回達成時だけ通知を作ります。
画像が未制作のスタンプは、アプリ内でSF Symbolsの仮画像を表示します。

## 画像仕様

- 512×512 px、PNG、sRGB、透過背景
- 円形のスタンプ台座を含め、外周に約8〜10%の余白
- 文字は画像へ入れない（名称はSwiftUIで表示）
- Asset Catalog名は下表の `Asset名` と完全一致

## 感想を届けた数（10種）

| 表示名 | 条件 | Asset名 |
|---|---:|---|
| はじめのことば | 1件 | `BadgeFirstFeedback` |
| ことばの花束 | 3件 | `BadgeThreeFeedbacks` |
| ことばの芽 | 5件 | `BadgeFeedback5` |
| ことばの小径 | 10件 | `BadgeFeedback10` |
| ことば日和 | 20件 | `BadgeFeedback20` |
| ことばの庭 | 30件 | `BadgeFeedback30` |
| ことばの森 | 50件 | `BadgeFeedback50` |
| 百のことば | 100件 | `BadgeFeedback100` |
| ことばの星空 | 200件 | `BadgeFeedback200` |
| ことばの銀河 | 500件 | `BadgeFeedback500` |

## 感想を届け続けた日数（10種）

同じ日に複数件送っても1日として数え、これまでの最長連続日数で判定します。

| 表示名 | 条件 | Asset名 |
|---|---:|---|
| ふつかの便り | 2日 | `BadgeFeedbackStreak2` |
| 三日つづり | 3日 | `BadgeFeedbackStreak3` |
| 五日つづり | 5日 | `BadgeFeedbackStreak5` |
| ことばの一週間 | 7日 | `BadgeFeedbackStreak7` |
| 十日つづり | 10日 | `BadgeFeedbackStreak10` |
| 二週間の便り | 14日 | `BadgeFeedbackStreak14` |
| 三週間の便り | 21日 | `BadgeFeedbackStreak21` |
| ことばのひと月 | 30日 | `BadgeFeedbackStreak30` |
| ことばのふた月 | 60日 | `BadgeFeedbackStreak60` |
| 百日つづり | 100日 | `BadgeFeedbackStreak100` |

## 感想を届けた作品数（8種）

| 表示名 | 条件 | Asset名 |
|---|---:|---|
| ふたつの出会い | 2作品 | `BadgeUniqueProjects2` |
| みっつの出会い | 3作品 | `BadgeUniqueProjects3` |
| 五つの物語 | 5作品 | `BadgeUniqueProjects5` |
| 十の作品めぐり | 10作品 | `BadgeUniqueProjects10` |
| 作品さんぽ | 20作品 | `BadgeUniqueProjects20` |
| 作品めぐりの達人 | 30作品 | `BadgeUniqueProjects30` |
| 五十の出会い | 50作品 | `BadgeUniqueProjects50` |
| 百の作品めぐり | 100作品 | `BadgeUniqueProjects100` |

## 感想箱を作った数（6種）

| 表示名 | 条件 | Asset名 |
|---|---:|---|
| はじめての感想箱 | 1個 | `BadgeFirstProject` |
| みっつの感想箱 | 3個 | `BadgeProjects3` |
| 五つの感想箱 | 5個 | `BadgeProjects5` |
| 十の感想箱 | 10個 | `BadgeProjects10` |
| 感想箱の街 | 20個 | `BadgeProjects20` |
| 感想箱の王国 | 30個 | `BadgeProjects30` |

## いいねを届けた数（6種）

| 表示名 | 条件 | Asset名 |
|---|---:|---|
| はじめての共感 | 1件 | `BadgeFirstLike` |
| 共感の芽 | 5件 | `BadgeLikesGiven5` |
| 共感の花束 | 10件 | `BadgeLikesGiven10` |
| やさしい共感 | 25件 | `BadgeLikesGiven25` |
| 共感の輪 | 50件 | `BadgeLikesGiven50` |
| 百の共感 | 100件 | `BadgeLikesGiven100` |

## 自分の感想がいいねされた数（6種）

| 表示名 | 条件 | Asset名 |
|---|---:|---|
| はじめて届いた共感 | 1件 | `BadgeLikesReceived1` |
| 共感が咲いた | 5件 | `BadgeLikesReceived5` |
| 十の共感 | 10件 | `BadgeLikesReceived10` |
| 共感の花畑 | 25件 | `BadgeLikesReceived25` |
| 共感のきらめき | 50件 | `BadgeLikesReceived50` |
| 百の共感を受けて | 100件 | `BadgeLikesReceived100` |

## 作者から❤️をもらった数（6種）

| 表示名 | 条件 | Asset名 |
|---|---:|---|
| 作者に届いた！ | 1件 | `BadgeCreatorHeart` |
| 作者に三度届いた | 3件 | `BadgeCreatorHearts3` |
| 作者の五つのハート | 5件 | `BadgeCreatorHearts5` |
| 作者に十度届いた | 10件 | `BadgeCreatorHearts10` |
| 作者とのことばの輪 | 25件 | `BadgeCreatorHearts25` |
| 作者に五十度届いた | 50件 | `BadgeCreatorHearts50` |

## ログイン継続（2種）

| 表示名 | 条件 | Asset名 |
|---|---:|---|
| Pocoな一週間 | 7日 | `BadgeSevenDayStreak` |
| Pocoな一か月 | 30日 | `BadgeThirtyDayLoginStreak` |

## 通知

新規解除時に通知タブの「達成スタンプ」へ1件だけ追加します。同じスタンプでは
再通知されません。通知を押すと既読になり、スタンプ画像・名称・達成条件は
マイページの「達成スタンプ」で確認できます。
