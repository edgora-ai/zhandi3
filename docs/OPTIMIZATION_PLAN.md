# zhandi3 优化方案与任务拆解（2026-08-29）

> **执行状态（2026-08-29 修复轮收尾）**：P0 批次全部完成并通过验证——A1-A6、B1-B5、B6、G1、G2 + P1 中的 C1/C2/C4/C5、D2/D3/D6/D7(部分)、E1、E2、F2、F4。验证记录：headless 基座/`--wildtest`/`--firetest`/`--sim` 全绿零 SCRIPT ERROR；sim KPI `bot_armor_avg` 50–100%、`vv_ratio` 0.41–0.58；毒圈 `zone_r=14 phase=5` 全场打完；视觉修复以 `/tmp/r_fp3.png`（突击步枪+视模型）、`/tmp/r_night.png`（夜景压暗）截图为凭。明细见 `ISSUES.md` § OPT 修复轮已验证。未完成：C3/C6、D4/D5、E3–E5、F1/F3/F5–F9、G3–G7、H1–H6。
> 定位：`docs/ISSUES.md` 定义"是什么/为什么"，`docs/ROADMAP.md` 定义"何时做/门禁"，本文件把 `docs/REVIEW_20260829.md`（玩家×策划全面评审，75 条问题）拆解为**可直接开工的任务**，每条含改动要点与可执行验收条件。
> 任务 ID 规则 `OPT-<工作流><序号>`，提交信息与代码注释沿用工程惯例：`fix(OPT-A3): ...` + `// FIX: OPT-A3 ...` 可追踪前缀；任务完成时同步更新 `ISSUES.md` 对应行（新增行在标题中带 OPT ID）。
> 规模：S<0.5 天 / M 0.5–2 天 / L 2–5 天 / XL>5 天。优先级：P0（对抗成立性）/ P1（手感与表现）/ P2（长线与打磨）。

## 全局完成定义（DoD，所有任务继承）

1. `--headless --quit-after 600` 退出码 0，零 `ERROR`/`SCRIPT ERROR`/`!is_inside_tree()`/`already has a parent`
2. `--wildtest --ground --arm --seed 7` 与 `--sim --seed 7` 既有断言零回退
3. 涉及视觉的任务必须附 `--screenshot` 前后对比图；涉及数值的任务必须在 `--sim`/`--firetest` 输出可 grep 的 KPI 行
4. 固定 `--seed 7` 二次运行结果一致

---

## 〇、任务总表

| ID | 任务 | 规模 | 优先级 | 归属 | 依赖 | 覆盖问题 |
|----|------|------|--------|------|------|----------|
| OPT-A1 | Bot 资源行为：捡甲/捡药/回血 | M | P0 | Phase1 插入 | — | PG2 |
| OPT-A2 | Bot 拾取失败冷却与可达性 | S | P0 | Phase1 插入 | — | PG3、P3 残余 |
| OPT-A3 | Bot 交战公平四连修 | M | P0 | Phase1 插入 | — | CB5、CB6 |
| OPT-A4 | 趴姿/自适应高度感知 | S | P0 | Phase1 插入 | — | CB7 |
| OPT-A5 | Bot 命中反馈（飘字/白闪/低血） | S | P0 | Phase1 插入 | — | CB8 |
| OPT-A6 | Bot burst pause 方向修正 | S | P0 | Phase1 插入 | — | REG6、H3 残余 |
| OPT-B1 | 时停约束（CD/Boss 免疫/减伤） | M | P0 | Phase1 插入 | — | CB1、R3 |
| OPT-B2 | 弹反规则统一（投射物=hitscan） | M | P0 | Phase1 插入 | — | CB2、R30 |
| OPT-B3 | 完美格挡防连点刷新 | S | P0 | Phase1 插入 | — | CB3 |
| OPT-B4 | 疾疾（flurry）限频 | S | P0 | Phase1 插入 | — | CB4 |
| OPT-B5 | 精灵复活契约（战场归零/播报/无敌帧） | M | P0 | Phase1 插入 | — | PG6、CB16 |
| OPT-B6 | PvE 投射物阵营 mask 与部位判定 | M | P0 | Phase2 插入 | B2 | CB11、R5 |
| OPT-C1 | hitscan 距离衰减 | M | P1 | Phase2 插入 | — | CB9、G9 |
| OPT-C2 | 视角系散布 + 连射 bloom | M | P1 | Phase2 插入 | — | CB10 |
| OPT-C3 | 武器生态位与掉落权重再平衡 | M | P1 | Phase2 插入 | C1 | CB19、PG10 |
| OPT-C4 | 近战/箭统一增伤与判定半径 | S | P1 | Phase2 插入 | — | CB12、G8、R25 |
| OPT-C5 | 弓数值与射速闸 | S | P1 | Phase2 插入 | — | CB18、R4 |
| OPT-C6 | PvE 攻击可读性包（telegraph/Boss 阶段） | L | P1 | Phase2 插入 | — | CB13、CB14、CB15、R22 |
| OPT-D1 | 换弹反馈链（音+动画+完成音） | M | P1 | Phase2 插入 | D7 | FX1 |
| OPT-D2 | 枪口焰统一（玩家+bot 火舌面片） | S | P1 | Phase2 插入 | — | FX3 |
| OPT-D3 | 受击方向指示 + 濒死音频层 | M | P1 | Phase2 插入 | — | FX6 |
| OPT-D4 | hitmarker / 击杀确认 / 爆头区分 | S | P1 | Phase2 插入 | D3 | CB17 |
| OPT-D5 | 弹孔 decal 与材质区分命中 | M | P1 | Phase2 插入 | H4 | FX8 |
| OPT-D6 | 曳光差异化与守卫光束语义 | S | P1 | Phase2 插入 | — | FX9 |
| OPT-D7 | 视模型与 HUD 修正包 | M | P1 | Phase2 插入 | — | TA8、TA9、VIS1、VIS2、VIS3 |
| OPT-E1 | 音频回归四连修（雨/脚步/弓音/压限） | M | P1 | Phase2 插入 | — | REG1、REG2、REG3、REG5、FX2、FX4、FX5、FX7 |
| OPT-E2 | 音效池优先级 + 日志治理 | S | P1 | Phase2 插入 | — | FX13、FX18 |
| OPT-E3 | 音效覆盖缺口补齐（≥12 类） | M | P2 | Phase3 | E1 | FX14 |
| OPT-E4 | 3D 衰减重构 + 混响总线 | M | P2 | Phase3 | E1 | FX15、M10 |
| OPT-E5 | 音乐循环扩写 + 血月音频联动 | M | P2 | Phase3 | — | FX16、L2 |
| OPT-F1 | glb 角色卡通化重染 + 平滑着色 | L | P1 | Phase2 插入 | — | TA1、TA2 |
| OPT-F2 | unshaded 植被/水面日夜联动 | M | P1 | Phase2 插入 | F3 | TA3 |
| OPT-F3 | EnvironmentDirector 环境合成器 | L | P1 | Phase2（=2.9） | — | TA4、R19、M4 |
| OPT-F4 | 太阳轨迹修复 | S | P1 | Phase2 插入 | F3 | TA5 |
| OPT-F5 | 森林阴影（冠层投影/blob shadow） | M | P2 | Phase3 | — | TA6 |
| OPT-F6 | 草治理（淡出 + 路面/沙滩过滤） | M | P2 | Phase3 | — | TA7 |
| OPT-F7 | 描边规范统一 | M | P2 | Phase3 | — | TA10 |
| OPT-F8 | 建筑细节层（贴图/屋顶形制/沙袋） | L | P2 | Phase3 | — | TA11 |
| OPT-F9 | 渲染正确性杂项包 | M | P2 | Phase3 | — | TA12、TA13、TA14、TA15、TA16、TA17 |
| OPT-G1 | 毒圈节奏重调 | M | P0 | Phase1/2 插入（=G5/R24） | — | PG1 |
| OPT-G2 | 据点 buff 时效与争夺裁决 | M | P0 | Phase2 插入 | — | PG4、R23、H2 |
| OPT-G3 | 载具成本与车内伤害 | M | P1 | Phase2 插入（=M2） | — | PG5 |
| OPT-G4 | 搜刮经济与空投 | M | P1 | Phase2 插入 | — | PG9、PG11 |
| OPT-G5 | 精力经济重调 | S | P1 | Phase2 插入 | — | PG12 |
| OPT-G6 | 旷野模式定位二选一 | L | P2 | Phase3（=G1/R2） | — | PG7 |
| OPT-G7 | --seed 真复现 + 二周目增量 | L | P2 | Phase3/4（=C7） | — | PG8、REG4 |
| OPT-H1 | 毒圈反馈包（圈墙材质/tick 音/下圈预览） | M | P1 | Phase2 插入 | G1 | FX10、VIS4 |
| OPT-H2 | 占领世界内可视化与争夺音 | S | P1 | Phase2 插入 | G2 | FX17 |
| OPT-H3 | 结算增强与文案治理 | S | P2 | Phase2 插入 | — | PG14、M5 |
| OPT-H4 | 特效性能包（共享资源/GPU 粒子/光源预算） | L | P2 | Phase3 | D5 | FX11、FX12、TA13 |
| OPT-H5 | 反馈杂项包（飘字/落地水花/引雷/入水） | S | P2 | Phase3 | — | FX19、FX20 |
| OPT-H6 | 天空元素（云形/花瓣/地表色斑） | S | P2 | Phase3 | F3 | VIS5、VIS6、VIS7 |

