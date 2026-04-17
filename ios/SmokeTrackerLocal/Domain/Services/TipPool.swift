import Foundation

struct TipPool {
    private static let shortIntervalMinutes = 15
    private static let highCountThreshold = 10

    private static let globalFallback = [
        "先把这一根记下来，别急着顺着下一根走。",
        "先停一下，再决定下一根。",
        "这一下先放慢一点就够了。"
    ]

    private static let triggerTips: [TriggerPrimary: [String: [String]]] = [
        .afterWaking: [
            "default": [
                "起床后这根最固定，先别让动作太顺。",
                "这根多半是习惯先到了，不一定是非抽不可。",
                "先让人醒一醒，不急着让烟跟上。"
            ],
            "short_interval": [
                "这根离上一根太近了，先别连着接。",
                "起床后节奏容易快，这一下更适合缓一缓。"
            ],
            "high_count": [
                "今天已经不少了，起床后这类固定烟更该卡一下。",
                "今天量已经上来了，这根更适合慢一点。"
            ],
            "delayed_success": [
                "起床后还能先拖一下，这一步很值。",
                "这次不是醒来就点，已经有区别了。"
            ],
            "pace_higher": [
                "到现在比昨天快一点，这根更适合停一下。",
                "今天到这会儿比昨天紧，这一下更值得放慢。"
            ]
        ],
        .idleTime: [
            "default": [
                "空档一来就想抽，很常见，先别接太快。",
                "先换个小动作，不急着再来一根。",
                "这类烟最容易顺手，先停一下。"
            ],
            "short_interval": [
                "这根离上一根有点近，先缓一下。",
                "这一下更适合拉开点间隔。"
            ],
            "high_count": [
                "今天已经不少了，这类顺手烟更值得卡一下。",
                "今天重点不是多一根，是慢一点。"
            ],
            "delayed_success": [
                "这次你已经多拖了一步。",
                "这次不是顺手就抽，已经有区别了。"
            ],
            "pace_higher": [
                "到现在比昨天快一点，这根更适合停一停。",
                "今天到这会儿偏快，这一下更值得放慢。"
            ]
        ],
        .afterMeal: [
            "default": [
                "饭后想抽很常见，但这一根最像惯性。",
                "先别让饭后自动接上烟。",
                "先换个收尾动作，不急着来这根。"
            ],
            "short_interval": [
                "这根离上一根有点近，饭后也不必立刻补。",
                "刚抽过又来这一根，先缓一下更值。"
            ],
            "high_count": [
                "今天已经不少了，饭后这类惯性烟更值得卡一下。",
                "今天总量不低，先别让流程自动接烟。"
            ],
            "delayed_success": [
                "饭后还能先拖一下，这一步很值。",
                "这次不是饭后立刻抽，已经多了缓冲。"
            ],
            "pace_higher": [
                "到现在比昨天快一点，饭后这一下更值得慢下来。",
                "今天到这会儿偏快，这根更适合停一停。"
            ]
        ],
        .stress: [
            "default": [
                "这根更像想缓一下，不一定非靠烟。",
                "压力在，但下一步不一定只能是抽烟。",
                "先停几秒，别顺着烦躁走。"
            ],
            "short_interval": [
                "烦的时候容易抽得更密，这根先别接太快。",
                "这根离上一根太近了，先给情绪一点空隙。"
            ],
            "high_count": [
                "今天已经不少了，这种压力烟更该慢一点。",
                "今天量已经上来了，这根更值得停一下。"
            ],
            "delayed_success": [
                "压力在的时候还能先拖一下，这很不容易。",
                "这次不是一下被情绪带走，已经很值了。"
            ],
            "pace_higher": [
                "到现在比昨天快一点，这一下更适合放慢。",
                "今天到这会儿偏快，这根更值得停一停。"
            ]
        ],
        .social: [
            "default": [
                "社交场景最容易顺着来，先记这一根。",
                "别人抽，不等于你这根非得跟上。",
                "这类烟多半是气氛带的。"
            ],
            "short_interval": [
                "社交里最容易一根接一根，这次先别跟太快。",
                "场子热，不代表节奏也要这么快。"
            ],
            "high_count": [
                "今天已经不少了，社交这类顺手烟更要收一下。",
                "今天总量不低，这根更值得慢一点。"
            ],
            "delayed_success": [
                "社交场景里还能先拖一下，这一步挺值。",
                "这次不是气氛一来就跟上，已经不一样了。"
            ],
            "pace_higher": [
                "到现在比昨天快一点，这种跟着抽更值得卡一下。",
                "今天到这会儿偏快，先别顺着气氛接。"
            ]
        ],
        .driving: [
            "default": [
                "路上这类烟很容易跟动作绑死，先记这一根。",
                "开车时想抽，多半是场景回路到了。",
                "这类烟更像习惯动作，不一定是真需求。"
            ],
            "short_interval": [
                "路上最容易一根接一根，这次先别接太快。",
                "刚抽完又来这一根，先缓一下更值。"
            ],
            "high_count": [
                "今天已经不少了，路上这类惯性烟更要收住。",
                "今天节奏偏快，这类固定场景更该慢一点。"
            ],
            "delayed_success": [
                "路上这类固定触发你还能先拖一下，这很值。",
                "这次不是动作一到就抽，已经打断了一点。"
            ],
            "pace_higher": [
                "到现在比昨天快一点，路上这根更适合停一下。",
                "今天到这会儿偏快，这一下更值得拉开点间隔。"
            ]
        ],
        .workTransition: [
            "default": [
                "工作切换时最容易顺手抽，先把这一下记下来。",
                "这类烟很多时候是在换挡，不一定是在需要。",
                "工作过渡这一下，先别自动接烟。"
            ],
            "short_interval": [
                "这根离上一根有点近，工作切换也不必这么快接。",
                "工作在换挡，抽烟节奏不必也跟着变快。"
            ],
            "high_count": [
                "今天已经不少了，工作间隙这类烟更该卡一下。",
                "今天节奏偏密，这类过渡烟更值得收一收。"
            ],
            "delayed_success": [
                "工作切换时还能先拖一下，这一步很值。",
                "这次不是一切换就点烟，已经有区别了。"
            ],
            "pace_higher": [
                "到现在比昨天快一点，这种过渡烟更值得停一下。",
                "今天到这会儿偏快，这一下更适合放慢。"
            ]
        ],
        .other: [
            "default": [
                "先把这一根记下来，别急着给它找理由。",
                "这类说不清的烟，先看见它就已经有用了。",
                "不用先定义清楚，先记下来就行。"
            ],
            "short_interval": [
                "这根离上一根有点近，先别顺着再往下走。",
                "先把节奏拉开，再看这一根算什么。"
            ],
            "high_count": [
                "今天已经不少了，这类模糊烟更值得停一下。",
                "今天总量不低，这根更该先放慢。"
            ],
            "delayed_success": [
                "原因说不清也没关系，先拖10分钟已经很值。",
                "这次不是顺手立刻抽，已经比平时多了一步。"
            ],
            "pace_higher": [
                "到现在比昨天快一点，这一下更值得先停一停。",
                "今天到这会儿偏快，这根更适合慢一点。"
            ]
        ]
    ]

