# zhandi3 路线图 · 可验收版 (v2 — 20260901 四维审计增量)

> 与 `docs/ISSUES.md` 同为唯一真实来源。`ISSUES.md` 定义“是什么/为什么”，本文件定义“何时做/做到什么算做完/怎么验证”。
> 基线 `main@a25e2bb` (Godot 4.7 Forward Plus) 叠加 `docs/REVIEW_20260901.md` 四维审计结论。所有验收均以可执行的 `godot --headless` / 探针日志 / 截图为判据。
> **v2 变更**：在既有 4 Phase 上叠加 `AUD-P0/P1` 15 项增量（特效/模型/操作/玩法四维打磨），不推翻既有门禁，仅扩展 Phase 1-3 的任务清单与准出。

## 总览

| Phase | 名称 | 周期 | 核心目标 | 准出门禁 |
|-------|------|------|----------|----------|
| Phase 1 | 阻断（Blocker）+ 热修 Hotfix | 4–6 周 + 1–2d 热修 | 消灭崩溃/悬垂/软锁，叠加手柄可用/跳跃不丢/首刷不卡/表现不穿帮 | §1 门禁 + AUD-P0 全绿 |
| Phase 2 | 体验（Experience）+ 迭代 Iteration | 6–8 周 + 1 周迭代 | 新玩家 5 分钟可自学；HUD/导航/输入/性能达到可玩发行阈值；帧率/手感/留存达标 | §2 门禁 + 帧率 P50≥60 / 1% low≥45 / p95 draw calls≤600 |
| Phase 3 | 内容（Content）+ 打磨 Polish | 8–12 周 + 按需打磨 | 区域化玩法与重复度治理，野图从“演示”升级为“世界”，宣发最后一米 | §3 门禁全绿 |
| Phase 4 | 发行（Ship） | 4–6 周 | 平台交付、合规、商店与定价闭环 | §4 门禁全绿 |

> 人力假设：1–2 人 AI 辅助迭代；每项修复单分支、单项验证、合入后才开下一项；每周至少一次窗口抽检截图。

---

## 全局门禁（所有 Phase 通用）

任一 Phase 宣称完成前必须满足：

1. **零 ERROR 基座**：`--wildtest --ground --arm --seed 7` 与 `--sim --seed 7` 日志零 `ERROR` / `SCRIPT ERROR` / `!is_inside_tree()` / `already has a parent` / `leaked`
2. **三回归锁死**：`--feedtest` / `--focusrecoverytest` / `--seasontest` 均 EXIT:0 且断言通过
3. **帧率基座**（Phase 2 起强制）：Mobile/Low 档 1280×720 固定路线 120s，P50 ≥60 FPS，1% low ≥45 FPS，p95 draw calls ≤600
4. **文档一致**：`README.md` / 启动统计 / `ISSUES.md` / 本文件对同一数量的描述一致（神庙/种子/NPC 等从注册表生成，不手写）
5. **新增（v2）**：固定 `--seed 7` 二次运行结果一致；`--firetest` 伤害-距离表可 grep；夜景截图 `day_light` 曲线可验证

---

## Phase 1 — 阻断 4–6 周 + 热修 1–2d

**目标**：任何玩家在不看 README 的情况下可完整跑通一局 Wild 与一局 Battlefield，且自动化回归零 ERROR；叠加热修后手柄可用、跳跃不丢、首刷不卡。

### 任务清单（既有）