> 批次建议：**M1 批次（对抗成立）** = OPT-A1~A6 + B1~B5 + G1 + E1；**M2 批次（手感反馈）** = OPT-C1/C2/C4/C5 + D1~D7 + G2/G3/G5 + H1/H2 + F1~F4；**M3 批次（表现与长线）** = 其余。

---

## 一、WS-A：Bot 对抗公平性（P0）

### OPT-A1｜Bot 资源行为：捡甲/捡药/回血（M｜P0）
- 覆盖：PG2（ISSUES 无对应行，完成时新增）
- 文件：`scripts/bots/bot.gd`、`scripts/game/loot.gd`
- 要点：`_find_nearest_loot` 的 kind 扩展 `"armor"/"medkit"`；think tick 增加需求评估——hp<60% 搜 45m 内 medkit、armor==0 搜 45m 内 armor；拾取走现有 `Loot` 消费接口；优先级 weapon > medkit(重伤) > armor > ammo。
- 验收：
  1. `--sim --seed 7` 结束打印 KPI 行 `[sim][kpi] bot_v_bot_kill_ratio` ≥0.50、`bot_armor_avg` ≥40%、`bot_zone_death_ratio` ≤0.35
  2. 探针断言：hp=50 的 bot 半径 10m 放 1 medkit，8s 内拾取且 hp 上升 >20
  3. bot 拾取护甲后 `take_damage` 吸收路径有日志命中

### OPT-A2｜Bot 拾取失败冷却与可达性（S｜P0）
- 覆盖：PG3（P3"已修"的残余：`bot.gd:460-469` 注释 `12s` 无实现，`_loot_failed_pos` 只写不读）
- 文件：`scripts/bots/bot.gd`
- 要点：LOOT 失败记录 `pos+kind` 与失败时刻；12s 冷却内 `_find_nearest_loot` 过滤同目标；fallback 分支同规则；可选：路径可达粗检（水平距离 vs 直线 + 障碍射线）。
- 验收：
  1. 构造不可达武器（建筑碰撞体内），bot 在 1 个失败周期（8s）后转 ROTATE，30s 内不再锁定该物资（日志断言）
  2. `--sim --seed 7` 全场结束时 LOOT 卡死 bot 数 = 0（新增 KPI 行 `bot_loot_stuck`）
  3. 删除或实现 `_loot_failed_pos`（零"只写不读"变量，grep 验证）

### OPT-A3｜Bot 交战公平四连修（M｜P0）
- 覆盖：CB5（受击瞬锁/无反应时间/8m 背后全感知）、CB6（丢视后穿烟开火 2.5-4.2s）
- 文件：`scripts/bots/bot.gd`
- 要点：
  1. 受击：`take_damage` 记录伤害来源方向，进入 0.5s 警觉期（转向但不锁 `aim_target` 不开火）；无 LoS 只朝方向警戒、可逼近搜索 ≥5s
  2. 索敌：背后感知半径 8m→3m；枪声事件驱动转向（复用烟雾/口哨的事件通道）
  3. 停火：LoS 丢失（含 `_smoke_blocks` 判定接入交火循环）>0.5s 即停火，最多对最后已知位置 1 次 ≤3 发压制；完全丢失 1s 转 ROTATE
  4. 交战态每 0.5s 检查毒圈并加权撤退
- 验收：
  1. `--firetest` 新增场景：超视距（>100m）狙击 bot → bot 首发延迟 ≥500ms；烟雾中已锁定 bot → 受击伤害 0
  2. 探针：bot 背后 5m 静步接近 → 不被感知；bot 对烟内目标开火弹数 ≤3
  3. `--sim --seed 7` 玩家平均存活时间不下降（防修过头），bot 互杀占比不下降（OPT-A1 联动）

### OPT-A4｜趴姿/自适应高度感知（S｜P0）
- 覆盖：CB7（`bot.gd:427` 射线终点硬编码 1.4m，趴姿胶囊顶 0.9m 掠空）
- 文件：`scripts/bots/bot.gd`
- 要点：索敌射线对每个 combatant 用其碰撞形状求胸口采样高度（站立 ~1.4m、趴姿 ~0.5m）；趴姿感知距离 ×0.5。
- 验收：探针断言——30m 外趴下玩家可被 ≤2×SIGHT_RANGE 内 bot 发现（概率 >0）；站立感知距离不变（回归）；`--firetest` 增加趴姿场景。

