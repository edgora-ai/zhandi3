# zhandi3 全量问题清单 · 7视角评审建档

> 基线 `main@4041505` + prior 57 `.gd` / 17746 行 → 17810 行，Godot 4.7 Forward Plus。
> 已修复 21 项（P0 5 + 音画HUD + P1 稳定性 + Bot降频 + shot_bow + 蘑菇扣除 + InputMap/三平台脚手架），剩余按 S→M 逐项 headless 验证推送。
> 7视角落盘：Game Design 5.1 / Visual 5.9 / Tech 5.3 / Audio 4.7 / Systems 4.6 / QA 4.5 / Commercial 3.4，加权 ~4.7-4.8 需大改。
> Game@gpt-5.6-sol 11项（2 critical：Wild终局3重冲突+零存档；8 high：背包/InputMap/Guardian/圈192s/小地图等）与 QA 已落，剩余 peer 10 项与商业合规进入 S→M 修复。
> 重跑模型：Tech/Audio 用 `muse-free`（原 `gpt-5.6-sol` watchdog 超时）重跑成功；workflow `wufj3j4y7` 6/8 完成（2个 Prompt 过长失败已由直连 Agent 补齐）。
> 同伴3阻断与 Audio/Tech 互证已合并。

## 统计

- 总计 49 项（含同伴3阻断去重后）：Critical 7 / High 22 / Medium 17 / Low 3
- 关联 Task：P0 热修 #4 #5 / P1 稳定 #6 + 性能 #7 / P2 系统 #8 + 发行 #9
- 验证基座：`godot --headless --check-only` + `--screenshot` 雨夜回归（Task #3）

---

## Critical（7）

| # | 标题 | 视角 | 证据 | Task |
|---|------|------|------|------|
| C1 | `SOUNDS` 缺 `explosion/freeze/stasis/shot_bow` 静默 | Audio#1 / Game#4 | `sfx_bank.gd:5-20` 仅15条；`remote_bomb.gd:113` `player.gd:352/401` `main.gd:493` 直 `return`；`assets/sfx/*.wav` 存在 | #4 |
| C2 | 昼夜与 Boss 音乐同改 `volume_db` 互盖 | Audio#2 | `sfx_bank.gd:122-158` 夜 `-32dB` Boss 拉回 `-30dB`；Tween 打架；`_night_player` 未 duck | #5 |
| C3 | `export_presets.cfg` 缺失无法交付 | Tech#1 / Commercial | `project.godot:20-25` 仅 `1280x720 MSAA2x`；`export_presets.cfg` 不存在 | #9 |
| C4 | 输入硬编码无 InputMap/手柄全失效 | Tech#2 | `player.gd:568` `KEY_WASD` 直读；全仓 `@export 0` | #9 |
| C5 | 局外存档=0 “永久成长”归零 | Systems#1 / QA | `selected_map.txt` 仅存地图；`player.gd:26` 等实例变量 `reload_current_scene` 清零 | #8 |
| C6 | IP 直接下架风险 | Commercial | `README.md:1-3` 战地3/旷野之息/海拉鲁等 `main.gd:622` | #9 |
| C7 | 无复玩闭环/错误大逃杀定位 | Commercial | `main.gd:4` `BOT_COUNT 24` 短局；无网络/匹配/反作弊 | #9 |

## High（22）