    static func nextTip(
        trigger: TriggerPrimary,
        minutesSinceLast: Int?,
        countInDay: Int,
        delayed10min: Bool,
        vsYesterdaySoFar: PaceCompare
    ) -> String {
        let bucket = resolveBucket(
            minutesSinceLast: minutesSinceLast,
            countInDay: countInDay,
            delayed10min: delayed10min,
            vsYesterdaySoFar: vsYesterdaySoFar
        )

        let group = triggerTips[trigger] ?? [:]
        let pool = pickPool(group: group, bucket: bucket)
        return pickDeterministic(pool: pool, seed: deterministicSeed(trigger: trigger, bucket: bucket, countInDay: countInDay))
    }

    private static func resolveBucket(
        minutesSinceLast: Int?,
        countInDay: Int,
        delayed10min: Bool,
        vsYesterdaySoFar: PaceCompare
    ) -> String {
        if delayed10min { return "delayed_success" }
        if let m = minutesSinceLast, m < shortIntervalMinutes { return "short_interval" }
        if vsYesterdaySoFar == .higher { return "pace_higher" }
        if countInDay >= highCountThreshold { return "high_count" }
        return "default"
    }

    private static func pickPool(group: [String: [String]], bucket: String) -> [String] {
        if let arr = group[bucket], !arr.isEmpty { return arr }
        if let arr = group["default"], !arr.isEmpty { return arr }
        return globalFallback
    }

    private static func deterministicSeed(trigger: TriggerPrimary, bucket: String, countInDay: Int) -> Int {
        let str = "\(trigger.rawValue)|\(bucket)|\(countInDay)"
        return str.unicodeScalars.map(\.value).reduce(0) { ($0 &* 131 &+ Int($1)) & 0x7fffffff }
    }

    private static func pickDeterministic(pool: [String], seed: Int) -> String {
        guard !pool.isEmpty else { return globalFallback.first ?? "先停一下，再决定下一根。" }
        let idx = abs(seed) % pool.count
        return pool[idx]
    }
}