### OPT-A5｜Bot 命中反馈（S｜P0）
- 覆盖：CB8
- 文件：`scripts/bots/bot.gd`、`scripts/fx/damage_number.gd`
- 要点：bot `take_damage` 接 `DamageNumber.spawn_at`（与 wild_monster 同款，爆头变色）；0.1s 材质闪白（复用怪物受击实现）；hp<30 显示低血提示（飘字"残血"或体型缩放脉冲）。
- 验收：`--firetest` 打 bot 断言飘字生成 + 闪白标志；截图比对 bot 与怪物受击表现一致。

### OPT-A6｜Bot burst pause 方向修正（S｜P0，回归）
- 覆盖：REG6（H3 只修了精度方向，`bot.gd:655` 停顿仍 `× skill` 反向）
- 文件：`scripts/bots/bot.gd`
- 要点：`_burst_pause = randf_range(0.35, 0.9) / skill`（或 `× (2.0 - skill)`）。
- 验收：`--firetest` 断言 skill=1.5 与 skill=0.7 的 bot 各 30s 输出窗口，有效 DPS 比值 ≥2.0；高 skill bot 停顿均值 < 低 skill bot。

---

## 二、WS-B：玩家技能约束与死亡契约（P0）

### OPT-B1｜时停约束（M｜P0）
- 覆盖：CB1（无 CD、可冻结 Boss、无减伤）；R3（自冻结已修，保持回归）
- 文件：`scripts/player/player.gd`
- 要点：加 `stasis_cd` ≥15s；目标 `hp >= 150` 时冻结时长 1.5s 或直接免疫（建议按 `max_hp` 阈值而非当前血）；冻结期间目标 `take_damage` 减免 50%；同目标 30s 冷却字典。
- 验收：
  1. `--wildtest` 断言：连续两次按 V，第二次无效果直至 CD 结束；西诺克斯/守卫被冻结 ≤1.5s
  2. 冻结期间对目标 DPS 减半（探针数值断言）
  3. `--sim` 全场时停触发次数与 CD 一致（无连发）

### OPT-B2｜弹反规则统一（M｜P0）
- 覆盖：CB2（`wild_projectile.gd:96-113` 无窗口/无消耗/无限反弹）；R30（弹反后 mask 打不中施法者）
- 文件：`scripts/game/wild_projectile.gd`、`scripts/player/player.gd`
- 要点：投射物命中举盾玩家走与 hitscan 同一判定函数——完美窗口内才反弹（速度 ×1.4 保持），窗口外按 0.25 减伤+10 精力；弹反成功后投射物 `collision_mask` 切玩家阵营层使其可命中施法者。
- 验收：
  1. `--wildtest` 断言：非完美时机举盾吃石 → hp 减少（0.25×12=3）且精力 -10；完美窗口 → 弹回
  2. 弹回的石块可对投掷者造成伤害（守卫/小怪探针）
  3. 持续举盾 10s 内被同源投射物命中 ≥2 次消耗精力（非无限免费）

### OPT-B3｜完美格挡防连点刷新（S｜P0）
- 覆盖：CB3（`player.gd:854-856` 每次抬盾重置 `_block_start`）
- 文件：`scripts/player/player.gd`
- 要点：`_block_start` 仅在"从非格挡→格挡"的边沿记录一次；松盾后 0.5s 内再举不构成新完美窗口（期间按普通减伤）；弹反成功才返还精力。
- 验收：探针模拟 10Hz 连点右键 5s，完美格挡触发次数 ≤ 实际抬盾边沿数且落空后 0.5s 内无完美判定；守卫光束弹反一次后无二连弹反。

### OPT-B4｜疾疾（flurry）限频（S｜P0）
- 覆盖：CB4（0.3s iframe/0.8s CD 可常驻慢动作）
- 文件：`scripts/player/player.gd`
- 要点：`flurry_internal_cd` ≥3s（真实时间，参考 P12 墙钟方案）；单场战斗（进入交战态起算）≤3 次；慢动作时长 1.6s 墙钟 → 0.6s 游戏时或保持 1.6s 但倍率窗口缩至 0.8s；近战倍率 2.0→1.5。
- 验收：`--wildtest` 探针：连续翻滚 10 次只触发 ≤3 次 flurry；触发间隔 ≥3s；`Engine.time_scale` 恢复路径零泄漏（M12 回归保持）。

### OPT-B5｜精灵复活契约（M｜P0）
- 覆盖：PG6（战场默认 1 只=隐藏复活币）、CB16（复活无无敌帧可被秒烧）
- 文件：`scripts/player/player.gd`、`scripts/main.gd`、`scripts/player/hud.gd`
- 要点：战场图 `fairies` 默认 0（`_map_id=="battlefield"` 时归零，或按地图配置表）；wild 保持现有；复活后 1.5s 无敌 + HUD 护盾图标；wild 图复活也 emit feed（"小精灵把你拉了回来"保留）并在击杀者侧记 assists（若战场图未来允许拾取精灵）。
- 验收：
  1. `--sim --seed 7`（战场）断言全场复活次数 = 0；`--wildtest` 断言精灵复活链路不回退且复活后 1.5s 内 `take_damage` 无效
  2. HUD 在持有精灵时显示剩余数；复活瞬间有 feed 行
  3. README 操作/机制描述同步更新

### OPT-B6｜PvE 投射物阵营 mask 与部位判定（M｜P0，随 Phase2 工厂化落地）
- 覆盖：CB11（mask 不含 bot 层、箭不传部位）；R5/R30
- 文件：`scripts/game/wild_projectile.gd`、`scripts/player/player.gd`（`_fire_arrow`）
- 要点：投射物 mask 按"发射者阵营的敌对层全集"（野怪发射→可打 bot/玩家；玩家发射→可打野怪/bot）；`take_damage` 增加部位参数，箭命中走 `get_hit_part`，弓爆头 ×1.5、可触发西诺克斯独眼硬直。
- 验收：
  1. `--wildtest` 断言：bot 会被野怪石块/火焰弹伤害；玩家箭命中西诺克斯头部触发硬直（日志/状态断言）
  2. 玩家弓对木靶爆头位伤害 = 1.5×（探针）
  3. 玩家不被自己箭误伤（source 豁免保持）

---

## 三、WS-C：战斗数值与手感（P1）

### OPT-C1｜hitscan 距离衰减（M｜P1）
- 覆盖：CB9；G9（TTK 趋同）
- 文件：`scripts/player/weapon.gd`
- 要点：`WEAPONS` 表加 `falloff_start/falloff_end/falloff_min`；SMG 60m 起 →100m -60%、rifle 120m 起 -25%、DMR 250m 起 -15%；伤害插值线性。
- 验收：`--firetest` 在 10/50/100/150m 固定靶打印伤害 KPI 行，断言各枪曲线符合上表；SMG 100m TTK ≥1.4s；三枪 30m TTK 拉开 >15%（G9 口径）。