| # | 任务 | 关联 ISSUE | 交付物 | 验收标准（可验证） |
|---|------|------------|--------|-------------------|
| 1.1 | 骑乘死亡对称退出 | P11/D5/R?（P11） | `player.gd:die/respawn` 均 `exit_vehicle()` + 恢复可见/碰撞/相机；四载具 `horse/vehicle/motorcycle/raft` 无残留 driver | 四载具各测：骑乘中死亡→重生后玩家可见、有碰撞、可移动，载具 `driver==null`；`--wildtest` 四段各 1 次 |
| 1.2 | 慢动作/时停泄漏治理 | P12/M12/R1-R3/P18 | `time_scale` 栈化或显式 reset；Stasis/Flurry/hitstop 清理前置于所有 early return；Timer 用真实时间或 ALWAYS | `time_scale==0.22` 期间 Timer 不被拉长至 44s；`die()` 兜底还原；Stasis 不选中 `self`；骑乘/背包/菜单不延长冻结/慢动作 |
| 1.3 | 入树前 `global_position` 与重复挂载 | P1/D2/R? + P2行商 | 统一 `position/home → add_child` 单次挂载；血月路径 home 正确 | `--wildtest --seed 7` 零 `!is_inside_tree()` 且零 `already has a parent`；抽检 WildMonster/Guardian/Fish 生成点误差 <0.01 |
| 1.4 | 游泳/抓鱼/缩胶囊可达性 | P15 | 游泳态仍可 `_scan_loot`/`_scan_interact`；离水恢复胶囊 | 游泳中 E 可抓鱼获 `meat`，`fish_spot` 60s 重生可回归；离水后碰撞高度恢复至设计值 |
| 1.5 | 背包 10 项与 N/B 键位统一 | P13/P14/G3 | `entry_count` 按实际行数；InputMap 语义名统一；HUD/提示/商店一致 | 10 项均可选中/取出/存入；`grep -r "KEY_" scripts/player` 为空；HUD 与 `project.godot` 文案一致 |
| 1.6 | 入树/悬垂/await 守卫收敛 | P2/D1/P8/M16/D9 | `is_instance_valid` 双点守卫；`await` 后 `is_inside_tree()`；Projectile source 弱引用 | `--sim --seed 7` 全场零悬垂；场景卸载时零释放异常 |
| 1.7 | 倒木/守卫桥面 | P9/D10/R? | 倒木碰撞 90°；守卫仅非 `is_on_floor` 回落 | 桥面/平台可通行回归通过；抽检 Guardian/Hinox/Lizalfos 不穿桥 |
| 1.8 | Bot 哑火与超时 | P10/D8/P3/D3/R? | 空匣搜 ammo；LOOT 8s 超时（目标变化才重置，真实 delta） | `--sim` 无永久 LOOT 锁与哑火 Bot；不可达塔顶/城堡武器 8s 后必切目标 |
| 1.9 | 血月类型污染（同类判活） | P4/D6 | 同类才抑制 | 跨类不抑制；`--wildtest` 血月后各类型按预期补齐（Phase 3 补全前仅已注册类型） |
| 1.10 | InputMap 基座 + 存档基座 | C4/C5/G2/R18-19 | `project.godot` InputMap 全量；`user://save_v1.json` 版本化原子写入；`EnvironmentDirector` 占位 | 键位重映射后行为一致；损坏存档回退不崩；Season/DayNight/Weather 不再直写 Environment（Phase 2 完成合成器） |

### 任务清单（v2 热修增量 — AUD-P0）

| # | 任务 | 关联 AUD | 交付物 | 验收标准（可验证） |
|---|------|----------|--------|-------------------|
| 1.11 | 摇杆死区+7 键位冲突修复 | AUD-P0-1 | `project.godot` deadzone 0.18，`move_back Joy13→11` 等 7 处解冲突，新增 `ads`/`fire` 进 InputMap | `grep deadzone` 均 0.18；手柄右摇/扳机可完成 `--wildtest`；`grep -r "KEY_" scripts/player` 仍 0 |
| 1.12 | 载具 InputMap 化 | AUD-P0-2 | `vehicle.gd:354` `horse.gd:475` `wild_motorcycle.gd:330` `raft.gd:214` 改 `get_action_strength` | 重映射后行为一致；手柄左摇可驾驶 20m |
| 1.13 | 跳跃 coyote+buffer | AUD-P0-3 | `player.gd:809` 墙钟 `coyote 0.15 + buffer 0.18` | 探针 100 次楼梯跳成功率 >98% |
| 1.14 | GLB preload 池化 | AUD-P0-4 | `wild_moblin.gd:66` 等 5 处 `preload` + 集中注入 + `call_deferred ≤4/帧` | `[boot_t]` 首刷 -60%；`--wildtest` 零 hitch |
| 1.15 | 描边分级与草/花禁描边 | AUD-P0-5 | `toon.gd:11,17` 角色 0.014/建筑 0.018，草/花/树冠禁 next_pass | `--sim` draw calls 峰值 -30% |
| 1.16 | 弹孔池全量有效性巡检 | AUD-P0-6 | `fx.gd:111` 改 `filter(is_instance_valid)` 全扫 | `--reloadtest` 720 帧零 freed |
| 1.17 | 烟雾/爆炸昼夜与雾一致 | AUD-P0-7 | `smoke_grenade.gd:63` `disable_fog=false + day_light`；`remote_bomb.gd:152` emission 并行衰减 | 夜景烟雾 ≤ 白天 40%；爆炸 0.3s 无黑芯 |
| 1.18 | 水面/闪电/云池化 | AUD-P0-8 | `water.gdshader:49` 64→32 + varying；`weather.gd:271` 静态化；`sky_builder.gd:99` MultiMesh | 水面 1.4ms→0.7ms；云 100→1 draw |
| 1.19 | 落点保底补弹药 | G-P0-3 | `main.gd:583` 追加 `ammo 45` | 空手进圈率 0；`--sim` 首圈人均弹药 ≥40 |

