import Foundation

enum MockData {
    static let forestCreator = Creator(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
        name: "もりのなかまたち",
        avatarName: nil
    )
    static let tetraCreator = Creator(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
        name: "Tetra Games",
        avatarName: nil
    )
    static let hoshikoCreator = Creator(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
        name: "Hoshiko",
        avatarName: nil
    )

    static let forestProject = Project(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
        title: "絵本「森のこえ」",
        creator: forestCreator,
        category: .book,
        description: "やさしい気持ちになれる、森の小さな仲間たちの物語。絵本を届けたい。",
        imageName: nil,
        feedbackCount: 1_234,
        createdAt: Date(timeIntervalSince1970: 1_750_000_000)
    )
    static let tetraProject = Project(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
        title: "ゲーム「テトラの冒険」",
        creator: tetraCreator,
        category: .game,
        description: "ドット絵の世界で冒険する、心あたたまるインディーRPGです。",
        imageName: nil,
        feedbackCount: 2_891,
        createdAt: Date(timeIntervalSince1970: 1_749_000_000)
    )
    static let starProject = Project(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!,
        title: "マンガ「星の子」",
        creator: hoshikoCreator,
        category: .manga,
        description: "心にそっとよりそう物語を描いています。",
        imageName: nil,
        feedbackCount: 987,
        createdAt: Date(timeIntervalSince1970: 1_748_000_000)
    )

    static let projects = [forestProject, tetraProject, starProject]

    static let feedbacks: [Feedback] = {
        let baseMessages = [
            "心があたたかくなったよ", "イラストが本当にきれい！", "子どもと一緒に何度も読みたい絵本です",
            "最後のページでうるっときました", "森の音が聞こえてきそうでした", "やさしい世界につつまれました",
            "素敵な物語をありがとう！", "寝る前に読むのが楽しみです", "色づかいがとても好き",
            "大切な人にも贈りたいです", "小さな動物たちがかわいい", "何度読んでも新しい発見があります",
            "冒険がとにかく楽しい！", "音楽までずっと聴いていたい", "ドット絵の世界が大好き",
            "キャラクター全員に愛着がわきました", "続きの旅も楽しみにしています", "ラストバトルに感動しました",
            "星の子の表情が忘れられません", "次のお話も待っています", "静かな余韻が心地よかった",
            "自分のことを肯定してもらえた気がします", "友だちにもすすめました", "創ってくれてありがとう"
        ]
        let messages = (0..<100).map { baseMessages[$0 % 12] } + Array(baseMessages.dropFirst(12))
        let nicknames = ["はな", "rena", "パパくま", "さくら", "みどり", "そらのひつじ", "ちい", "ゆき"]
        let projectIDs = Array(repeating: forestProject.id, count: 100)
            + Array(repeating: tetraProject.id, count: 6)
            + Array(repeating: starProject.id, count: 6)

        return messages.enumerated().map { index, message in
            Feedback(
                id: UUID(uuidString: String(format: "30000000-0000-0000-0000-%012d", index + 1))!,
                projectID: projectIDs[index],
                message: message,
                nickname: nicknames[index % nicknames.count],
                isPublic: true,
                createdAt: Date(timeIntervalSinceNow: TimeInterval(-index * 3_700)),
                likes: (index * 7 + 3) % 48,
                bubbleColor: BubbleColor.allCases[index % BubbleColor.allCases.count]
            )
        }
    }()
}