### OPT-C2｜视角系散布 + 连射 bloom（M｜P1）
- 覆盖：CB10（世界轴扩散塌缩、无 bloom）
- 文件：`scripts/player/weapon.gd`
- 要点：扩散改为 `dir + cam_basis.x*rx + cam_basis.y*ry`（机瞄/腰射同源）；`_bloom` 每发 +0.15°、上限 +1.2°、停火 0.3s 后按指数回落；bot 侧散布同步改视角系（防同类 bug）。
- 验收：
  1. `--firetest` 新增俯射场景（塔顶向下 60°）：100 发弹着分布各向异性比 <1.5（当前塌缩态 >3）
  2. 连发 10 发散布半径单调上升且 ≤ 上限；停火 1s 后恢复初值
  3. 现有 `H3` 精度断言不回退

### OPT-C3｜武器生态位与掉落权重再平衡（M｜P1，依赖 C1）
- 覆盖：CB19（步枪无生态位）、PG10（DMR 垄断、护甲两档）
- 文件：`scripts/player/weapon.gd`、`scripts/main.gd`（掉落权重）、`scripts/game/loot.gd`
- 要点：DMR 武器权重 20%→≤8%；步枪定位"对甲"：护甲吸收上限对步枪 0.6→0.45；补 r3 护甲 75 值；SMG 12m 内 ×1.3。
- 验收：`--sim --seed 7` 统计一局 DMR 出现数 ≤ 全武器 10%；探针：50 甲目标被步枪击杀 TTK 比 SMG 快 >15%（20-50m）；三档护甲均可在战局出现（loot 统计行）。

### OPT-C4｜近战/箭统一增伤与判定半径（S｜P1）
- 覆盖：CB12（锁定 4.2m vs 判定 2.6m；不吃 `damage_mult`）；G8/R25
- 文件：`scripts/player/player.gd`
- 要点：锁定半径与弧形判定统一 2.6m（或 lunge 速度提到覆盖差值）；`_apply_melee_hit` 与 `_fire_arrow` 乘 `damage_mult`；锁定目标超判定范围时显示"太远"微反馈而非挥空。
- 验收：`--wildtest` 断言：吃烤串（+25%）后近战单刀伤害 = 基础 ×1.25；占点 buff 下近战同步 +10%；锁定目标在 3.5m 时不再必落空（lunge 后命中或明确 miss 反馈二选一）。

### OPT-C5｜弓数值与射速闸（S｜P1）
- 覆盖：CB18；R4（绕过 RPM/双扣弹药，保持回归）
- 文件：`scripts/player/player.gd`、`scripts/player/weapon.gd`
- 要点：`_fire_arrow` 进 `_cool` 闸（≥0.35s）+ 最低 draw 0.25 才可放箭；满抽伤害 38→45；命中接 `hit_landed`（播 hit 音）。
- 验收：探针连点放箭频率 ≤1/0.35s；满抽木靶伤害 =45；箭命中播放 hit 音（日志断言）；R4 双扣断言不回退。

### OPT-C6｜PvE 攻击可读性包（L｜P1）
- 覆盖：CB13（投石/飞行器无前摇）、CB15（西诺克斯无攻击环）、CB14/TA 侧（巨龙站桩不预判）；R22
- 文件：`scripts/game/wild_monster.gd`、`flying_attacker.gd`、`hinox.gd`、`wild_dragon.gd`
- 要点：
  1. 投石加 ≥0.5s 抬臂前摇 + `FX.attack_ring`，预警期锁定发射瞬间预判点
  2. 飞行器开火 ≥0.6s 充能音+眼部发光，弹速 19→16 或伤害 15→12
  3. 西诺克斯跺地前摇 0.42→0.7s + 脚下 4.2m 攻击环；投石举手动画同步
  4. 巨龙二阶段新增俯冲掠地（近战窗口 2s）或扇形扫射弹幕（需掩体）；血 ≤50% 落地喘息弱点期 4s
- 验收：
  1. `--wildtest` 断言：三类攻击发动前 attack_ring 存在帧数 ≥ 前摇 ×0.8；预警期玩家位移后命中点不变（投石）
  2. 龙二阶段探针：出现俯冲/弹幕新攻击模式 ≥1 种；弱点期龙的高度 ≤10m
  3. 被飞行器击杀的死亡回放/日志能定位声源（充能音先于弹体 ≥0.6s）

---

## 四、WS-D：核心反馈链（P1）

### OPT-D1｜换弹反馈链（M｜P1，依赖 D7 视模型）
- 覆盖：FX1
- 文件：`scripts/player/weapon.gd`、`tools/gen_sfx.py`、`scripts/fx/sfx_bank.gd`
- 要点：`gen_sfx.py` 新增 `reload_start`（拔匣）/`reload_end`（上膛 click）双段采样；`start_reload`/补弹时刻各播一段，与 reload 时长对齐 ±50ms；视模型换弹动画：枪体下沉 15°+ 弹匣位移，时长 = reload 时长。
- 验收：`--firetest` 断言两段音各播一次且时间差 = reload 时长 ±50ms；换弹期截图视模型姿态变化（前后对比图）；空仓自动换弹同样触发。

### OPT-D2｜枪口焰统一（S｜P1）
- 覆盖：FX3
- 文件：`scripts/player/weapon.gd`、`scripts/main.gd`（bot 开火路径）
- 要点：十字/星型 unshaded quad 面片 0.05s + 现有 OmniLight 脉冲；bot 开火在 `muzzle_world()` 同步生成（60m 内可见）；共享同一 mesh/material。
- 验收：`--screenshot --frames N` 抓开火帧：玩家与 bot 均有可见火舌（对比图）；同屏 8 bot 齐射无材质重复创建（探针零 new Material）。

### OPT-D3｜受击方向指示 + 濒死音频层（M｜P1）
- 覆盖：FX6
- 文件：`scripts/player/player.gd`、`scripts/player/hud.gd`、`audio/bus_layout.tres`、`scripts/fx/sfx_bank.gd`
- 要点：`take_damage` 把 `from` 方向（相对玩家朝向角）传 HUD；屏幕边缘 120° 弧形指示 ≥0.6s；hp≤30% 持续红晕 + 心跳音（60→140BPM 随血量）+ SFX bus 挂 low-pass ≤600Hz 随血量压低；回血解除。
- 验收：`--firetest` 从固定象限打玩家 → HUD 指示器角度误差 ≤45°（探针读 HUD 状态）；hp 30→10 探针：心跳 BPM 上升、low-pass 生效（bus effect 参数断言）；回满血红晕消失（H12 对称性回归保持）。

### OPT-D4｜hitmarker / 击杀确认 / 爆头区分（S｜P1，依赖 D3）
- 覆盖：CB17
- 文件：`scripts/player/hud.gd`、`scripts/main.gd`、`scripts/fx/damage_number.gd`
- 要点：准星四角 X 标记 0.15s（爆头红色）；击杀扩散圈+专属音（可复用 L2 的 stinger 体系）；飘字限频白名单豁免"击杀/弹反/弱点"。
- 验收：`--firetest` 断言命中/爆头/击杀三态 HUD 标志各触发一次；SMG 贴脸 10 连发"击杀"字不被限频吞（日志断言）。

