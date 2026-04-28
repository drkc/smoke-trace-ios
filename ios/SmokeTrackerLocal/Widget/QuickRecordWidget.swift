import WidgetKit
import SwiftUI
import AppIntents
import SwiftData

private let quickRecordWidgetKind = "QuickRecordWidget"

struct QuickRecordWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "快速记录"
    static var description = IntentDescription("桌面快速记录，可在设置里自定义按钮触发原因")
}

struct QuickRecordActionIntent: AppIntent {
    static var title: LocalizedStringResource = "快速记录"

    @Parameter(title: "触发类型")
    var trigger: TriggerTypeWidgetOption

    init() {
        self.trigger = .idleTime
    }

    init(trigger: TriggerTypeWidgetOption) {
        self.trigger = trigger
    }

    func perform() async throws -> some IntentResult {
        let eventTime = Date()
        let wrote = QuickRecordPersistence.writeDirect(triggerRawValue: trigger.rawValue, createdAt: eventTime)
        if !wrote {
            WidgetQuickRecordStore.enqueue(triggerRawValue: trigger.rawValue, createdAt: eventTime)
        }
        WidgetQuickRecordStore.saveLatestActionFeedback(
            triggerRawValue: trigger.rawValue,
            createdAt: eventTime,
            isDirectWrite: wrote
        )
        WidgetCenter.shared.reloadTimelines(ofKind: quickRecordWidgetKind)
        return .result()
    }
}

enum TriggerTypeWidgetOption: String, AppEnum, CaseIterable {
    case afterWaking = "after_waking"
    case idleTime = "idle_time"
    case afterMeal = "after_meal"
    case stress = "stress"
    case social = "social"
    case driving = "driving"
    case workTransition = "work_transition"
    case other = "other"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "触发类型")

    static var caseDisplayRepresentations: [TriggerTypeWidgetOption: DisplayRepresentation] = [
        .afterWaking: "起床后",
        .idleTime: "空档",
        .afterMeal: "饭后",
        .stress: "压力",
        .social: "社交",
        .driving: "开车",
        .workTransition: "工作间隙",
        .other: "其他"
    ]

    var zhLabel: String {
        switch self {
        case .afterWaking: return "起床后"
        case .idleTime: return "空档"
        case .afterMeal: return "饭后"
        case .stress: return "压力"
        case .social: return "社交"
        case .driving: return "开车"
        case .workTransition: return "工作间隙"
        case .other: return "其他"
        }
    }

    static func from(rawValue: String) -> TriggerTypeWidgetOption {
        TriggerTypeWidgetOption(rawValue: rawValue) ?? .idleTime
    }
}

