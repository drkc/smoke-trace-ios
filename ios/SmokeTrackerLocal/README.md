# SmokeTrackerLocal (iOS Offline)

纯 iPhone 端离线版 Smoke Tracker（M2 进行中）。

## 当前状态
- [x] SwiftUI + SwiftData 工程骨架
- [x] Home 一键记录
- [x] 今日计数 / 距上一根
- [x] 补记（时间/触发/备注/延迟标记）
- [x] 撤销最新记录
- [x] 标记“先拖10分钟”
- [x] 历史（日/周/月切换、摘要、趋势、触发分布、明细）
- [x] 历史摘要补齐（区间日均、较上区间对比、上一区间总数）
- [x] Worker 风格即时提示（本地 TipPool）
- [x] 设置（导入 Worker JSON、导出 JSON/CSV、清空数据）
- [ ] 本地锁（PIN/FaceID）
- [ ] 更完整图表（热力图）

## 目录
- `App/` 入口与 Root
- `Domain/Models/` SwiftData 模型
- `Domain/Services/` 记录写入与统计服务
- `Domain/ImportExport/` Worker 导出导入与本地导出
- `Features/Home/` 首页主流程
- `Features/History/` 历史聚合与图表
- `Features/Settings/` 导入导出与清空

## Worker 导出导入支持（新增）
支持直接导入现有 Worker 端 `GET /api/export?format=json` 生成的 JSON 文件。

当前导入规则：
- 识别顶层结构：
  - `exported_at`
  - `timezone`
  - `logs[]`
- 识别日志字段：
  - `id`
  - `created_at`
  - `trigger_primary`
  - `trigger_secondary`
  - `delayed_10min`
  - `minutes_since_last`
  - `count_in_day`
  - `is_backfill`
- 去重策略：按 `id` 去重（已存在则跳过）
- 导入后：全量重算 `minutesSinceLast` 与 `countInDay`，并优先使用源 JSON 的 `timezone` 进行按天计数重算
- 导入完成后显示“对账报告”：
  - 总数（源数据 / 本地导入前后）
  - 重复与非法触发跳过数
  - 源数据时间范围
  - 按触发类型的源数量 / 导入新增 / 本地净增

## 生成工程
本目录使用 XcodeGen 管理 `project.yml`。

```bash
cd ios/SmokeTrackerLocal
xcodegen generate
open SmokeTrackerLocal.xcodeproj
```

若未安装 xcodegen（macOS）：
```bash
brew install xcodegen
```

## GitHub Actions（无本地 Mac 场景）
已提供 CI 工作流：
- `.github/workflows/ios-smoketracker-build.yml`

流程（unsigned-only）：
1. macOS runner 安装 xcodegen
2. 生成 xcodeproj
3. Simulator 编译（Debug）
4. iPhoneOS Release 编译（禁用签名）
5. 打包 `SmokeTrackerLocal-unsigned.ipa`
6. 上传 artifacts（仅 unsigned ipa）

说明：
- 当前工作流已固定为“不处理证书/描述文件/签名导出”。
- 产物为未签名 IPA，需要你后续用轻松签或其它工具重签后安装。

## 运行要求
- Xcode 15+
- iOS 17+
- 设备：iPhone（竖屏）

## 离线说明
- 当前实现无网络请求依赖。
- 数据存储于本机 SwiftData。