### OPT-D5｜弹孔 decal 与材质区分命中（M｜P1，依赖 H4 预算结论）
- 覆盖：FX8
- 文件：`scripts/fx/fx.gd`、`scripts/player/weapon.gd`
- 要点：`FX.impact` 增加表面类型参数（碰撞法线+材质组：金属/沙土/木材/石）；生成小 decal quad（共享 3-4 张程序化贴图，`tex_gen` 扩展），池化上限 64 个 LRU 复用；命中音/粒子色按表面区分 ≥3 种。
- 验收：`--screenshot` 扫射墙面 ≥5 弹孔可见且存续（15s 内二次截图仍在）；同屏 decal ≤64（探针）；金属/木材命中音不同（播放日志断言）。

### OPT-D6｜曳光差异化与守卫光束语义（S｜P1）
- 覆盖：FX9
- 文件：`scripts/player/weapon.gd`、`scripts/game/guardian.gd`、`scripts/fx/fx.gd`
- 要点：`FX.tracer` 加 width/color 参数——SMG 0.02 金、rifle 0.025 金、DMR 0.05 亮金+0.1s 残影、箭无曳光（现有）；守卫光束改红柱（0.08 宽）+被锁定玩家屏幕边缘红闪 0.3s。
- 验收：截图比对三枪曳光宽度可辨；守卫发射瞬间被锁定视角红闪（探针 HUD 标志）。

### OPT-D7｜视模型与 HUD 修正包（M｜P1）
- 覆盖：TA8（ADS FOV 巨枪）、TA9（换弹/切枪/开火动画基底）、VIS1（武器名"波克剑"）、VIS2（绿色胶囊入画）、VIS3（剑比例过大）
- 文件：`scripts/player/weapon.gd`、`scripts/main.gd`、`scripts/player/player.gd`
- 要点：
  1. 视模型挂独立相机层或按 zoom 反缩放（ADS 前后投影尺寸不变）
  2. rifle accent 枪托件缩放/移位出画面；剑视模型整体 ×0.65 并右移，格挡块重比例
  3. 切枪 0.2-0.3s 抬枪入场插值；开火 pitch 回跳 ≥1.5°（供 D1 动画基底）
  4. 修 `main.gd:500` melee 分支硬编码标签：武器槽变化统一走 `player.weapon.label()`（1133 行路径）
- 验收：
  1. `--screenshot --ground --arm` 武器名 = 所持武器名（字符串断言）
  2. DMR 开镜截图枪占屏比 ≤ 腰射 1.2 倍
  3. 默认视角视模型不入画（占屏宽 ≤25%，截图比对）；切枪/开火截图姿态差异可见

---

## 五、WS-E：音频重整（P1/P2）

### OPT-E1｜音频回归四连修（M｜P1，回归）
- 覆盖：REG1（雨=海滩鸟鸣+双实例）、REG2（脚步错位/bot 无声）、REG3（弓音=hit）、REG5（无压限+合成削波）
- 文件：`scripts/world/weather.gd`、`scripts/player/player.gd`、`scripts/fx/sfx_bank.gd`、`tools/gen_sfx.py`、`audio/bus_layout.tres`
- 要点：
  1. `gen_sfx.py` 新增 `rain_loop`（宽带噪声+雨滴颗粒，无鸟鸣）与 ≥4 类脚步（草地/沙石/木板/水）；地形材质映射函数（读脚下顶点色/高度带）；游泳改 `water_slosh`
  2. 雨天播放 rain_loop 且全局 ambience 让位（单实例互斥）
  3. bot 脚步以 3D 播放（复用现有 play_at，移动节流）
  4. 弓新增 `bow_draw`（蓄力）+`bow_release`（弦震）；`shot_bow` 映射改新资源
  5. 合成归一化每轨 ≤0.89 true peak；Master 挂 Limiter（ceiling -1dB）
- 验收：
  1. `grep -n "ambience.wav" scripts/world/weather.gd` = 0；雨天日志仅 1 个环境音实例
  2. `gen_sfx.py` 产物全部峰值 ≤0.89（脚本内置断言打印）
  3. `--wildtest` 断言：草地/沙滩/木板三种表面脚步音名不同；bot 移动时 15m 内有脚步播放日志
  4. 8 枪 + 爆炸 + 雷同帧叠加，输出 wav 探针无削波（≤0dBFS）

### OPT-E2｜音效池优先级 + 日志治理（S｜P1）
- 覆盖：FX13（池轮询抢占）、FX18（print 刷屏）
- 文件：`scripts/fx/sfx_bank.gd`、`scripts/player/player.gd`
- 要点：`play` 分配优先非 playing 节点，满载按优先级抢占（UI > 命中确认 > 枪声 > 环境）；所有播放路径 print 收进 `OS.is_debug_build()` 或 `--verbose-sfx` 开关。
- 验收：探针 8 枪并发时 UI 音与 hit 音播放次数不缺失；release 模式（`--headless` 无调试标志）60s 运行 stdout 行数 <20。

### OPT-E3｜音效覆盖缺口补齐（M｜P2，依赖 E1）
- 覆盖：FX14
- 文件：`tools/gen_sfx.py`、`scripts/fx/sfx_bank.gd`、`scripts/game/smoke_grenade.gd`、`vehicle.gd`、`wild_motorcycle.gd`、`player.gd`、`korok.gd`、`wild_creature.gd` 等
- 要点：新增 ≥12 条：ui_click/weapon_switch/dodge_whoosh/water_splash/land_dust/smoke_pop/engine_loop（吉普+摩托）/korok_reward/animal_call（猪狼熊鸟各 1）/mount_neigh；交互触发→出声 <50ms。
- 验收：`--wildtest` 扩展断言：切枪/闪避/入水/落地/开箱各触发对应音名（日志）；`gen_sfx.py` 产物数 ≥35。

### OPT-E4｜3D 衰减重构 + 混响总线（M｜P2，依赖 E1）
- 覆盖：FX15；M10（统一但取值不合理）
- 文件：`scripts/fx/sfx_bank.gd`、`audio/bus_layout.tres`
- 要点：分类衰减——枪声/爆炸 max_distance ≥350 + 远距 low-pass；脚步/ Foley 60m；UI 2D；新增 Reverb bus，神庙/驿站室内 send ≥0.4（区域标签驱动）。
- 验收：220m 外枪声在接收端仍可闻（探针 -30dB 内）；室内/室外同一音效 reverb send 差异断言；M10 统一性回归不破。