| # | 标题 | 视角 | 证据 | Task |
|---|------|------|------|------|
| H1 | B 键背包抢占炸弹引爆永不可达 | Game#1 / QA#3 / Peer B | `player.gd:207 return` 抢占 `285` | #4 |
| H2 | 据点 `1.1^n` 指数叠加 | Peer C | `main.gd:854` 每0.5s `*=1.1` | #4 |
| H3 | Bot 精度反向+无限资源 | Game#2 | `bot.gd:311 1.8*skill` 越大越偏；`327 999` 备弹 | #4 |
| H4 | 四大 Boss 攻击全哑 | Audio#3 | `guardian.gd:329` `hinox.gd:172` `wild_dragon.gd:252` `wizzrobe.gd:102` 仅 `FX` | #5 |
| H5 | 全 Master 单总线无分层压限 | Audio#4 | `sfx_bank.gd:40,45` 全 `Master`；无 `bus_layout` | #5 |
| H6 | 移动/Foley 大面积哑区 | Audio#5 | `grep footstep 0`；`player.gd:598-813` `horse.gd` 零 `sfx` | #5 |
| H7 | AI O(N²)轮询+射线爆发必掉帧 | Tech#3 | `bot.gd:384` 31Bot≈3000 ray/s；Wild 无休眠 | #7 |
| H8 | 全同步 `load()`+单帧烘焙黑屏 | Tech#4 | `terrain.gd:212` 193x193 同步；`wild_world.gd:32` 数百 `add_child` | #7 |
| H9 | Player 超级 `_physics_process` | Tech#5 | `player.gd:598` 6组扫描+ImmediateMesh每帧重建 | #7 |
| H10 | HUD 固定像素溢出 | Visual#1 | `hud.gd:547` `660x490` 等 | #5 |
| H11 | 世界状态 420x54 裁切 | Visual#2 | `hud.gd:289` vs `main.gd:1121` 3行 | #5 |
| H12 | 毒圈红晕只开不关 | Visual#3 | `hud.gd:413` 仅 `on=true` | #5 |
| H13 | 小地图非导航 | Visual#4 | `hud.gd:136` 仅12色块 | #5 |
| H14 | 世界生成 `_home` 原点 | QA#2 | `wild_world.gd:70` 先 `add_child` 后坐标 | #6 |
| H15 | Stal `queue_free` 不可达泄漏 | QA#1 | `stal.gd:172` `not alive return` 挡 `220` | #6 |
| H16 | Bot/敌人 `is_instance_valid` 缺失 | QA#4,5 | `bot.gd:305` 等直访 `aim_target.alive` | #6 |
| H17 | 载具固定偏移无 shape_test | QA | `vehicle.gd:360` 等 | #6 |
| H18 | `global_position` 直写绕过物理 | QA | `player.gd:1711` `wizzrobe.gd:115` | #6 |
| H19 | 种子预算无上限无消耗出口 | Systems#2,3 | `player.gd:1010` `max_stamina` 无封顶；`wild_world.gd:1431` 多源；5项商店 | #8 |
| H20 | 成长与经济中后期溢出 | Systems#3 | `fish_spot.gd:37` 60s +血月多源 vs 护甲满甲归零 | #8 |
| H21 | 结算不进局外 | Systems#7 | `main.gd:765` `hud.gd:420` 仅展示 | #8 |
| H22 | 无输入/本地化/无障碍 | Commercial | `project.godot` 无 InputMap；中文硬编码 | #9 |

## Medium（17）

| # | 标题 | 视角 | 证据 | Task |
|---|------|------|------|------|
| M1 | 医疗上限 `100` 与 `max_hp` 成长不一致 | Game#6 | `loot.gd:345` 写死100 vs `player.gd:1027` `max_hp+10` | #4 |
| M2 | 载具无成本压缩探索 | Game#7 | `vehicle.gd:360` 27速 无燃料 | #8 |
| M3 | 神庙同模板无分层 | Game#8 | `shrine_trial.gd:134` 均 `completed` 开门 | #8 |
| M4 | 季节湿润被 Weather 覆盖 | Visual#5 | `weather.gd:114` vs `terrain.gd:382` | #5 |
| M5 | 纯颜色编码无冗余 | Visual | `hud.gd:661` 灰/青/绿 | #5 |
| M6 | `_puff` 实心球 | Visual | `fx.gd:100` 无 alpha/碎片 | #5 |
| M7 | 飘字 `no_depth_test` 无合并 | Visual | `damage_number.gd:10` | #5 |
| M8 | 雨雪 CPU 逐实例 `set_instance_transform` | Visual#9 | `weather.gd:15` 700+420 每帧 | #7 |
| M9 | 雨雪只有雷声 | Audio#6 | `weather.gd:96` 仅雷 | #5 |
| M10 | 3D 衰减不统一 | Audio#7 | `sfx_bank.gd:46 unit6` vs 地区声 `unit80` | #5 |
| M11 | Haptics/镜头缺失 | Audio#8 | 零 `vibration/shake`；顿帧50ms | #5 |
| M12 | `time_scale` 无栈泄漏 | Tech#6 | `player.gd:580/1077` 共用 `time_scale` | #7 |
| M13 | 零 `@export` 魔法数 | Tech#7 | 全仓 `@export 0` | #7 |
| M14 | 渲染无分级 | Tech#8 | `terrain.gd:124 res192` 常驻 | #7 |
| M15 | 体力药 `max_stamina+=20` 无层数 | QA | `player.gd:1969` 叠加 | #6 |
| M16 | `await` 缺 `is_inside_tree` | QA | `guardian.gd:236` 等 | #6 |
| M17 | `O(N²)` 组扫描 | QA | `wild_npc.gd:297` 等每帧 `get_nodes_in_group` | #6 |

## Low（3）