**Phase 1 准出（v2）**：`--wildtest` / `--sim` / `--feedtest` / `--focusrecoverytest` / `--seasontest` 全绿且零 ERROR；窗口抽检着陆/游泳/骑乘/抓鱼/背包各 1 次无显性回退；新增 1.11–1.19 探针全绿（见验证矩阵）。

---

## Phase 2 — 体验 6–8 周 + 迭代 1 周

**目标**：新玩家无需 README，3 分钟内完成“空降→搜刮→交战→跑圈→占点/神庙”基础闭环；HUD 与输入达到可发行阈值；叠加帧率/手感/留存达标。

| # | 任务 | 关联 ISSUE | 交付物 | 验收标准 |
|---|------|------------|--------|----------|
| 2.1 | 首局教学与主目标 | R11/UX A1/fork 起始 | 92m 空降后 3 步教学（视角/滑翔/落点物资）+ 常驻目标卡（神庙/讨伐/据点）+ 日志可重看 | 新玩家走查 5 分钟内可回答“去哪/怎么变强/死了怎么办”；教学可跳过；无教学时不遮挡操作 |
| 2.2 | 小地图/毒圈/据点/神庙导航 | H13/R11/R24/World H5/UX A2 | 小地图画当前/下一安全圈、据点、方向/距离；罗盘/离屏标记；神庙先解释后计时 | 小地图与 `zone` 同源坐标；据点/神庙远距可规划路线；圈总时长 220–260s，决赛圈 DPS 20 |
| 2.3 | HUD 响应式与信息分层 | H10/H11/H12/R?/UX A3-A5 | 响应式锚点 + 滚动/分页；红晕对称；世界状态不裁切；背包后项可见 | 1280×720/1920×1080/16:10/21:9 均无溢出/重叠/屏外；背包选中项自动滚动可见 |
| 2.4 | 交互提示完整性 | R13/UX fork | 宝箱/水晶/鱼/床等与扫描一致的 HUD 提示 | 每类可交互物靠近必有提示且与 `player.gd:869-909` 扫描一致 |
| 2.5 | 输入与舒适设置产品化 | C4/R18/H?/UX S1/S2/A6/A9 | InputMap 唯一入口 + `InputRouter`；灵敏度/FOV/反转Y/HUD缩放/音量分轨/暂停菜单/手柄 | `T/V` 等冲突为 0；手柄右摇/扳机/菜单焦点可用；设置持久化 |
| 2.6 | 战斗反馈与命中分级 | R6/UX A4-A5/Combat M7-M8 | 换弹动画/声/进度/空仓；命中四态/受击方向/拾取 toast；`damage_mult` 统一 DamageContext | 换弹期有进度且非“失灵”；剑/弓同享 `all_damage_mult`；弹药总量单次增加且人机同接口 |
| 2.7 | AI/Player/天气 性能分帧 | H7/H9/M8/M17/R?/Perf 6 | 视锥+距离 LOD + 射线预算；组扫描限频/分区；雨雪 GPU/批更新 | `--sim --seed 7` 60fps 下射线/帧有上限；headless CPU p95 <10ms；区服帧时不随总数平方增长 |
| 2.8 | 成长与经济预算审计 | H19/H20/M1/M2/M15 | 种子/鱼/商店预算与封顶；医疗以 `max_hp` 为钳制；载具成本/解锁 | 长测经济曲线不发散；获宝珠后满血为新上限；载具不再无成本压缩尺度 |
| 2.9 | 环境合成器 | M4/R19/World H1 | `EnvironmentDirector` 唯一合成 Season×DayNight×Weather | 季节基色×昼夜×天气一次计算；互覆盖回归为 0；四季探针一致 |