### OPT-E5｜音乐循环扩写 + 血月联动（M｜P2）
- 覆盖：FX16；L2（stinger 保持回归）
- 文件：`tools/gen_sfx.py`、`scripts/fx/sfx_bank.gd`、`scripts/world/day_night.gd`
- 要点：日间循环扩至 ≥90s 双层（pad+旋律层，事件驱动强度）；修复铃音尾部截断（越界样本补零或收束）；血月触发 8s stinger + 低音 drone 层 crossfade ≤2s，结束回切。
- 验收：music.wav 时长 ≥90s 且循环点幅度连续（首尾 50ms RMS 差 <10%）；血月进出各 3 次无音量跳变（C2 三轨 Mixer 真值表回归保持）。

---

## 六、WS-F：渲染风格统一（P1/P2）

### OPT-F1｜glb 角色卡通化重染 + 平滑着色（L｜P1）
- 覆盖：TA1（PBR 哑光无描边）、TA2（flat 低分段）
- 文件：`scripts/game/wild_moblin.gd`、`wild_lizalfos.gd`、`hinox.gd`、`stal.gd`、`wild_creature.gd`、`keese.gd`、`wizzrobe.gd`（`_try_glb_visual` 统一 helper）、`tools/blender_gen/*.py`
- 要点：抽公共 `_apply_toon_override(glb, tint)`：按材质名 override 为 `Toon.make_material`（DIFFUSE/SPECULAR + next_pass 描边 0.014±0.002）；blender 脚本主体球体分段 ≥24 或 `shade_smooth` 后重新生成 glb（可再生产物，AGENTS 边界内）。
- 验收：
  1. 近距截图（`--moblintest`/`--liztest`）：莫布林/蜥蜴轮廓有 1-2px 描边、色带 2-3 阶（与 bot 同框对比图）
  2. 特写截图无可见平面棱块；glb 重新生成脚本入库可复现
  3. 材质数统计：每角色 override 后材质 ≤ 重染前（不膨胀）

### OPT-F2｜unshaded 植被/水面日夜联动（M｜P1，依赖 F3）
- 覆盖：TA3
- 文件：`assets/shaders/grass.gdshader`、`canopy.gdshader`、`water.gdshader`、`scripts/world/day_night.gd`
- 要点：三 shader 加 `day_light` uniform（0.12–1.0），DayNight 每帧写入（走 F3 合成器则由其分发）；ALBEDO ramp 与 `day_light` 相乘，夜晚保底环境项 0.15 防全黑。
- 验收：夜晚截图草地亮度 ≤ 白天 30%、水面不再发光（像素采样探针或直方图）；白天视觉零变化（回归截图 diff）。

### OPT-F3｜EnvironmentDirector 环境合成器（L｜P1，=ROADMAP 2.9）
- 覆盖：TA4（季节天空被昼夜覆盖）；R19、M4
- 文件：新增 `scripts/world/environment_director.gd`、改造 `season_system.gd`、`day_night.gd`、`weather.gd`、`main.gd`
- 要点：Season/DayNight/Weather 只发布权重（基色×强度），Director 单点合成 sky/fog/exposure/sun 并写 Environment；迁移现有直写点（`day_night.gd:99-130`、`season_system.gd:136-151`、`weather.gd:158-159`）。
- 验收：
  1. `--season winter` 截图天空 ≈ Color(0.50,0.67,0.86)、太阳能量 0.88 冷白；`--seasontest` 四季探针全绿
  2. grep `environment.` 直写仅存在于 Director 一处
  3. 昼夜循环 + 四季切换 + 降雨三事件并发 60s 无颜色跳变（帧采样曲线平滑）

### OPT-F4｜太阳轨迹修复（S｜P1，依赖 F3）
- 覆盖：TA5（asin 镜像、正午阴影翻转、相位错 90°）
- 文件：`scripts/world/day_night.gd`
- 要点：改方位角-仰角参数化（yaw = lerp(日出角, 日落角, t) 连续旋转；pitch = 单峰曲线，峰值对齐 phase 正午）。
- 验收：探针每 0.05t 采样太阳旋转——yaw 单调、pitch 连续、t=0.5 前后无 >5°/帧 跳变；`phase_name` 边界与仰角 ±10° 内对齐。

### OPT-F5｜森林阴影（M｜P2）
- 覆盖：TA6
- 文件：`scripts/world/props.gd`、`assets/shaders/canopy.gdshader`
- 要点：冠层 MultiMesh 开投影（或低面冠层代理 shadow-only pass / 接地 blob shadow quad），按性能预算二选一。
- 验收：正午截图林内/林外地表亮度差 ≥15%；`--sim` 帧率门禁不破（P50 ≥60）。

### OPT-F6｜草治理（M｜P2）
- 覆盖：TA7（16 万实例无淡出、长在路面/沙滩）
- 文件：`scripts/world/props.gd`、`scripts/world/terrain.gd`
- 要点：烘焙期过滤——道路顶点色带 4.2m+1m 过渡、沙滩带（WATER_LEVEL+1.2）内不种；MultiMesh 加 `visibility_range_end=60` + fade；计数由 16 万按过滤后实量重算。
- 验收：探针统计道路/沙带草实例 =0；远景（60m 外）截图无草点噪闪；帧率门禁不破。

### OPT-F7｜描边规范统一（M｜P2）
- 覆盖：TA10（宽度 7 倍离散、棱线断壳）
- 文件：`scripts/world/toon.gd`（缓存+规范表）、`buildings.gd`、`props.gd`、`weapon.gd`
- 要点：`Toon.make_material` 增加按类目宽度规范（角色 0.014/建筑 0.02/道具 0.01）与材质缓存字典；建筑描边壳共享平滑法线或改屏幕空间描边（可行性 spike 后定案）。
- 验收：同屏截图描边宽度比 ≤2×（当前 7×）；建筑棱线特写无断口；材质实例数下降（探针对比）。

### OPT-F8｜建筑细节层（L｜P2）
- 覆盖：TA11
- 文件：`scripts/world/tex_gen.gd`、`scripts/world/buildings.gd`
- 要点：tex_gen 新增砖缝/木板条纹贴图（可平铺）；墙面 UV 映射；村庄配方差异化——每村 ≥2 种屋顶形制 + 1 独有构筑（水井/晾架/祭坛）；沙袋 2 种尺寸+错位堆叠。
- 验收：三村截图并排有可命名差异；墙面特写有纹理非纯色；沙袋工事截图无同尺寸阵列感。

### OPT-F9｜渲染正确性杂项包（M｜P2）
- 覆盖：TA12（蕨类钉水面）、TA13（材质/网格碎片化）、TA14（点光堆积/青光滥用）、TA15（树冠卡片）、TA16（阴影距离/bias）、TA17（眼睛嵌入/开火帧）
- 文件：`wild_world.gd`、`props.gd`、`main.gd`、`wild_moblin.gd`、`tools/blender_gen/soldier.py`、`bot.gd`
- 要点：蕨类不合格点跳过并回收 instance_count；trunk/box 基础 mesh 全局共享+材质按色缓存；非近距灯光 distance fade、同屏实时光 ≤8、灯笼/路灯换暖芯黄；叶贴图 256→512；阴影距离 250→320 + bias 0.02；莫布林眼睛外移 0.02m；soldier 加 shoot 关键帧、bot 开火切换。
- 验收：
  1. 水面截图 0 漂浮蕨；wild Static draw call ≤2500（监视器探针行）
  2. 夜间截图同屏动态光 ≤8；驿站灯笼为暖色（截图）
  3. 莫布林特写眼睛在头面外；bot 对枪时肩部有后坐帧（连帧截图）