| # | 标题 | 视角 | 证据 | Task |
|---|------|------|------|------|
| L1 | 神庙统计 `shrines=2` 与实际4座不一致 | Game#9 | `wild_world.gd:23 vs 120` | #8 |
| L2 | 缺 Stinger/语音记忆点 | Audio#9 | `hinox.gd:117` 等仅 `pickup` | #5 |
| L3 | 启动统计与隐私/EULA缺失 | Commercial | `docs/` 无 | #9 |

---

## 路线图

- **Phase 1 阻断 4-6周：** #4 P0 5项 + #5 音画/HUD + `export_presets`/`InputMap` + 存档 + 异步/分帧 + IP 清理并行
- **Phase 2 体验 6-8周：** AI/Player 性能 + 成长预算 + HUD响应式/小地图 + 载具差异化
- **Phase 3 内容 8-12周：** 区域随机池/血月变体、神庙分层、野外风险层、讨伐分阶段
- **Phase 4 发行 4-6周：** 商店页/视频/胶囊、手柄/本地化、LICENSE/NOTICE、隐私/EULA、分级、LOD基准；定价 免费/6-15试玩→18-30买断

## 验证

- 每项修复后 `godot --headless --check-only` + `--screenshot` 雨夜回归（Task #3）
- 本文件为唯一真实来源，Top15 Backlog 以此为准

## 本轮增量（peer 10 项高置信，待逐项修复验证）

| # | 标题 | 证据行号 | 状态 |
|---|------|----------|------|
| P1 | wild_world 入树前 global_position：野怪/守卫/马/鱼/营地/飞行器/动物/NPC 均 add 后定位，导致 !is_inside_tree() ERROR 且 Guardian/Fish/WildMonster/Creature/Flyer/NPC 回原点 | wild_world.gd:73-74,80-81,127-128,962-963,967-968,988-989,1005-1006,1021-1022,1030-1031,1036-1040,1044-1048,1065-1068,1174-1179,1319-1324,1337-1340,1382-1402 | 部分已修（guardian/moblin/monster/fish/circle/trail/creature/attacker/npc 已改 add→pos→add），剩余需验证零 ERROR |
| P2 | Bot 悬垂 Loot：两 Bot 争同一 Loot，A consumed+queue_free，B 下帧解引用 freed | bot.gd:31,375,418-428,487-491；loot.gd:345-388 | 待 S 修 |
| P3 | Bot 无寻路仅直线+2.2m 射线，塔顶/城堡武器永久锁 LOOT | bot.gd:362-367,614-629；wild_world.gd:1410-1415 | 待 M 优化 |
| P4 | 血月类型污染：任意 wild_enemy 抑制指定类型 respawn，邻类抑制 | wild_world.gd:996-1008,1026-1057 | 待 S 修 |
| P5 | 血月遗漏类型：仅 5 类，其余 Stal/Keese/Wizzrobe/Chuchu/Hinox/Flyer/Dragon | wild_world.gd:996-1057 | 待 M 补 |
| P6 | Wild/BR 混用：阔野死亡重生但 Bot death 仍 BR victory | main.gd:611-638,642-663 | 待 S 修 |
| P7 | 载具内重生：die 不 exit vehicle，传送回被拉回载具 | player.gd:1110-1128；horse.gd:363-402；main.gd:642-663 | 待 S 修 |
| P8 | await 后直 queue_free（Creature/Liz/Wizzrobe/Hinox） | wild_creature.gd:266-279 等 | 待 M 加 is_inside_tree 守卫 |
| P9 | 倒木碰撞无 rotation 竖直块；守卫硬写 terrain y 覆桥 | wild_world.gd:1191-1206,251-258；guardian.gd:304-306 | 待 M 修 |
| P10 | Bot 只找 weapon 不找 ammo，空匣反复 reload 永久哑火 | bot.gd:355-367,590-595；weapon.gd:98-103 | 待 M 修 |

## 本轮增量2（peer 第二批 8 项，待逐项修复）

| # | 标题 | 证据 | 优先级 |
|---|------|------|--------|
| P11 | 骑乘死亡未 exit：vehicle/driver/可见性/碰撞/相机均不清，四载具逐帧拉回 | player.gd:1110-1128；main.gd:642-663；horse:526-528 vehicle:340 motorcycle:391 raft:215 | S |
| P12 | hitstop 全局 0.05 卡慢，恢复仅 783-787 且 Timer 受 time_scale 拉长至 44s | player.gd:1078,1568,783-787,599-635；main.gd:611-638 | S |
| P13 | 背包 +6 但实际 10 项，后 4 项不可达；main 回归绕过导航写索引 | player.gd:1890-1892,1913-1931；main.gd:1416,1420,1508 | S |
| P14 | N/B 文字不一致：main 1126/1129 与 hud 569 仍写 B，商店 N 被早截，骑乘 N 绕过 guard | project.godot:57-64 player.gd:207-287 main.gd:1126 hud.gd:569 | S |
| P15 | 游泳时 _scan_loot 前 return，抓鱼不可达；缩胶囊未恢复 | player.gd:632-635,781,845-855,513-520,1738-1746 fish_spot:37-45 | S |
| P16 | 盾滑无 stamina gate，0 精力可继续 | player.gd:712-721 | M |
| P17 | 大 delta 跨过 swipe 窗口/滑翔精力/台阶无 sweep | player.gd:1612-1632,681-705,1722-1735 | M |
| P18 | 精力药到期清退与重服窗口可永久多留 +20（早退未运行） | player.gd:795-799,1970-1974 | S |