### 任务清单（v2 迭代增量 — AUD-P1）

| # | 任务 | 关联 AUD | 交付物 | 验收标准 |
|---|------|----------|--------|----------|
| 2.10 | 地形 LOD + 四象限视距 | AUD-P1-1 | `terrain.gd:8,213` GRID 96 + `visibility_range` | 低端核显 30fps 达标；`--sim` p95 draw≤600 |
| 2.11 | 建筑共享 Mesh + 视距 | AUD-P1-2 | `buildings.gd:159` shared_box 单例 + 120/250m | draw calls -15% |
| 2.12 | 移动/射击曲线可学习化 | AUD-P1-3 | `ACCEL 20+friction18 / bloom 0.09/0.65/6.5 + 固定弹道` | 压枪可练；TTK 拉开 15%（`--firetest` 表） |
| 2.13 | GPU 粒子池（血/烟/火花） | AUD-P1-4 | `GPUParticles3D` 32/64 三套 + MultiMesh 池 | SMG 13发/s 零 new Material |
| 2.14 | 局外天赋三选一 | AUD-P1-5 | `main.gd:37,61` `total_kills→天赋点` 写入 `save_v1` | 重载天赋生效；二周目可测增强 |
| 2.15 | 投放种子化（地标抖动） | AUD-P1-6 | `buildings.gd:42` `wild_world.gd:713` `hash(seed) ±6m` | `--seed 7 vs 13` 布局不一致 |
| 2.16 | 雨雪生存化 | AUD-P1-7 | `weather.gd:133` 雨 `移速×0.92 攀爬×1.25` | 湿时攀爬/移动探针达标 |

**Phase 2 准出**：新玩家走查通过 + HUD 响应式截图回归 + Mobile/Low 帧率门禁 + 输入/手柄可完成一局；新增 2.10–2.16 KPI 全绿。

---

## Phase 3 — 内容 8–12 周 + 打磨按需

**目标**：治理重复度，建立区域化玩法与可复用内容管线，野图从“演示”升级为“世界”；叠加宣发最后一米。

| # | 任务 | 关联 ISSUE | 交付物 | 验收标准 |
|---|------|------------|--------|----------|
| 3.1 | 统一 Biome/Content Mask 与占地保留 | R7/R8/World S2-S3/Perf 3 | `BiomeQuery` + `WorldLayout` 占地（道路/POI/视线/谜题）先于植被 | POI 门前/路中线净空可验证；雪区雨雪一致；地表/树种/资源/天气/音效同源 |
| 3.2 | 神庙分层与区域绑定 | M3/R9/World S4 | 4 庙各 2–3 步递进，机制与地区绑定，内部空间/奖励差异化 | 完成一庙后不可预测下一庙；每庙至少 1 个需组合移动（攀/滑/筏/制冰/磁力）的谜题 |
| 3.3 | 探索解谜体系升级（原“探索解谜”去商标化） | R29/World H4 | 搬运/轨迹/计时/风向/攀滑组合；每语法三级难度 | 新增谜题不为“靠近/一次伤害”同质；抽检 3 种语法各 1 题 |
| 3.4 | 血月全量类型与刷新注册表 | P5/D7/R5/R17/World H?/Combat S5 | `EnemySpawnSpec` 注册表驱动生成与血月；Stal/Keese/Wizzrobe/Chuchu/Hinox/Flyer/Dragon 补齐 | 血月后全类型按 `spawn_id` 可验证补齐；类型用 `id` 而非 basename |
| 3.5 | 怪物/投射物/掉落 工厂化 | R16/R17/Arch H3-H4 | `Health/Drop/Target/Presenter` + `EnemyDefinition/Factory` + `DropTable`；投射物按阵营 mask | 新增一怪 ≤1 新脚本 +1 注册行；弹反切阵营后可命中施法者 |
| 3.6 | 世界分区与 LOD/HLOD | Perf 3-5/M14/R? | 20–40m chunk；静态网格合并；距离可见/阴影分级；水/草分块 | 远区碰撞/实例按距休眠；p95 draw calls ≤600；冷启动到可操作 ≤4s |
| 3.7 | 遭遇与营地原型化 | World M1 | 河岸/雪地/火山/遗迹营地原型分化 | 同一营地不再复用同一结构/守军/奖励 |