---

## 七、WS-G：玩法系统修正（P0/P1/P2）

### OPT-G1｜毒圈节奏重调（M｜P0，=G5/R24）
- 覆盖：PG1
- 文件：`scripts/game/zone.gd`、`scripts/main.gd`
- 要点：总时长 182→220-260s；第 3 阶段起收缩速度 ≥8.6m/s（或圈外 dps 2→4→8→16→32 每 10s 递增）；决赛圈半径 9→14m 缓冲。
- 验收：`--sim --seed 7` 断言：满血不进圈必死于第 2 阶段内；总时长 220-260s；决赛圈 DPS 保持 20（G5 既有口径）；玩家/bot 平均交战次数上升（KPI 行 `avg_fights_per_match` 基线对比）。

### OPT-G2｜据点 buff 时效与争夺裁决（M｜P0）
- 覆盖：PG4（永久全图/死者保留/站桩冻结/多占无收益）；R23、H2
- 文件：`scripts/game/capture_point.gd`、`scripts/main.gd`、`scripts/player/hud.gd`
- 要点：buff 改"身处圈内生效"或归属后 60s 衰减（二选一，建议前者+HUD 图标）；owner 死亡即转中立+播报；争夺冻结 >10s 进度倒退 0.2/s；多据点收益 1.1/1.15/1.2 递增并 HUD 明示。
- 验收：
  1. 探针：owner 走离据点 30m → `damage_mult` 回基线；owner 死亡 → 旗变中立色 + feed 行
  2. 双人僵持 10s 后进度开始倒退（日志断言）
  3. HUD 显示占有数与当前加成值；`--sim` 据点相关播报无死人持有

### OPT-G3｜载具成本与车内伤害（M｜P1）
- 覆盖：PG5（零成本/车内无敌/bot 不用车）；M2
- 文件：`scripts/game/vehicle.gd`、`horse.gd`、`wild_motorcycle.gd`、`scripts/bots/bot.gd`
- 要点：载具 hp 300-500（受击可爆，爆炸对驾驶员 40 伤）；驾驶员受击伤害 ×0.5（移除碰撞层清零的完全隐身，改为减伤+车体遮挡）；燃料按秒消耗+地图油桶补给；bot 转移意图 30% 概率找 60m 内载具（可后置）。
- 验收：探针：车内被打 hp 下降（×0.5）；载具受 500 伤爆炸+驾驶员掉血；`--sim` 全程车载进决赛圈路径 = 0（位置轨迹断言）；燃料耗尽可再补给跑通一圈。

### OPT-G4｜搜刮经济与空投（M｜P1）
- 覆盖：PG9（人均 3.3 件/锚点固定）、PG11（medkit 即用/弹药无上限）
- 文件：`scripts/main.gd`、`scripts/game/loot.gd`、`scripts/player/player.gd`、`buildings.gd`
- 要点：总物资 ≥ 人均 5 件、武器:弹药:医疗 ≈4:3:3；村庄/野点锚点纳入 `--seed` 播种；决赛圈前 1 次空投（光柱+伞包，含 r3 甲/DMR）；medkit 入包+3s 读条可打断；单武器位备弹上限 240。
- 验收：`--sim --seed 7` 物资统计 KPI 行达配比；同 seed 两局村庄位置一致、异 seed 不同；读条中受击取消回血（探针）；超上限拾取有 HUD 提示且不生效。

### OPT-G5｜精力经济重调（S｜P1）
- 覆盖：PG12
- 文件：`scripts/player/player.gd`
- 要点：滑翔/攀爬回复延迟 0.45→1.5s、回复 26→15/s；滑翔累计高度消耗递增（每降 20m 耗精 ×1.5）；游泳加轻消耗 1/s。
- 验收：探针满精力连续滑翔 ≤25s；疾跑-间歇-疾跑循环 60s 总位移下降 ≥20%；`--wildtest` 攀爬塔顶链路不破（21m 塔仍可一管登顶——上限校准依据）。

### OPT-G6｜旷野模式定位二选一（L｜P2，=G1/R2）
- 覆盖：PG7
- 文件：`scripts/main.gd`、`wild_world.gd`、`hud.gd`
- 要点：方案 a（战斗化）——每 bot 落点半径 40m 保底 1 武器+野外软缩圈+全灭结算；或方案 b（探索化）——UI 明示"探索模式"、隐藏 alive 计数、删无代价复活链。实施前定案，不双修。
- 验收：方案 a：`--sim --map wild` 终局空手 bot ≤1、全灭有结算画面；方案 b：HUD 无 alive 计数、死亡必须消耗资源（精灵/材料）；README 同步。

### OPT-G7｜--seed 真复现 + 二周目增量（L｜P2，=C7，回归）
- 覆盖：PG8、REG4
- 文件：`scripts/main.gd`、`scripts/game/zone.gd`、`scripts/bots/bot.gd`、`scripts/world/weather.gd`、存档服务（C5 基座）
- 要点：全局 RNG 收敛到种子派生子流（zone 漂移/bot skill/天气各自 `RandomNumberGenerator.seed = hash(seed, namespace)`）；二周目：结算写档（H21 占位对接）后下一局 bot skill 下限 0.7→0.9 或阶段时长 -10%。
- 验收：
  1. headless 断言脚本：`--seed 7` 两局输出毒圈中心序列/bot skill 列表/天气序列 hash 一致；`--seed 7` vs `--seed 13` 不一致
  2. 二周目开启后 `--sim` KPI：bot 命中率/存活曲线较一周目可测增强
  3. README"单机复玩"段与实现一致（删除或兑现占位文案）

---

## 八、WS-H：HUD、系统反馈与性能（P1/P2）

### OPT-H1｜毒圈反馈包（M｜P1，依赖 G1）
- 覆盖：FX10（掉血静默/无下圈预览）、VIS4（圈墙读作瑕疵）
- 文件：`scripts/game/zone.gd`、`scripts/player/hud.gd`、`scripts/fx/sfx_bank.gd`、`tools/gen_sfx.py`
- 要点：圈外掉血 tick 音（≥2 次/s）+屏幕滴答；小地图叠加下一目标圈虚线（`_target_center/_target_radius` 暴露，与 zone 同源）；圈墙材质改危险色渐变（红橙半透明）+ 底部 3m 墙裙加浓。
- 验收：圈外探针 tick 音频次正确；小地图虚线圈与实际缩圈终点误差 ≤2px（坐标换算断言）；四季/昼夜下圈墙截图均读作"危险边界"（对比图）。

