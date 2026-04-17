import WidgetKit
import SwiftUI
import AppIntents

private let quickRecordWidgetKind = "QuickRecordWidget"

struct QuickRecordWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "快速记录"
    static var description = IntentDescription("从桌面快速记录一根烟")
    static var openAppWhenRun = true

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

enum TriggerTypeWidgetOption: String, AppEnum {
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
}

struct QuickRecordWidgetView: View {
    let entry: QuickRecordEntry

    var body: some View {
        ZStack {
            Button(intent: QuickRecordWidgetIntent(trigger: entry.trigger)) {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.orange)

                    Text("快速记录")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("触发：\(entry.trigger.zhLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if entry.pendingCount > 0 {
                        Text("待入库：\(entry.pendingCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .containerBackground(.fill.secondary.opacity(0.12), for: .widget)
    }
}

struct QuickRecordEntry: TimelineEntry {
    let date: Date
    let pendingCount: Int
    let trigger: TriggerTypeWidgetOption
}

struct QuickRecordProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuickRecordEntry {
        QuickRecordEntry(date: .now, pendingCount: 0, trigger: .idleTime)
    }

    func snapshot(for configuration: QuickRecordWidgetIntent, in context: Context) async -> QuickRecordEntry {
        QuickRecordEntry(
            date: .now,
            pendingCount: WidgetQuickRecordStore.pendingCount(),
            trigger: configuration.trigger
        )
    }

    func timeline(for configuration: QuickRecordWidgetIntent, in context: Context) async -> Timeline<QuickRecordEntry> {
        let entry = QuickRecordEntry(
            date: .now,
            pendingCount: WidgetQuickRecordStore.pendingCount(),
            trigger: configuration.trigger
        )
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(300)))
    }
}

struct QuickRecordWidget: Widget {
    let kind: String = quickRecordWidgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: QuickRecordWidgetIntent.self, provider: QuickRecordProvider()) { entry in
            QuickRecordWidgetView(entry: entry)
        }
        .configurationDisplayName("快速记录")
        .description("桌面一键记一根，可在添加组件时指定默认触发")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