### 任务清单（v2 打磨增量）

| # | 任务 | 关联 AUD | 交付物 | 验收标准 |
|---|------|----------|--------|----------|
| 3.8 | 云 MultiMesh + 水面 shader 瘦身收口 | AUD-P0-8/P2 | 云 1 draw；水面 varying 化 | 视觉抽检 + 帧率门禁 |
| 3.9 | 据点雷达/弹药补给 | 玩法 P1 | 占点给 `雷达 5s 脉冲` 或 `弹药` | 探针：占点后 40m 内敌高亮 5s |
| 3.10 | 任务二段与 Stinger 采样 | 特效/玩法 P2 | 护送后追击线；`hinox_down/boss_victory` 专用采样 | 探针 `[stinger]` 日志 + 听感区分 |
| 3.11 | `*.import` 分级与 PBR/Toon 收敛 | 模型 P1 | billboard 关切线/烘焙；`WildMonster` 复用骨架 | 显存 -15%；同屏风格一致 |

**Phase 3 准出**：固定种子下区域重访有差异化决策；新增内容不增加人均 headless ERROR；性能门禁仍绿；视觉抽检通过。

---

## Phase 4 — 发行 4–6 周

**目标**：达到可上架交付的技术与合规基线。

| # | 任务 | 关联 ISSUE | 交付物 | 验收标准 |
|---|------|------------|--------|----------|
| 4.1 | 导出与画质档 | C3/Perf 2 | `export_presets.cfg`（PC/Mac/Web 至少 2 目标）+ Low/Med/High 档 | `godot --headless --export-release` 可产出；Low 档 Mobile 无 MSAA/Glow 阴影 80–100m |
| 4.2 | 输入/本地化/无障碍 | C4/H22/L?/R18 | InputMap/重映射/手柄全量；本地化表；对比度/字号/音量分轨；色盲/轮廓 | 全量玩法可用手柄通关；中英至少 1 额外语言；无障碍 checklist 通过 |
| 4.3 | IP 原创化与商店页 | C6/C7 | 文案/地名原创化；商店胶囊/视频/描述 | 合规自检清单通过；外部 IP 零直用 |
| 4.4 | 审计与合规 | L3/C3 | LICENSE/NOTICE、隐私/EULA、分级、启动统计 | 文档与运行时数量一致；法务清单通过 |
| 4.5 | 定价与复玩 | C7/G? | 二周目/难度/随机池或联机方案二选一；定价策略 | 若单机则二周目增量可验证；若联机则网络/反作弊边界明确 |
| 4.5a | 单机复玩（C7占位） | C7 | README `合规与启动统计` + `scripts/main.gd:1-5` 单机离线定位；`--seed` 随机池；二周目难度增量说明 | ` --seed 7` 与 `--seed 13` 布局可复现差异；`--wildtest` 种子池可验证；二周目增量由种子池+成长解锁共同承载，头显可验证 |

> **单机复玩：--seed 随机池 + 二周目难度增量（C7）**：本作为单机离线体验（见 `scripts/main.gd:1-5`），无联机依赖。复玩靠 `--seed N` 随机池验证——同一版本固定种子可复现出生点/物资/天气/任务序列，换种即新局；二周目难度增量由种子池与成长解锁共同承载（不同种子布局差异 + 已解锁成长/强度可验证增量）。

**Phase 4 准出**：三平台产出物 + 合规文档 + 商店页 + 定价与复玩说明齐套。

---

## 优先级总表（S→M，去重后 Top 15 + AUD Top 15）

### 既有 Top 15

