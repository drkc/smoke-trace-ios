import WidgetKit
import SwiftUI
import AppIntents

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
        WidgetQuickRecordStore.enqueue(triggerRawValue: trigger.rawValue)
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
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
    let smallChoices: [TriggerTypeWidgetOption]
    let mediumChoices: [TriggerTypeWidgetOption]
}

struct QuickRecordProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuickRecordEntry {
        QuickRecordEntry(
            date: .now,
            pendingCount: 0,
            smallChoices: WidgetQuickRecordStore.defaultSmall.map { TriggerTypeWidgetOption.from(rawValue: $0) },
            mediumChoices: WidgetQuickRecordStore.defaultMedium.map { TriggerTypeWidgetOption.from(rawValue: $0) }
        )
    }

    func snapshot(for configuration: QuickRecordWidgetIntent, in context: Context) async -> QuickRecordEntry {
        buildEntry()
    }

    func timeline(for configuration: QuickRecordWidgetIntent, in context: Context) async -> Timeline<QuickRecordEntry> {
        let entry = buildEntry()
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(300)))
    }

    private func buildEntry() -> QuickRecordEntry {
        let prefs = WidgetQuickRecordStore.loadPreferences()
        return QuickRecordEntry(
            date: .now,
            pendingCount: WidgetQuickRecordStore.pendingCount(),
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