struct QuickRecordWidgetView: View {
    let entry: QuickRecordEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .systemMedium {
                mediumContent
            } else {
                smallContent
            }
        }
        .padding()
        .containerBackground(.fill.secondary.opacity(0.12), for: .widget)
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("快速记录")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(entry.smallChoices, id: \.self) { choice in
                    Button(intent: QuickRecordActionIntent(trigger: choice)) {
                        HStack {
                            Text(choice.zhLabel)
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let latest = entry.latestActionFeedback {
                Text(latest.message)
                    .font(.caption2)
                    .foregroundStyle(latest.isDirectWrite ? .green : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if entry.pendingCount > 0 {
                Text("待入库：\(entry.pendingCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快速记录")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(entry.mediumChoices, id: \.self) { choice in
                    Button(intent: QuickRecordActionIntent(trigger: choice)) {
                        Text(choice.zhLabel)
                            .font(.caption2)
                            .lineLimit(2)
                            .minimumScaleFactor(0.5)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let latest = entry.latestActionFeedback {
                Text(latest.message)
                    .font(.caption2)
                    .foregroundStyle(latest.isDirectWrite ? .green : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if entry.pendingCount > 0 {
                Text("待入库：\(entry.pendingCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct QuickRecordEntry: TimelineEntry {
    let date: Date
    let pendingCount: Int
    let latestActionFeedback: WidgetQuickRecordActionFeedback?
    let smallChoices: [TriggerTypeWidgetOption]
    let mediumChoices: [TriggerTypeWidgetOption]
}

struct QuickRecordProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuickRecordEntry {
        QuickRecordEntry(
            date: .now,
            pendingCount: 0,
            latestActionFeedback: nil,
            smallChoices: WidgetQuickRecordStore.defaultSmall.map { TriggerTypeWidgetOption.from(rawValue: $0) },
            mediumChoices: WidgetQuickRecordStore.defaultMedium.map { TriggerTypeWidgetOption.from(rawValue: $0) }
        )
    }

    func snapshot(for configuration: QuickRecordWidgetIntent, in context: Context) async -> QuickRecordEntry {
        buildEntry()
    }

    func timeline(for configuration: QuickRecordWidgetIntent, in context: Context) async -> Timeline<QuickRecordEntry> {
        let now = Date()
        let entry = buildEntry(now: now)
        let nextRefresh: Date
        if entry.latestActionFeedback != nil {
            nextRefresh = now.addingTimeInterval(10)
        } else {
            nextRefresh = now.addingTimeInterval(300)
        }
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func buildEntry(now: Date = .now) -> QuickRecordEntry {
        let prefs = WidgetQuickRecordStore.loadPreferences()
        return QuickRecordEntry(
            date: now,
            pendingCount: WidgetQuickRecordStore.pendingCount(),
            latestActionFeedback: WidgetQuickRecordStore.loadLatestActionFeedback(now: now),
            smallChoices: prefs.small.map { TriggerTypeWidgetOption.from(rawValue: $0) },
            mediumChoices: prefs.medium.map { TriggerTypeWidgetOption.from(rawValue: $0) }
        )
    }
}

struct QuickRecordWidget: Widget {
    let kind: String = quickRecordWidgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: QuickRecordWidgetIntent.self, provider: QuickRecordProvider()) { entry in
            QuickRecordWidgetView(entry: entry)
        }
        .configurationDisplayName("快速记录")
        .description("小号 2 按钮 / 中号 4 按钮，可在 App 设置中自定义")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private let smokingDashboardWidgetKind = "SmokingDashboardWidget"

struct SmokingDashboardEntry: TimelineEntry {
    let date: Date
    let weekNumber: Int
    let dayNumber: Int
    let sinceLastText: String
    let smokedCount: Int
    let goalUpperLimit: Int
}

struct SmokingDashboardProvider: TimelineProvider {
    func placeholder(in context: Context) -> SmokingDashboardEntry {
        SmokingDashboardEntry(
            date: .now,
            weekNumber: 1,
            dayNumber: 1,
            sinceLastText: "1h20m",
            smokedCount: 3,
            goalUpperLimit: 14
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SmokingDashboardEntry) -> Void) {
        completion(buildEntry(now: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SmokingDashboardEntry>) -> Void) {
        let now = Date()
        let entry = buildEntry(now: now)
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60))))
    }

    private func buildEntry(now: Date) -> SmokingDashboardEntry {
        let context = ModelContext(SharedModelContainerFactory.shared)
        let setting = AppSetting.fetchOrCreate(in: context)
        let timeZone = TimeZone(identifier: setting.timezoneIdentifier) ?? .current

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let logs = (try? context.fetch(FetchDescriptor<SmokeLog>())) ?? []
        let todayCount = StatsService.countInDay(for: now, logs: logs, timeZone: timeZone)
        let latest = logs.max(by: { $0.createdAt < $1.createdAt })
        let sinceText = formatDuration(StatsService.minutesFromNow(to: latest?.createdAt, now: now))

        let startDate = setting.cessationPlanStartDate ?? now
        let goal = CessationGoalResolver(timeZone: timeZone).resolveGoal(for: now, planStartDate: startDate)
        let dayNumber = max(1, (calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: now)).day ?? 0) + 1)

        return SmokingDashboardEntry(
            date: now,
            weekNumber: goal.weekNumber,
            dayNumber: dayNumber,
            sinceLastText: sinceText,
            smokedCount: todayCount,
            goalUpperLimit: goal.maxSmokedCount
        )
    }

    private func formatDuration(_ minutes: Int?) -> String {
        guard let minutes else { return "-" }
        if minutes <= 0 { return "刚刚" }
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 { return "\(h)h" }
        return "\(h)h\(m)m"
    }
}

struct SmokingDashboardWidgetView: View {
    let entry: SmokingDashboardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("第\(entry.weekNumber)周", systemImage: "calendar.badge.clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text("Day \(entry.dayNumber)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                statTile(icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", title: "距上一根", value: entry.sinceLastText)
                statTile(icon: "flame.fill", title: "今日已抽", value: "\(entry.smokedCount)")
            }

            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.caption)
                    .foregroundStyle(.teal)
                Text("目标上限")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.goalUpperLimit == 0 ? "Quit Day" : "≤\(entry.goalUpperLimit)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(entry.goalUpperLimit == 0 ? .green : .primary)
            }
        }
        .padding(12)
        .containerBackground(
            LinearGradient(
                colors: [Color(.secondarySystemBackground), Color(.tertiarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            for: .widget
        )
    }

    @ViewBuilder
    private func statTile(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct SmokingDashboardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: smokingDashboardWidgetKind, provider: SmokingDashboardProvider()) { entry in
            SmokingDashboardWidgetView(entry: entry)
        }
        .configurationDisplayName("戒烟进度看板")
        .description("2×2 看板：周次、天数、距上一根、今日已抽与目标上限")
        .supportedFamilies([.systemSmall])
    }
}