## 本轮增量3（peer 10 项确定性缺陷，评分 4.5/10，再次确认）

> 已闭环：Stal crumble / Guardian await / Bot aim_target / Campfire 顺序
> 部分闭环：_home（入树前 global_position 仍 ERROR，需改 position/setup(home)）
> 未闭环 10 项如下，优先级 S→M：

| # | 标题 | 行号 | 优先级 |
|---|------|------|--------|
| D1 | Bot target_loot 悬垂（两 Bot 争同一 Loot，A queue_free 后 B 解引用） | bot.gd:375,487-491；loot.gd:345-388 | S |
| D2 | _home 部分闭环：仍有 Liz/Guardian/Fish/营地/Creature/Flyer/NPC 为 add 后定位 | wild_world.gd:1036-1040,1044-1048,1065-1068,1174-1179,1319-1324,1337-1340,1382-1402 | S |
| D3 | Bot 无寻路，塔顶/城堡 Loot 永久锁 LOOT，仅 2.2m 射线 | bot.gd:355-379,564-629；wild_world.gd:1410-1415 | M |
| D4 | Wild 复用 BR 淘汰：8 Bot 死后阔野被结算锁死 | main.gd:611-638,466-471,642-663 | S |
| D5 | 骑乘死亡未 exit，下帧被拉回座位 invisible/no collision | player.gd:1110-1128；main.gd:642-663；horse.gd:363-402,526-528 | S |
| D6 | 血月 _enemy_near 不判类型，异类抑制指定类型 | wild_world.gd:993-1057 | M |
| D7 | 血月遗漏类型（Stal/Keese/Wizzrobe/Chuchu/Hinox/Flyer/Dragon） | wild_world.gd:996-1057 | M |
| D8 | Bot 只找 weapon 不找 ammo，空匣哑火 | bot.gd:355-367,590-595；weapon.gd:98-103 | M |
| D9 | Projectile source 悬垂 6s | wild_projectile.gd:9,101-115 | M |
| D10 | 物理错位：倒木碰撞竖直、守卫强写 terrain y 覆桥 | wild_world.gd:1191-1206；guardian.gd:304-306 | M |

近期 Tech 复审 5.3 与本轮 4.5 交叉验证，`ISSUES` 保持唯一真实来源。

## 本轮增量4（Game Design@gpt-5.6-sol 5.1/10，11项，2 critical）

> 基线 fadf566，已含 22 项修复；本审计覆盖野取证+运行探针。

| # | 标题 | Sev | 证据 | 状态 |
|---|------|-----|------|------|
| G1 | Wild 终局3重冲突：无限重生+最后存活胜利+巨龙终局互斥，8 Bot死后锁死 | main.gd:620-663,768-784 探针 match_over=true | S 待修 |
| G2 | 零存档2小时无承接（与 Systems 一致） | player.gd:26-133 main.gd:65 | XL 待存档服务 |
| G3 | 背包 +6 vs 10 已在 f9bd405 修，但需回归 | player.gd:1890 | 已修待锁回归 |
| G4 | InputMap 0消费者 | project.godot:27 vs player.gd:203 | L 待迁移 |
| G5 | Battlefield 192s + 决赛圈停伤 | zone.gd:7-13,78-80 探针5s后HP=100 | M 待圈重调 |
| G6 | 无世界地图仅 164点阵 | hud.gd:132,759 main.gd:863 | L 待地图 |
| G7 | Guardian 每帧清零永不发射 | guardian.gd:264-283 探针5s HP=100 | S 本轮已补 |
| G8 | 成长数值近战/HUD不一致 | player.gd:1011,1520 hud.gd:248 | M 待 CombatStats |
| G9 | 三枪 TTK 0.89/0.80/0.83 趋同 | weapon.gd:14 | M 待差异化 |
| G10 | IP 风险 XL | README.md:1-3 | XL 需原创化 |

score 5.1，三轨音乐/据点/Bot/医疗等 6 项已闭环不重复计分。