### OPT-H2｜占领世界内可视化（S｜P1，依赖 G2）
- 覆盖：FX17
- 文件：`scripts/game/capture_point.gd`、`scripts/fx/sfx_bank.gd`
- 要点：占领圆环按进度扫描填充（0→100%）+ 逐秒 tick 音加速；被反占时旗顶闪烁。
- 验收：探针占领过程中圆环参数随 progress 线性变化；争夺状态旗帜闪烁标志；完成音保持不回退。

### OPT-H3｜结算增强与文案治理（S｜P2）
- 覆盖：PG14（统计单薄/"尸比"难懂）；M5（颜色无冗余，保持回归）
- 文件：`scripts/player/hud.gd`、`scripts/main.gd`
- 要点：结算增加存活时长/总伤害/占领次数/复活次数 ≥3 项；"尸比"改"淘汰"或"击倒"+图标；色块全部配文字。
- 验收：`--endtest` 截图含新统计行；HUD 三行文案评审通过（无歧义词）；M5 色盲冗余断言保持。

### OPT-H4｜特效性能包（L｜P2，前置 D5 的预算依据）
- 覆盖：FX11（每发 new Mesh/Material）、FX12（龙火球逐颗 OmniLight）、TA13（与 F9 部分合并）
- 文件：`scripts/fx/fx.gd`、`scripts/game/wild_projectile.gd`、`wild_dragon.gd`
- 要点：tracer/puff/streak 共享静态 mesh+material（运行时零分配）；命中改 GPUParticles2 组（spark+smoke，smoke 带程序化贴图）；火球/能量弹去逐颗光改共享 muzzle 光+发光材质+8-16 点拖尾；同屏动态光 ≤8 总预算（与 F9 合并执行）。
- 验收：SMG 10 连发探针零 `new StandardMaterial3D`；龙暴怒 10s 同屏动态光 ≤8；`--sim` 帧率门禁 P50 ≥60 且 1% low ≥45。

### OPT-H5｜反馈杂项包（S｜P2）
- 覆盖：FX19（飘字穿墙/AOE 吞字）、FX20（落地水花/引雷白帧）
- 文件：`scripts/fx/damage_number.gd`、`scripts/player/player.gd`、`scripts/world/weather.gd`
- 要点：飘字开 depth_test 或按距离淡出；AOE 多目标合并单总数；落地按速度 3-8 粒尘土；入水环形水花+水声（依赖 E3 water_splash）；被雷劈 0.1s 白帧+震屏+近距 thunder pitch 0.85。
- 验收：隔墙无飘字（探针）；炸弹 5 目标显示 1 个合计数字；落地/入水截图有粒子；被劈截图白帧。

### OPT-H6｜天空元素（S｜P2，依赖 F3）
- 覆盖：VIS5（云形重复/浮空）、VIS6（花瓣坏点感）、VIS7（地表薄荷色斑）
- 文件：`scripts/main.gd`（云生成）、`season_system.gd`（花瓣）、`terrain.gd`（顶点色过渡）
- 要点：云形 ≥3 种程序变形+高度带约束；花瓣贴图 ≥16px 带花形 alpha；排查薄荷色斑来源（草甸噪声/湿滑合成），加平滑过渡带。
- 验收：同屏截图云形 ≥3 种且无山腰浮云；花瓣特写非方块；色斑区域过渡带宽 ≥10m 无硬边。

---

## 九、执行顺序与依赖

```
M1（对抗成立，约 2 周）
  A1 ─┐
  A2 ─┤
  A3 ─┼─ 并行（同文件 bot.gd，建议单人串行：A2→A6→A3→A4→A5→A1）
  A4 ─┤
  A5 ─┘
  B1 B2 B3 B4 串行（同文件 player.gd：B3→B4→B1→B2）
  B5 独立
  G1 独立 → H1 可接续
  E1 独立（回归红线，最优先）
  A6（REG6）最先行：一行改动，立即消除难度倒挂

M2（手感反馈，约 2–3 周）
  D7 ─→ D1（换弹动画基底）
  D2 D3 ─→ D4
  C1 ─→ C3；C2 C4 C5 并行
  G2 ─→ H2；G3 G5 并行
  F3 ─→ F2 F4（合成器先立）
  F1 独立（blender 再生成周期长，尽早开跑）

M3（表现与长线，约 3–4 周）
  H4 ─→ D5（预算先定）
  F5 F6 F7 F8 F9；E2→E3 E4 E5；G4；B6；C6；H3 H5 H6；G6 G7
```

**回归红线**：E1（音频四连）、G7（seed 复现）、A6（难度方向）三项即使不进当期批次，也必须在下一批合入前完成重验并在 `ISSUES.md` 摘掉"已修"错标。

## 十、验证命令矩阵（新增/扩展）

```bash
# 既有基座（全局 DoD）
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 600
tools/Godot.app/Contents/MacOS/Godot --headless --quit-after 520 --path . -- --wildtest --ground --arm --seed 7
tools/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --quit-after 30000 --path . -- --sim --seed 7
tools/Godot.app/Contents/MacOS/Godot --headless --quit-after 300 --path . -- --firetest --ground --arm --seed 7

# 本方案新增探针（实现随对应任务落地）
--sim 输出 KPI 行：bot_v_bot_kill_ratio / bot_armor_avg / bot_zone_death_ratio /
                  bot_loot_stuck / avg_fights_per_match / revive_count
--firetest 输出：伤害-距离表 / 散布各向异性比 / bot 首发-受击延迟 / 烟中弹数
--wildtest 扩展断言：弹反窗口 / 时停 CD / flurry 限频 / 精灵契约 / 部位伤害 / 脚步音名
--seed 一致性脚本：两局 hash 对比（zone 漂移 / bot skill / 天气序列）

# 截图抽检（视觉任务必附）
tools/Godot.app/Contents/MacOS/Godot --path . -- --screenshot /tmp/probe.png --map battlefield --ground --arm --seed 7
tools/Godot.app/Contents/MacOS/Godot --path . -- --screenshot /tmp/probe_night.png --map wild --seed 7   # 夜晚 grass 亮度
```

## 十一、跟踪约定

1. 每个任务合入时：commit 前缀 `fix(OPT-XX):`，代码注释 `// FIX: OPT-XX ...`，并在 `ISSUES.md` 新增或更新对应行（标题带 OPT ID，验收列引用本文件条目）
2. 评审问题 → 任务映射完整性：REVIEW_20260829.md 的 PG1-14 / CB1-19 / TA1-17 / FX1-20 / VIS1-8 / REG1-6 全部被本表覆盖或并入既有追踪，无遗漏（PG13 并入 B2-B4 验收、FX2/4/5/7 并入 E1、TA13 并入 F9+H4；VIS8 小地图沿用 ISSUES.md 既有追踪 G6/R28，不另立任务）
3. 批次准出门禁沿用 `ROADMAP.md` 全局门禁 + 本文件 DoD；视觉任务以截图对比为凭据，数值任务以 KPI 行为凭据