| rank | 项 | 归属 | 验收锚点 |
|------|----|------|----------|
| 1 | 骑乘死亡未 exit | P11/D5 | 1.1 |
| 2 | 慢动作/时停泄漏与 Timer 拉长 | P12/M12/R1-R3 | 1.2 |
| 3 | 入树前 global_position 剩余 | P1/D2 | 1.3 |
| 4 | 游泳/缩胶囊/抓鱼不可达 | P15 | 1.4 |
| 5 | 背包 10 项与 N/B 统一 | P13-14 | 1.5 |
| 6 | 首局教学与主目标 | R11 | 2.1 |
| 7 | 小地图/毒圈导航 | R11/R24/World H5 | 2.2 |
| 8 | 神庙启停与出口 | R12 | 2.2/2.4 |
| 9 | 精力药/盾滑/大 delta | P16-18/R6 | 1.2/2.8 |
| 10 | InputMap/手柄 + 存档基座 | C4/C5 | 1.10 |
| 11 | 胜负终态与阔野死亡契约 | R1-R2 | 1.2/2.2 |
| 12 | 猎弓单链与双扣 | R4 | 2.6 |
| 13 | PvE 阵营与投射物 mask | R5/R30 | 3.5 |
| 14 | HUD 响应式与战斗反馈 | H10-H13/R13 | 2.3/2.6 |
| 15 | AI/物理主线程分帧 | H7/H9 | 2.7 |

### AUD Top 15（20260901 四维审计增量）

| rank | ID | 一句话 | 归属 | 验收锚点 |
|------|----|--------|------|----------|
| 1 | AUD-P0-1 | 摇杆死区+键位冲突 | 操作 P0 | 1.11 |
| 2 | AUD-P0-2 | 载具 InputMap 化 | 操作 P0 | 1.12 |
| 3 | AUD-P0-3 | coyote+buffer | 操作 P0 | 1.13 |
| 4 | AUD-P0-4 | GLB preload | 模型 P0 | 1.14 |
| 5 | AUD-P0-5 | 描边分级 | 模型 P0 | 1.15 |
| 6 | AUD-P0-6 | 弹孔池全检 | 特效 P0 | 1.16 |
| 7 | AUD-P0-7 | 烟雾/爆炸入雾昼夜 | 特效 P0 | 1.17 |
| 8 | AUD-P0-8 | 水面/闪电/云池化 | 特效 P0 | 1.18 |
| 9 | AUD-P1-1 | 地形 LOD | 模型 P1 | 2.10 |
| 10 | AUD-P1-2 | 建筑共享 | 模型 P1 | 2.11 |
| 11 | AUD-P1-3 | 移动/射击曲线可学习 | 操作 P1 | 2.12 |
| 12 | AUD-P1-4 | GPU 粒子池 | 特效 P1 | 2.13 |
| 13 | AUD-P1-5 | 局外天赋 | 玩法 P1 | 2.14 |
| 14 | AUD-P1-6 | 种子化地标 | 玩法 P1 | 2.15 |
| 15 | AUD-P1-7 | 雨雪生存化 | 玩法 P1 | 2.16 |

> 注：C3/C6/C7（export/IP/复玩）为发行域，不挤占 S 级玩法修复，按 Phase 4 并行。

---

## 验证命令矩阵

```bash
# 基座
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 600
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 520 -- --wildtest --ground --arm --seed 7
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 120 -- --noworld --ground --focusrecoverytest
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 120 -- --noworld --ground --seasontest
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 30  -- --noworld --feedtest
tools/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --quit-after 30000 -- --sim --seed 7
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300 -- --firetest --ground --arm --seed 7
# 窗口抽检
tools/Godot.app/Contents/MacOS/Godot --path . -- --screenshot /tmp/probe.png --frames 300 --seed 7
# AUD 新增探针（随任务落地）
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300 -- --firetest --ground --arm --seed 7  # 伤害-距离表（AUD-P1-3）
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 600 -- --wildtest --seed 7 --seed 13  # 布局 hash 对比（AUD-P1-6）
tools/Godot.app/Contents/MacOS/Godot --path . -- --screenshot /tmp/aud_night.png --frames 300 --seed 7  # 夜景压暗（AUD-P0-7/8）
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 720 -- --reloadtest --seed 7  # 弹孔池（AUD-P0-6）
```

> 本文件与 `docs/ISSUES.md` 共同为唯一真实来源；Top 15 Backlog 以 Critical/High/S 级为序，Phase 划分与门禁均以此为准。新增 AUD 段与既有 C/H/M/L 并列，互不覆盖。
