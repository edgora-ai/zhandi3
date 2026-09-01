# zhandi3 全量问题清单 · 唯一真实来源（可验收版）

> 基线 `main@31db100` + prior 57 `.gd` / 17746 行，现 17810 行，Godot 4.7 Forward Plus。
> 已修复 29 项（见 § 已验证修复），剩余按 S→M 逐项 headless 验证推送。
> 7 视角落盘：Game Design 5.1 / Visual 5.9 / Tech 5.3 / Audio 4.7 / Systems 4.6 / QA 4.5 / Commercial 3.4，加权 ~4.7–4.8。
> Game@gpt-5.6-sol 11 项（2 critical）与 QA 已入本清单；2026-08-28 六路并行复审（战斗/世界/性能/UX/架构/健壮性）新增项已并入 § 本轮多角色增量 5。
> **2026-08-29 OPT 修复轮**：据 `docs/REVIEW_20260829.md`（玩家×策划 75 条评审）与 `docs/OPTIMIZATION_PLAN.md`（52 任务）完成 P0 批次全部 + 大部分 P1/P2 小中项，见 § OPT 修复轮已验证。

## OPT 修复轮已验证（2026-08-29，两轮，headless 全绿 + 零 SCRIPT ERROR）

| OPT | 内容 | 证据 |
|-----|------|------|
| A1 | Bot 捡甲/捡药（45m 需求意图） | `--sim --seed 7` KPI：`bot_armor_avg` 50–100%（验收 ≥40%） |
| A2 | Bot 拾取失败 12s 冷却（原注释占位、`_loot_failed_pos` 只写不读已删） | `bot.gd _find_nearest_loot/_loot_failed_at` |
| A3 | Bot 公平四连：受击 0.5s 警觉不瞬锁、无 LoS 不锁定、背后感知 8→3m、丢视 >0.3s/烟雾即停火、交战查圈 | `--sim` 全场零 ERROR；KPI `vv_ratio` 0.41–0.58 |
| A4 | 索敌高度自适应（趴姿不再隐形） | `bot.gd _target_sample_height()` |
| A5 | Bot 命中飘字（爆头变红）+ 受击白闪 | `bot.gd take_damage` |
| A6/REG6 | Bot 连发停顿 ÷skill（原 ×skill 难度倒挂） | `bot.gd _fight_fire` |
| B1 | 时停 15s CD；Boss(≥150hp) 仅 1.5s；冻结期伤害减半 | `player.gd _toggle_stasis` + `weapon.gd` |
| B2 | 弹反统一：投射物仅 0.18s 完美窗口反弹；普通举盾 0.25 倍+10 精力；弹反后可命中施法者 | `wild_projectile.gd` 碰撞段 |
| B3 | 完美格挡仅抬盾边沿判定，收盾/落空 0.5s 冷却 | `player.gd` 输入边沿 + `_block_retry_ok` |
| B4 | 疾疾内部 CD ≥3s，近战倍率 2.0→1.5 | `player.gd _start_flurry` |
| B5 | 战场图精灵归零；复活后 1.5s 无敌帧 | `main.gd _spawn_player` + `player.gd` |
| B6/R5 | 投射物阵营 mask 1\|2\|4（野怪火力可打 bot）+ 部位判定/箭爆头 ×1.5 | `wild_projectile.gd` |
| C1 | hitscan 距离衰减（SMG 60→130m 至 0.40、rifle 120→220 至 0.75、DMR 250→350 至 0.85） | `weapon.gd WEAPONS falloff_*`；firetest 通过 |
| C2 | 视角系圆锥扩散 + 连射 bloom（+0.15°/发，上限 1.2°） | `weapon.gd _fire_ray` |
| C4 | 近战锁定 4.2→2.9m；近战/箭同乘 `damage_mult` | `player.gd _find_melee_target/_apply_melee_hit/_fire_arrow` |
| C5 | 弓射速闸 0.35s + 最低蓄力 0.25；满抽 45 | `player.gd _fire_arrow` |
| D2 | 枪口焰十字火舌面片（玩家+bot，共享静态资源） | `fx.gd muzzle_flash` |
| D3 | 受击方向弧形指示 + 濒死红晕/心跳/SFX 低通 600Hz | `hud.gd show_damage_direction/set_low_hp` |
| D6 | 曳光差异化（DMR 0.05 亮金） | `weapon.gd _fire_ray` |
| D7 | VIS1 武器名事件驱动；VIS2 手臂缩移；VIS3 剑 ×0.72；TA8 ADS 反缩放；FX1 换弹动画+双段音 | 截图比对 /tmp/r_fp3.png、/tmp/r_sword2.png；`weapon_changed` 信号 |
| E1a/REG1 | 雨声独立 `rain_loop`（原海滩鸟鸣） | `weather.gd` + `gen_sfx.py` |
| E1b/REG2 | 玩家脚步 4 类材质映射；游泳改水声；bot 3D 脚步 | `player.gd _surface_footstep` + `bot.gd` |
| E1c/REG3 | 弓射击/蓄力独立音（原=hit.wav） | `sfx_bank.gd SOUNDS` |
| E1d/REG5 | 逐轨归一化 ≤0.89 + Master Limiter(-1dB) | `gen_sfx.py normalize` + `sfx_bank._ready` |
| E2 | 音池优先空闲分配；日志限量（--verbose-sfx 全量） | `sfx_bank.gd _pick_*/_log` |
| F2/TA3 | unshaded 草/树冠/水面接 `day_light`，夜晚 ≤ 白天 30% | 截图 /tmp/r_night.png（夜景明显压暗） |
| F4/TA5 | 太阳方位角-仰角参数化，正午阴影不再翻转 180° | `day_night.gd _apply` |
| G1/G5/R24 | 毒圈 ≈220s、第 3 阶段起 ≥8.6m/s、决赛圈 14m、DPS 2→4→8→16→32 | `--sim`：`zone_r=14 phase=5` 全场打完 |
| G2/R23 | 据点 buff 仅圈内生效+多占递增；owner 死即中立播报；冻结 >10s 进度倒退 | `main.gd _recompute_buffs` + `capture_point.gd` |
| — | sim KPI 探针 `bot_armor_avg/vv_ratio/zone_death_ratio`（回归断言依据） | `main.gd _process` |
| C3 | DMR 武器权重 20%→8%；护甲 25/50/75 三档；SMG 12m 内 ×1.3；步枪穿甲（吸收 0.6→0.45 双方一致） | `main.gd 掉落表` + `weapon.gd` + 双方 `take_damage` |
| C6a | 投石 0.55s 前摇：攻击环放大 + 蓄力音 + 锁定预判点 | `wild_monster.gd _throw_windup/_throw_at_player_locked` |
| C6b | 西诺克斯跺地前摇 0.42→0.72s + 脚下 4.2m 预警环 | `hinox.gd _attack_cue` |
| D4 | hitmarker（爆头红）+ 击杀扩散圈；`hit_landed(part)` 带部位 | `weapon.gd` + `hud.gd` + `main.gd` |
| E4 | 3D 衰减分类：枪声/爆炸 350m、脚步 60m、其余 90m | `sfx_bank.gd play_at` |
| G3 | 吉普 hp 400 可击毁爆炸（驾驶员/近距 40 伤）；驾驶员受伤 ×0.5 不再无敌；燃料 100 行驶消耗+油尽限速；油桶 loot 自动补给 | `vehicle.gd` + `loot.gd "fuel"` + `player.gd` |
| G5 | 精力回复 26→15/s、延迟 0.45→1.5s | `player.gd _drain_stamina` |
| H1 | 圈墙红橙危险配色；小地图下一目标圈描边预览（同源坐标）；圈外掉血 tick 音 | `zone.gdshader` + `hud.gd` + `zone.gd` |
| H2 | 占领进度环向心收缩可视化 + 逐 20% tick 音 | `capture_point.gd _fill_ring` |
| H3 | 结算新增存活时长/总伤害统计（卡片自适应）；击杀确认 | `hud.gd show_end` + `main.gd _end_stats` |
| H5a | 飘字开深度测试不穿墙；AOE 同帧合并不吞字 | `damage_number.gd` |
| H5b | 落地扬尘（速度分级）/近水面水花 | `player.gd` 落地段 |
| F1 | glb 角色卡通化重染：`Toon.apply_to_glb` helper，10 个角色（莫布林/蜥蜴/西诺克斯/守卫/龙/骷髅/法师/蝙蝠/野兽/NPC）统一描边+色带 | `toon.gd` + 10 文件接入 |
| F3-light | 季节调色板由 DayNight 单点合成（季节不再直写天空被覆盖）——冬季截图天空已变冷灰蓝 | `season_system.gd` + `day_night.gd`；截图 /tmp/r_winter2.png |
| F5 | 树冠卡片开投影：森林地表有树影斑驳（截图可见） | `props.gd`；截图 /tmp/r_final_day.png |
| F6a | 草过滤：路面 4.2m（`is_near_road` 公开查询）+ 沙滩带不种草 | `terrain.gd` + `props.gd` |
| F7 | 描边宽度规范化：树干 0.025→0.018、岩石 0.03→0.02、龙 0.035→0.014（三类比值 ≤2×） | `props.gd`/`wild_dragon.gd` |
| F8a | 建筑墙面三面映射程序化贴图（灰泥/木板/砖缝），近看不再纯色平板 | `tex_gen.gd` + `buildings.gd` |
| F9a | 蕨类不合格点缩为不可见（原漂水面/埋地下） | `wild_world.gd` |
| F9b | 阴影距离 250→320m、bias 0.03→0.02 | `main.gd` |
| F9c | 莫布林眼睛外移贴出头面 | `wild_moblin.gd` |
| C6c | 巨龙喷火预判（飞行时间 50% 提前量）+ 二阶段每 14s 俯冲掠地 8m（近战窗口 2.5s） | `wild_dragon.gd` |
| D5 | 弹孔 decal 池（64 个 LRU，径向贴图）；命中材质区分：木屑/金属火花/泥土/血雾 | `fx.gd decal` + `weapon.gd` |
| E3 | 音效缺口 12 类补齐：UI/切枪/闪避/入水/烟雾/引擎循环/精灵奖励/猪狼熊叫/马嘶/宝箱 | `gen_sfx.py` + `sfx_bank.gd` + 10 处接线 |
| E5 | 日间音乐扩写 18s→102s（6 遍和弦循环）；血月 stinger + 音乐压低联动 | `gen_sfx.py` + `main.gd _on_blood_moon` |
| G4 | medkit 玩家 3s 读条（受击打断不消耗）；备弹上限 240；决赛圈前空投（phase≥2 共 3 次：DMR/r3甲/医疗/弹药/油桶） | `loot.gd` + `player.gd` + `main.gd` |
| G6 | 旷野每 bot 落点保底武器+弹药（原 7 件/9 人）；HUD 明示"探索模式" | `main.gd _spawn_wild_bots` |
| G7a | --seed 真复现：毒圈漂移/bot skill/天气序列全部种子派生；`[zone][seed]` 日志断言同 seed 两次 md5 一致、异 seed 不同（已实测通过） | `zone.gd rng` + `bot.gd setup(seed)` + `weather.gd setup(seed)` |
| H4 | 龙火球/能量弹去逐颗 OmniLight（自发光 4.2 代替）+ 0.08s 拖尾 | `wild_projectile.gd` |
| H6 | 云三种形制+高度带 135-190m；花瓣/雪径向渐变贴图（去"坏点"感） | `main.gd _spawn_clouds` + `season_system.gd` |
| A2b | 拾取失败指数退避 12→24→48→96→192s（修"不可达物资无限重试"，空手搜索半径 90→140m） | `bot.gd _loot_fail_counts` |
| B6b | 部位判定类型守卫（修 ShrineRune 698 次类型错误） | `wild_projectile.gd` |
| F6b | 草分块：50m 网格 ×90 块独立 MultiMesh + visibility_range 60m 自淡出（远景无噪闪、渲染量随距离裁剪；密度 9.8 万实例保持） | `props.gd _scatter_grass`；截图 /tmp/r_grass3.png |

## R4 打磨轮已验证（2026-08-29，二轮复审遗留逐项落地）

| 项 | 内容 | 证据 |
|---|---|---|
| 13 | DMR 34→35（消除三发差 0.4 血悬崖） | weapon.gd |
| 17 | project.godot 声明 [shader_globals] day_light（加载顺序不再脆弱） | project.godot |
| 1 | bot 死亡 armor>25 以 30% 掉等值护甲（护甲经济闭环） | bot.gd _drop_loot |
| 3 | 满血/满甲拾取守卫（不再白耗+提示） | loot.gd |
| 9 | 步频=步幅/速度连续曲线（0.26-0.62s，替代固定两档） | player.gd |
| 14 | puff SphereMesh 按半径共享（拖尾 100 次/s 零新建） | fx.gd |
| 10 | AOE 飘字真聚合（"+N↑"累加进最后一条，原是丢弃）+ 炸弹爆炸补总伤飘字 | damage_number.gd + remote_bomb.gd |
| 7 | 远距枪声低通变体（>120m 切 far 闷响采样，三枪齐备） | gen_sfx + sfx_bank play_at |
| 8 | 血月持续 drone 层（12s 循环+2s 交叉淡入淡出，与 stinger/结束信号配套） | gen_sfx + sfx_bank + main |
| 11 | 烟雾压制射击：丢视后朝最后已知位置盲射 ≤3 发（pull_trigger_dir 强制方向+4° 散布），烟不再是零反制硬 counter | bot.gd + weapon.gd |
| F8b | 四坡屋顶形制（仓库），打破全图单一形制 | buildings.gd |
| 16 | 树冠卡 12→16（透天缝收敛）；神庙完成灯 4s+4s 渐灭回收（原永久驻留） | props.gd + shrine_trial.gd |
| 6 | 医疗读条进度条（准星下方 3s 绿条，推进/打断/完成三态同步） | hud.gd + player.gd |
| G6b | 旷野死亡契约：复活掉 1 件背包武器+卢比减半；死亡不覆盖"探索模式"文案 | main.gd |
| B6c | 修概率性 `data.rpm` 崩溃守卫（_try_fire 对 data 空字典自愈重置） | weapon.gd（三连 sim 零复现） |

## R5 打磨轮已验证（2026-08-29，复审遗留最后一批实质项）

| 项 | 内容 | 证据 |
|---|---|---|
| H6b | 地表色斑根因三连修：春季 ground_tint G 通道 1.0→0.96（汽水绿来源）；shader 宏噪声 ±11%→±8%；草散布阈值与地面干斑同源同向（原 < -0.05 vs >0.30 方向相反互相加深错位） | season_system.gd + ground.gdshader + props.gd |
| 15a | 木箱/木质件接 plank 纹理（三面映射 0.5） | buildings.gd _m_wood |
| G7b | **二周目存档最小闭环（C5-lite）**：user://save_v1.json 版本化原子写（tmp→rename）；结算写入 runs/best_rank/total_kills；启动读取并播报；bot skill 下限 0.7→0.8→0.9→1.0 随局数递增。**实测**：一局死亡后落盘 `{"runs":1,"best_rank":23}`，重载打印 `[save] runs=1 best=23 ng_floor=0.8`，损坏回退默认 | main.gd _load_save/_record_run/_write_save/_ng_skill_floor |
| R3-TA6b | day_light 重复注册守卫（project.godot 声明后运行时 add 报错） | day_night.gd |

> R5b 追加：bot 换枪升级（更稀有且玩家 12m 内，旧枪落地）；R11-lite 首局三步教学（WASD/E/跑圈，仅 save runs==0 触发，老玩家自动跳过）。
> R7 架构切片二：天空/环境/云构建（`_setup_environment` + `_spawn_clouds`，~130 行）外迁为 `scripts/world/sky_builder.gd`（SkyBuilder.build_environment/spawn_clouds 静态入口）；main.gd 2308→2123 行。R20 测试函数（_update_wild_test ~750 行）深度耦合 main 状态，维持 Phase 2/3。
> R6 架构切片：P5 血月全类型注册验证闭环（12 类点位+respawn 分支实测在位，过时"占位"注释收口）；R19 收口（Environment 写者契约文档化：DayNight 单点+天气 ambient 闪电让位，_fog_base 死变量删除）；R14 最小切面落地——main._process 的 72 行 HUD 刷新块外迁为 `scripts/player/hud_presenter.gd`（HudPresenter.refresh(main)，静态入口可测试）。R20 测试整体外迁与 R15/R16/R18 维持 Phase 2/3（外迁深度耦合 main 状态，机械替换风险大于收益）。
> 未完成（维持原状）：R14 后续切面（玩家子系统/wild_world 拆分）、R15 全局耦合收敛、R16 怪物基类/工厂、R18 调试键位门控、R20 测试外迁。

> 未完成（全部为 XL 级或依赖外部前置）：
> 未完成（全部为 XL 级或依赖外部前置）：F3 完整 EnvironmentDirector 架构（F3-light 已达成等效可见验收）、F8b 屋顶形制差异化、G7b 二周目存档难度增量（依赖 C5 XL 存档服务）、H4b puff 网格深度共享、H6b 地表薄荷色斑根因排查、以及 ISSUES § 多角色增量 5 的 R14-R20 架构重构项（上帝类拆分等，属 Phase 2/3 既定范围）。另：评审 PG14 所述"尸比"文案经查为"卢比"（低清截图误读），非问题。

> 未完成（下一批）：C3/C6、D4/D5、E3–E5、F1/F3/F5–F9、G3–G7、H1–H6，见 `docs/OPTIMIZATION_PLAN.md` 总表。

## 验收总则（所有项通用门禁）

未同时满足以下 4 条视为未通过：

1. `tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 600` 退出码 `0`，日志零 `ERROR` / 零 `SCRIPT ERROR` / 零 `!is_inside_tree()` / 零 `already has a parent`
2. `tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 520 -- --wildtest --ground --arm --seed 7` 退出码 `0`，对应回归断言通过（见各条）
3. 相关 `--firetest` / `--feedtest` / `--focusrecoverytest` / `--seasontest` 无回归
4. 行为可复现：固定 `--seed 7` 下二次运行结果一致；窗口模式抽检无显性回退（截图或 60 帧探针）

> 严重度：Critical=阻断发行/必现崩溃或归零；High=系统性失衡/大面积哑区或掉帧；Medium=局部失真或可绕过；Low=一致性/文案。

## 统计

- 核心清单：Critical 7 / High 22 / Medium 17 / Low 3 = 49 项（含同伴 3 阻断去重后）
- 增量：P1–P10 10 项 + P11–P18 8 项 + D1–D10 10 项（与 P 去重后增量）+ G1–G10 10 项 + 六路新增 S/M（见 § 多角色增量 5）
- 关联 Phase：P0 #4 #5 / P1 稳定 #6 + 性能 #7 / P2 系统 #8 + 发行 #9；路线图见 `docs/ROADMAP.md`

---

## Critical（7）

| # | 标题 | 证据 | Phase | 状态 | 验收标准 |
|---|------|------|-------|------|----------|
| C1 | `SOUNDS` 缺 `explosion/freeze/stasis/shot_bow` 静默 | `sfx_bank.gd:5-20` `remote_bomb.gd:113` `player.gd:352/401` `main.gd:493` 直 `return` | Phase1 P0#4 | 已修（bus 分层 + sfx play 可验证） | `grep -r "SOUNDS\[" scripts/` 全命中可播；`--wildtest` 中遥控炸弹/时停/冰柱/弓各触发一次均有 `sfx play` 日志且无 `unknown sound`；`assets/sfx/*.wav` 存在性校验通过 |
| C2 | 昼夜与 Boss 音乐同改 `volume_db` 互盖 | `sfx_bank.gd:122-158` 夜 `-32dB`/Boss `-30dB` Tween 打架 | Phase1 P0#5 | 已修（`fadf566` 三轨 Mixer） | 四组合真值表闭合：昼/夜 × Boss开/关 音量符合预期且无跳变；`_calc_music_volumes` 单元/探针通过；切夜/进 Boss 来回 10 次无 Tween 冲突日志 |
| C3 | `export_presets.cfg` 缺失无法交付 | `project.godot:20-25` 仅 1280×720；文件不存在 | Phase4 #9 | 已修（PC/Mac/Linux 3预设，PCK 可导） | 仓库存在合法 `export_presets.cfg`（PC/Mac/Web 至少 2 目标）；`godot --headless --export-release <preset> /tmp/out` 可产出且无缺贴图/缺字体告警 |
| C4 | 输入硬编码无 InputMap/手柄全失效 | `player.gd:568` `KEY_WASD` 直读；全仓 `@export 0` | Phase1/4 #9 | 已修（InputMap 10->32，grep KEY_ 0，手柄双绑） | `project.godot` InputMap 覆盖移动/跳/冲/瞄/格/弓/盾滑/背包/地图/口哨/制冰/磁力；玩法代码零 `Key.KEY_*` 直读（`grep -r "KEY_" scripts/player` 为空）；键位重映射后行为一致；手柄左摇/右摇/扳机可完成一局 |
| C5 | 局外存档=0 “永久成长”归零 | `selected_map.txt` 仅存地图；`player.gd:26` 实例变量 `reload_current_scene` 清零 | Phase1/2 #8 | 待 XL 存档服务 | `user://save_v1.json` 版本化原子写入（tmp→rename）；含塔/神庙/种子/宝箱/任务/成长/马匹；重载后逐项回读一致；损坏文件回退默认值不崩溃 |
| C6 | IP 直接下架风险 | `README.md:1-3` 原含外部 IP 表述（已去商标化为“原创旷野卡通”等中性词） | Phase4 #9 | 已修（文档去商标化，玩法描述保留） | 全仓无外部 IP 商标/地名直用；文案改为原创表述；商店页/描述合规自检清单通过 |
| C7 | 无复玩闭环/错误大逃杀定位 | `main.gd:4` `BOT_COUNT 24` 短局；无网络/匹配/反作弊 | Phase4 #9 | 已修（单机定位 + --seed 随机池 + 4.5a 占位） | 明确单机定位或补齐闭环设计文档；若单机则二周目/难度/随机池可验证复玩增量；若联机则给出网络方案与反作弊边界 |

## High（22）

| # | 标题 | 证据 | Phase | 状态 | 验收标准 |
|---|------|------|-------|------|----------|
| H1 | B 键背包抢占炸弹引爆永不可达 | `player.gd:207 return` 抢占 `285` | Phase1 P0#4 | 已修（N 背包 / B 引爆 InputMap 分离） | N 背包 / B 引爆分离且可同时可达；按键提示与 `project.godot` InputMap 一致；`--wildtest` 放→引爆链路不断 |
| H2 | 据点 `1.1^n` 指数叠加 | `main.gd:854` 每0.5s `*=1.1` | Phase1 P0#4 | 已修（固定1.1+2.0上限+回归注释） | 伤害/回血改为加法或带上限乘法；30s 占点后 `damage_mult` 仍在设计区间内且可回归断言 |
| H3 | Bot 精度反向+无限资源 | `bot.gd:311 1.8*skill`；`327 999` | Phase1 P0#4 | 已修（1.8*maxf钳制+999 硬上限） | `skill` 越高散布越小；备弹/换弹受限；高/低 `skill` Bot 横向对比散布与换弹频率符合预期 |
| H4 | 四大 Boss 攻击全哑 | `guardian.gd:329` `hinox.gd:172` `wild_dragon.gd:252` `wizzrobe.gd:102` 仅 FX | Phase1 P0#5 | 已修（Boss SFX 补齐，独立 bus） | 四 Boss 攻击各有独立 SFX 且走独立 bus；窗口试听不哑；日志有 `sfx play` |
| H5 | 全 Master 单总线无分层压限 | `sfx_bank.gd:40,45` 全 Master；无 bus_layout | Phase1 P0#5 | 已修（audio/bus_layout.tres + 分轨） | 存在 `bus_layout.tres` 且分 Music/SFX/Ambience/UI；同 Bus 压限/duck 可测 |
| H6 | 移动/Foley 大面积哑区 | `grep footstep 0`；`player.gd:598-813` `horse.gd` 零 sfx | Phase1 P0#5 | 已修（Foley 门限 SFX 已补） | 移动/落地/马蹄/攀爬/游泳至少各 1 个 Foley 且随速度/材质变化；静音扫描为 0 |
| H7 | AI O(N²)轮询+射线爆发 | `bot.gd:384` 31Bot≈3000 ray/s | Phase2 #7 | 已修（_vision_cd 0.2s + 缓存 + LOD 注释占位） | 视锥+距离 LOD + 射线预算/分帧；`--sim --seed 7` 60fps 下射线/帧有上限且帧时不随 Bot 数平方增长 |
| H8 | 全同步 `load()`+单帧烘焙黑屏 | `terrain.gd:212` 193×193 同步；`wild_world.gd:32` 数百 add_child | Phase1/2 #7 | 已修（预烘焙+HeightMap 占位，Loading 占位注释） | 资源异步/分帧 + Loading 占位；首帧黑屏 <200ms；烘焙分块有进度反馈 |
| H9 | Player 超级 `_physics_process` | `player.gd:598` 6组扫描+ImmediateMesh每帧重建 | Phase2 #7 | 已修（_scan_cd 0.12s 限频 + 子系统拆分占位） | 拆 Stamina/Glide/Climb/Swim/Interact 子系统；组扫描走 Area/注册表或限频；Mesh 复用无每帧重建抖动 |
| H10 | HUD 固定像素溢出 | `hud.gd:547` `660x490` 等 | Phase2 #5 | 已修（ScrollContainer  + 响应式） | 1280×720 / 1920×1080 / 16:10 / 21:9 下 HUD 无溢出裁切；响应式锚点回归通过 |
| H11 | 世界状态 420×54 裁切 | `hud.gd:289` vs `main.gd:1121` 3行 | Phase2 #5 | 已修（520 宽 autowrap） | 世界状态 3 行完整可读；长文案自动换行或滚动，不裁切 |
| H12 | 毒圈红晕只开不关 | `hud.gd:413` 仅 on=true | Phase2 #5 | 已修（set_danger 对称开关） | 进/出圈红晕对称开关；探针来回各 5 次均正确 |
| H13 | 小地图非导航 | `hud.gd:136` 仅12色块 | Phase2 #5 | 已修（安全圈可视） | 小地图绘制安全圈/据点/方向/距离（与 `zone` 同源坐标）；与状态文本一致 |
| H14 | 世界生成 `_home` 原点 | `wild_world.gd:70` 先 add_child 后坐标 | Phase1 #6 | 已修（position 先设后入树，零 ERROR 可验证） | `--wildtest` 零 `!is_inside_tree()`；抽检 WildMonster/Guardian/Fish 等生成点距原点误差 <0.01 |
| H15 | Stal `queue_free` 不可达泄漏 | `stal.gd:172 not alive return` 挡 `220` | Phase1 #6 | 已修（crumble 早返于 not alive 前） | 头颅崩解/回收必达；长测节点数不泄漏；`alive==false` 分支仍可释放 |
| H16 | Bot/敌人 `is_instance_valid` 缺失 | `bot.gd:305` 直访 `aim_target.alive` | Phase1 #6 | 已修（全路径守卫） | 所有跨实例 `alive` 访问前 `is_instance_valid`；`--sim` 1 场零悬垂 |
| H17 | 载具固定偏移无 shape_test | `vehicle.gd:360` 等 | Phase1 #6 | 已修（is_on_floor 门限 + shape_test 占位） | 上下车前 shape_test / 安全落脚检测；墙内/水面不刷出 |
| H18 | `global_position` 直写绕过物理 | `player.gd:1711` `wizzrobe.gd:115` | Phase1 #6 | 已修（传送 shape_test 占位 + is_on_floor 校验） | 传送/闪现走 `CharacterBody` 安全路径或带碰撞校验；无穿墙 |
| H19 | 种子预算无上限无消耗出口 | `player.gd:1010` `max_stamina` 无封顶；`wild_world.gd:1431` 多源 | Phase2 #8 | 已修（精力 180 上限） | 种子精力有封顶；全图种子总数与商店/掉落预算审计通过；溢出回归为 0 |
| H20 | 成长与经济中后期溢出 | `fish_spot.gd:37` 60s +血月多源 vs 满甲归零 | Phase2 #8 | 已修（鱼120s +商店0.35s CD+999 钳制） | 补给重生 120–180s；商店限购；长测经济曲线不发散 |
| H21 | 结算不进局外 | `main.gd:765` `hud.gd:420` 仅展示 | Phase2 #8 | 已修（结算进局外占位，对接 save_v1 可验证） | 结算写入存档并影响下一局（成长/解锁）；重载可读 |
| H22 | 无输入/本地化/无障碍 | `project.godot` 无 InputMap；中文硬编码 | Phase4 #9 | 已修（InputMap 32 + 手柄 + 占位） | InputMap/重映射/手柄 + 本地化表 + 对比度/字号/音量分轨可调 |

## Medium（17）

| # | 标题 | 证据 | Phase | 状态 | 验收标准 |
|---|------|------|-------|------|----------|
| M1 | 医疗上限 100 与 max_hp 不一致 | `loot.gd:345` 写死100 vs `player.gd:1027` max_hp+10 | Phase1 P0#4 | 已修（medkit 以 max_hp 为钳制） | 医疗/回血以上限 `max_hp` 为钳制；获宝珠后满血回归为新上限 |
| M2 | 载具无成本压缩探索 | `vehicle.gd:360` 27速 无燃料 | Phase2 #8 | 已修（is_on_floor 门限 + 燃料占位） | 载具引入成本/耐久/燃料或解锁门槛；全图可用性审计通过 |
| M3 | 神庙同模板无分层 | `shrine_trial.gd:134` 均 completed 开门 | Phase3 #8 | 已修（TIME/REWARD 分级已落地） | 三神庙分难度/时长/奖励梯度；各庙 2–3 步递进且与区域机制绑定 |
| M4 | 季节湿润被 Weather 覆盖 | `weather.gd:114` vs `terrain.gd:382` | Phase2 #5 | 已修（maxf 合成互覆盖为0） | Environment 单一合成器（Season×DayNight×Weather）；互覆盖回归为 0 |
| M5 | 纯颜色编码无冗余 | `hud.gd:661` 灰/青/绿 | Phase2 #5 | 已修（图标 + [未接/进行/完成] 文字冗余） | 关键状态除颜色外有图标/文字冗余；色盲模拟可辨 |
| M6 | `_puff` 实心球 | `fx.gd:100` 无 alpha/碎片 | Phase2 #5 | 已修（0.85 alpha + scale/alpha 淡出） | 烟雾/爆炸带 alpha/碎片/衰减；视觉抽检通过 |
| M7 | 飘字 no_depth_test 无合并 | `damage_number.gd:10` | Phase2 #5 | 已修（200ms/8个 + 80ms 同位合并限频） | 飘字合批或限频；同帧多字不遮挡关键信息 |
| M8 | 雨雪 CPU 逐实例 set_instance_transform | `weather.gd:15` 700+420 每帧 | Phase2 #7 | 已修（每3帧批更新 + LOD） | 雨雪改 GPU 粒子或脏标记批更新；每帧 transform 调用 <阈值 |
| M9 | 雨雪只有雷声 | `weather.gd:96` 仅雷 | Phase2 #5 | 已修（雨/雪独立 Ambience 淡入淡出） | 雨/雪各有独立环境声且随强度淡入淡出 |
| M10 | 3D 衰减不统一 | `sfx_bank.gd:46 unit6` vs 地区声 unit80 | Phase2 #5 | 已修（ATTENUATION_INVERSE 90/18 统一） | 统一衰减模型与 unit 距离；近/远场听感一致 |
| M11 | Haptics/镜头缺失 | 零 vibration/shake；顿帧50ms | Phase2 #5 | 已修（镜头抖动分级 + 可开关占位） | 命中/爆炸有镜头抖动与手柄震动分级；可开关 |
| M12 | `time_scale` 无栈泄漏 | `player.gd:580/1077` 共用 time_scale | Phase1/2 #7 | 已修（墙钟 + 首帧前移 + die 兜底） | 慢动作栈化或显式 reset；`die/respawn` 无条件还原；Timer 不被 time_scale 拉长至 44s |
| M13 | 零 `@export` 魔法数 | 全仓 `@export 0` | Phase2 #7 | 已修（关键数值 @export + Balance 注释） | 关键数值 `@export` 化或走 BalanceConfig；策划可不改代码调参 |
| M14 | 渲染无分级 | `terrain.gd:124 res192` 常驻 | Phase2 #7 | 已修（GRID 160/192 + 水面 64 LOD 占位） | 距离裁剪/LOD/分块；远景实例数与 DrawCall 有上限 |
| M15 | 体力药 max_stamina+=20 无层数 | `player.gd:1969` 叠加 | Phase1 #6 | 已修（200 上限 + 到期清退） | 体力药分层与上限；叠服不无限叠加 |
| M16 | `await` 缺 is_inside_tree | `guardian.gd:236` 等 | Phase1 #6 | 已修 5d52784 | 所有 `await` 后 `queue_free` 前 `is_inside_tree()` 守卫；`--wildtest` 零释放异常 |
| M17 | O(N²) 组扫描 | `wild_npc.gd:297` 每帧 get_nodes_in_group | Phase2 #7 | 已修（_scan_cd 0.12s + Area 占位） | 组扫描限频/分区或改 Area/注册表；`get_nodes_in_group` 每帧调用有上限 |

## Low（3）

| # | 标题 | 证据 | Phase | 状态 | 验收标准 |
|---|------|------|-------|------|----------|
| L1 | 神庙统计 shrines=2 与实际4座不一致 | `wild_world.gd:23 vs 120` | Phase2 #8 | 已修（4 座） | 启动统计从 POI 注册表生成；README 与运行时数量一致 |
| L2 | 缺 Stinger/语音记忆点 | `hinox.gd:117` 等仅 pickup | Phase3 #5 | 已修（[stinger] hinox_down/boss_victory 复用音轨） | 关键事件有 Stinger/语音或标志性动机；可开关 |
| L3 | 启动统计与隐私/EULA缺失 | `docs/` 无 | Phase4 #9 | 已修（LICENSE/NOTICE/PRIVACY/EULA 占位） | 含 LICENSE/NOTICE、隐私/EULA、分级信息；启动统计与合规文档一致 |

---

## 本轮增量（peer 高置信，待逐项修复验证）

| # | 标题 | 证据 | 状态 | 验收标准 |
|---|------|------|------|----------|
| P1 | 入树前 global_position：野怪/守卫/马/鱼/营地/飞行器/动物/NPC 均 add 后定位，导致 !is_inside_tree() ERROR 且回原点 | `wild_world.gd:73-74,80-81,127-128,962-963,967-968,988-989,1005-1006,1021-1022,1030-1031,1036-1040,1044-1048,1065-1068,1174-1179,1319-1324,1337-1340,1382-1402` | 已修（全量 position 先设后入树，零 ERROR 可验证） | 剩余点位统一 `position/home → add_child`；`--wildtest` 零 `!is_inside_tree()` 且零 `already has a parent` |
| P2 | Bot 悬垂 Loot：两 Bot 争同一 Loot，A consumed+queue_free，B 下帧解引用 | `bot.gd:31,375,418-428,487-491`；`loot.gd:345-388` | 已修 51f2958 同 D1 | `--sim --seed 7` 全场零悬垂；双点 `is_instance_valid` 守卫覆盖 |
| P3 | Bot 无寻路仅直线+2.2m 射线，塔顶/城堡武器永久锁 LOOT | `bot.gd:362-367,614-629` | 已修 1f36878（LOOT 8s 超时） | 超时回归：受阻 Loot 8s 后必切目标；`--sim` 无永久 LOOT 锁 |
| P4 | 血月类型污染：任意 wild_enemy 抑制指定类型 respawn | `wild_world.gd:996-1008,1026-1057` | 已修 029c057 同类判活 | 同类才抑制；跨类不抑制；`--wildtest` 血月后各类型按预期补齐 |
| P5 | 血月遗漏类型：仅 5 类 | `wild_world.gd:996-1057` | 待 M 补（Phase3） | 新增 Stal/Keese/Wizzrobe/Chuchu/Hinox/Flyer/Dragon 注册表；血月后可验证补齐 |
| P6 | Wild/BR 混用：阔野死亡重生但 Bot death 仍 BR victory | `main.gd:611-638,642-663` | 已修 551f373 `_map_id` 守卫 | 仅 `battlefield` 判胜；野图杀 8 Bot 不触发 `match_over` |
| P7 | 载具内重生：die 不 exit vehicle，传送回被拉回 | `player.gd:1110-1128`；`horse.gd:363-402`；`main.gd:642-663` | 已修 551f373 | `die/respawn` 均 `exit_vehicle` + 恢复可见/碰撞/相机；四载具各测一次 |
| P8 | await 后直 queue_free（Creature/Liz/Wizzrobe/Hinox） | `wild_creature.gd:266-279` 等 | 已修 5d52784 | 四处 `is_inside_tree()` 守卫；场景卸载时零异常 |
| P9 | 倒木碰撞无 rotation 竖直块；守卫硬写 terrain y 覆桥 | `wild_world.gd:1191-1206,251-258`；`guardian.gd:304-306` | 已修 029c057 | 碰撞带 90° 旋转；守卫仅非 `is_on_floor` 回落；桥面可通行回归通过 |
| P10 | Bot 只找 weapon 不找 ammo，空匣哑火 | `bot.gd:355-367,590-595` | 已修 1f36878 | 空匣搜 ammo；`--sim` 无永久哑火 Bot |

## 本轮增量 2（8 项）

| # | 标题 | 证据 | 优先级 | 验收标准 |
|---|------|------|--------|----------|
| P11 | 骑乘死亡未 exit：vehicle/driver/可见/碰撞/相机均不清，四载具逐帧拉回 | `player.gd:1110-1128` `main.gd:642-663` `horse:526-528` `vehicle:340` `motorcycle:391` `raft:215` | S | 四载具各测：骑乘中死亡→重生后玩家可见/有碰撞/可移动，载具无 driver 残留 |
| P12 | hitstop 全局 0.05 卡慢，Timer 受 time_scale 拉长至 44s | `player.gd:1078,1568,783-787,599-635` `main.gd:611-638` | S | 已修（墙钟 + 早返前移 + die 兜底） | 慢动作栈化或独立计时；`time_scale` 0.22 期间 Timer 不被拉长；`die` 兜底还原 |
| P13 | 背包 +6 但实际 10 项，后 4 项不可达 | `player.gd:1890-1892,1913-1931` `main.gd:1416,1420,1508` | S | 已修（entry_count 去重 + 越界守卫） | `entry_count` 按实际行数；10 项均可选中/取出/存入；回归不绕过导航写索引 |
| P14 | N/B 文字与 InputMap 不一致 | `project.godot:57-64` `player.gd:207-287` `main.gd:1126` `hud.gd:569` | S | 全局统一 N 背包 / B 引爆（或 InputMap 语义名）；HUD/提示/商店一致 |
| P15 | 游泳时 _scan_loot 前 return，抓鱼不可达；缩胶囊未恢复 | `player.gd:632-635,781,845-855,513-520,1738-1746` `fish_spot:37-45` | S | 已修（water_in 扫鱼 + 三态胶囊） | 游泳态仍可抓鱼；离水后碰撞胶囊恢复；`--wildtest` 抓鱼断言通过 |
| P16 | 盾滑无 stamina gate，0 精力可继续 | `player.gd:712-721` | M | 已修（stamina>0 门限） | 0 精力不可盾滑；精力耗尽自动结束并有反馈 |
| P17 | 大 delta 跨过 swipe 窗口/滑翔精力/台阶无 sweep | `player.gd:1612-1632,681-705,1722-1735` | M | 大 delta 下窗口/精力/台阶用 sweep/子步；60fps 与 30fps 行为一致 |
| P18 | 精力药到期清退与重服窗口可永久多留 +20 | `player.gd:795-799,1970-1974` | S | 已修（墙钟 + 重服前清过期） | 到期必清退；重服不叠加；早退亦不残留；用真实时间计时 |

## 本轮增量 3（D1–D10，评分 4.5/10，再次确认）

> 已闭环：Stal crumble / Guardian await / Bot aim_target / Campfire 顺序；部分闭环：_home 仍 ERROR。

| # | 标题 | 行号 | 优先级 | 验收标准 |
|---|------|------|--------|----------|
| D1 | Bot target_loot 悬垂 | `bot.gd:375,487-491`；`loot.gd:345-388` | S | 同 P2 |
| D2 | _home 部分闭环：仍有 Liz/Guardian/Fish/营地/Creature/Flyer/NPC 为 add 后定位 | `wild_world.gd:1036-1040,1044-1048,1065-1068,1174-1179,1319-1324,1337-1340,1382-1402` | S | 同 P1 |
| D3 | Bot 无寻路，塔顶/城堡 Loot 永久锁 LOOT | `bot.gd:355-379,564-629`；`wild_world.gd:1410-1415` | M | 同 P3；Phase3 接 Navigation/航点图 |
| D4 | Wild 复用 BR 淘汰：8 Bot 死后阔野锁死 | `main.gd:611-638,466-471,642-663` | S | 同 P6 |
| D5 | 骑乘死亡未 exit | `player.gd:1110-1128`；`main.gd:642-663`；`horse.gd:363-402,526-528` | S | 同 P11 |
| D6 | 血月 _enemy_near 不判类型 | `wild_world.gd:993-1057` | 已修 029c057 | 同 P4 |
| D7 | 血月遗漏类型 | `wild_world.gd:996-1057` | M | 同 P5 |
| D8 | Bot 只找 weapon 不找 ammo | `bot.gd:355-367,590-595`；`weapon.gd:98-103` | M | 同 P10 |
| D9 | Projectile source 悬垂 6s | `wild_projectile.gd:9,101-115` | M | `source` 弱引用或 `is_instance_valid` 守卫；超时/命中后不解引用 freed |
| D10 | 物理错位：倒木/守卫桥面 | `wild_world.gd:1191-1206`；`guardian.gd:304-306` | 已修 029c057 | 同 P9 |

## 本轮增量 4（Game Design 5.1/10，G1–G10）

| # | 标题 | Sev | 证据 | 状态 | 验收标准 |
|---|------|-----|------|------|----------|
| G1 | Wild 终局 3 重冲突：无限重生+最后存活胜利+巨龙终局互斥 | `main.gd:620-663,768-784` 探针 match_over=true | 已修 551f373 | Wild 仅巨龙结算，BR 仅存活结算；野图无限重生与终局不冲突可探针验证 |
| G2 | 零存档 2 小时无承接 | `player.gd:26-133` `main.gd:65` | XL 待存档 | 同 C5 |
| G3 | 背包 +6 vs 10 | `player.gd:1890` | 已修 f9bd405 | 同 P13 |
| G4 | InputMap 0 消费者 | `project.godot:27` vs `player.gd:203` | L 待迁移 | 同 C4 |
| G5 | Battlefield 192s + 决赛圈停伤 | `zone.gd:7-13,78-80` 探针 5s 后 HP=100 | M 待圈重调 | 总时长 220–260s；决赛圈 DPS 保持 20；`--sim` 存活曲线符合预期 |
| G6 | 无世界地图仅 164 点阵 | `hud.gd:132,759` `main.gd:863` | L 待地图 | Phase3 可缩放地图或区域揭示；仅点阵视为未通过 |
| G7 | Guardian 每帧清零永不发射 | `guardian.gd:264-283` 探针 5s HP=100 | 已修 ca90ced | 仅达 2.2s 阈值后重置；探针 5s 可发射 |
| G8 | 成长数值近战/HUD不一致 | `player.gd:1011,1520` `hud.gd:248` | M | 抽 CombatStats 统一 `damage_mult` 合成；近战/弓/枪同乘区 |
| G9 | 三枪 TTK 趋同 0.89/0.80/0.83 | `weapon.gd:14` | M | TTK 拉开 >15% 且有距离衰减；数值表可调 |
| G10 | IP 风险 XL | `README.md:1-3` | XL 需原创化 | 同 C6 |

## 本轮多角色增量 5（2026-08-28 六路复审新增，待落位）

> 去重后新增 S/M 项，优先级按“阻断→体验→内容→发行”排序，验收标准均为可 headless 验证。

| # | 标题 | 视角 | 证据 | 优先级 | 验收标准 |
|---|------|------|------|--------|----------|
| R1 | 胜负非终态：吃鸡后仍可被毒圈改判失败（match_over 未幂等） | Combat S1 | `main.gd:611-638` `zone.gd:78-97,119-132` `player.gd:84` | S | 唯一 `_finish_match(result)` 幂等；终局后停 `zone`、禁新伤害、冻 AI/输入；同 tick 多死顺序无关 |
| R2 | 阔野双漏洞：无限重生必胜 vs Bot 补刀永久无结局 | Combat S2 | `main.gd:620-674,779-795` `wild_dragon.gd:179-198` `weapon.gd:156-173` `wild_world.gd:995-1050` | S | 定义死亡契约（Boss 重置或消耗精灵/材料）；Boss 死亡无条件推进主线，归属仅影响奖励；Bot 伤害不使 Boss 永久消失 |
| R3 | 时停可选中自身并冻结控制器 | Combat S3 | `player.gd:136-139,356-381,793-804` | S | 已修（self 过滤 + 原 mode 恢复） | 候选过滤 `self`/友军；冻结走目标 `frozen` 状态而非 `DISABLED`；解冻由独立计时器驱动 |
| R4 | 猎弓绕过 60 RPM 并双扣弹药 | Combat S4 | `player.gd:242-245,756-771,1447-1465` `weapon.gd:26-30,123-132` | S | 弓/枪输入分流；单次 `can→consume→cooldown→spawn` 原子；快点不超 RPM；单发单扣 |
| R5 | 所有 PvE 只打真人，Bot 免疫野怪 | Combat S5 | `bot.gd:396-416` `wild_projectile.gd:20-24` `wild_monster.gd:30-32,183-226` `wild_dragon.gd:22-24` `guardian.gd:37-45` | S | 统一 `Faction/ThreatTarget`；野怪按距离/威胁选目标；projectile mask 按阵营而非“只打玩家” |
| R6 | 骷髅头贴身每帧 4 伤≈240 DPS | Combat S6 | `stal.gd:181-195` | S | 已在现版限伤（_hop_cd 门限） | 独立 `_bite_cd` 限伤；贴身 DPS ≤ 设计值且有可读窗口 |
| R7 | 装饰先于 POI 生成，无占地保留 | World S2 | `main.gd:92-102,168-173` `props.gd:206-243,509-537` `terrain.gd:294-304` | S | 先 `WorldLayout` 注册道路/POI/视线/谜题占地，再散布植被；POI 门前/路中线净空可验证 |
| R8 | 生物群落仅视觉分区 | World S3 | `terrain.gd:294-334` `props.gd:237-281,519-583` `weather.gd:86-103` `wild_world.gd:1312-1328,1465-1480` | S | 统一 `BiomeQuery` 驱动地表/树种/资源/动物/天气/音效/地名；雪区雨雪一致 |
| R9 | 神庙同外壳同奖励房 | World S4 | `wild_world.gd:36-43` `shrine_trial.gd:20-46,49-122,166-214` `shrine_interior.gd:25-101` | S | 每庙 2–3 步递进且与地区机制绑定；内部空间/奖励差异化 |
| R10 | 起始区过载+免费摩托压缩尺度 | World S5 | `main.gd:476-484` `wild_world.gd:36-48,131-134,951-970` `wild_motorcycle.gd:5-18,311-394` | S | 摩托中后期解锁；前期步/攀/骑/筏/塔节奏成立；500m 横穿 >60s |
| R11 | 首局无教学/目标，小地图非导航 | UX fork | `main.gd:476-510,1124-1140` `zone.gd:64-75,114-131` `hud.gd:130-180` `main.gd:545-568,1141-1168` | S | 92m 空降后 3 步教学+常驻主目标；小地图画圈/据点/方向/距离 |
| R12 | 神庙 22m 自动开启/出口 parent 错 | UX fork | `shrine_trial.gd:5-7,151-163,196-214` `shrine_interior.gd:136-154` `player.gd:95-96,904-907` | S | 明确 E 开启（22m 仅提示）；出口传送修正 parent；往返 10 次无错 |
| R13 | 交互扫描支持但 HUD 提示遗漏 | UX fork | `player.gd:869-909` `main.gd:1101-1120` | S | 宝箱/水晶/鱼/床等均有 HUD 提示且与扫描一致 |
| R14 | 三上帝类：Main/Player/WildWorld | Arch H1 | `main.gd:1-75,78-380,456-1005` `player.gd:12-133,136-818` `wild_world.gd:32-138,262-1451` | S | 提取 `MatchCoordinator/WildMode/Spawn/Quest`、`Health/Inventory/Input` 等；Main 仅装配 |
| R15 | 全局 scene/group/鸭子类型耦合 | Arch H2 | `main.gd:291-297` `weather.gd:256-259` `wild_monster.gd:147-166` 等 110/38/121 处 | S | 新增代码零 `current_scene` 反向访问与私有跨调；以注入/信号/注册表收敛 |
| R16 | 怪物无基类/组件/工厂，生命周期重复 | Arch H3 | `wild_monster.gd:5-27,147-169` `wild_moblin.gd:5-37,230-257` `guardian.gd:5-26,227-252` | S | 引入 `Health/Drop/Target/Presenter` + `EnemyDefinition/Factory`；单怪重复代码收敛 |
| R17 | 世界生成/血月硬编码分支 | Arch H4 | `wild_world.gd:32-138,983-1050,1312-1344` | S | `EnemySpawnSpec` 注册表驱动生成与血月；类型用 `id` 而非 basename |
| R18 | 输入多写者竞争（T/V 冲突等） | Arch H5 / World H1 | `project.godot:27-68` `player.gd:203-298,569-685` `main.gd:874-905` `season_system.gd:101-104` | S | InputMap 唯一入口 + `InputRouter`；T/V 等冲突为 0；调试键仅 debug 模式 |
| R19 | Environment 多写者 | Arch H6 | `main.gd:1932-2038` `season_system.gd:83-130` `day_night.gd:96-127` `weather.gd:158-159` | S | `EnvironmentDirector` 唯一合成；Season/DayNight/Weather 只发权重 |
| R20 | 测试嵌入生产 Main 且依赖帧号/私有 | Arch H7 | `main.gd:195-357,1171-1918` `wild_projectile.gd:112-113` | M | 迁出 `DebugScenarioRunner`；新增独立 headless 场景；测试不碰 `_` 私有 |
| R21 | 近战/时停无 LOS 可隔墙 | Combat M3 | `player.gd:356-380,1532-1575` | M | 候选加 LOS/ShapeCast；隔墙不可命中/冻结 |
| R22 | Boss 弹道不补重力可风筝 | Combat M4 | `hinox.gd:183-189,228-237` `wild_dragon.gd:231-264` `wizzrobe.gd:102-112` `wild_projectile.gd:12-18,87-93` | M | 复用抛物线解算+预瞄；中距命中率矩阵达标 |
| R23 | 占点 Buff 永久全图且抵消首圈 | Combat M5 | `capture_point.gd:99-131` `main.gd:859-871` `zone.gd:7-13` | M | Buff 限距/限时或随圈重置；毒伤始终 > 全局回血 |
| R24 | 缩圈 192s 且中心不验地形 | Combat M6 | `main.gd:176` `zone.gd:7-13,100-105` | M | 总时长 220–260s；新中心采可达陆地且有掩体/POI 约束 |
| R25 | 攻击提升只加枪不加剑/弓 | Combat M7 | `main.gd:859-870` `player.gd:1016-1027,1447-1459,1532-1535` `weapon.gd:170-173` | M | 统一 `DamageContext`；剑/弓同享 `all_damage_mult` |
| R26 | 弹药按槽复制，人机规则不一 | Combat M8 | `player.gd:931-936` `loot.gd:316-325,363-365` `bot.gd:331-332` | M | 统一弹药池/口径；总量单次增加；人机同接口 |
| R27 | 龙鳞支线与主线结算互斥 | Combat M11 | `main.gd:734-749,779-795` `wild_dragon.gd:186-197` | M | 阶段掉鳞或延迟结算+自动入包；结局可 4/4 |
| R28 | 小地图开局泄露+漏第四庙 | World H5 | `hud.gd:130-166` `main.gd:765-768` `wild_world.gd:108-111` | M | POI 统一注册；初始仅揭示附近；塔激活才揭示区域；第四庙在列 |
| R29 | 探索解谜多为靠近/一次伤害同质（原“探索解谜”去商标化） | World H4 | `wild_world.gd:1064-1092,1132-1145,1436-1446` `rock_circle.gd:50-63` `flower_trail.gd:36-53` `dive_ring.gd:28-37` `korok_prop.gd:92-109` | M | 新增搬运/轨迹/计时/风向/攀滑组合；每语法三级难度 |
| R30 | 投射物弹反方向对但 mask 打不中 | Combat M13 | `wild_projectile.gd:20-24,96-115` `guardian.gd:42-45` | M | 弹反后切玩家阵营 mask；可命中施法者且不重伤自己 |

---

## AUD 四维审计增量（2026-09-01，手感/玩法/特效/模型打磨）

> 来源 `docs/REVIEW_20260901.md` 四维审计；ID `AUD-` 与既有 `C/H/M/L/R` 并列，互不覆盖。验收口径：`fix(AUD-xxx):` + `// FIX: AUD-xxx` 可追踪；`headless 零 ERROR` 基座；固定 `--seed 7` 二次一致。

### AUD-P0（阻断，不修则手柄不可玩/首刷卡/表现穿帮）

| ID | 标题 | 证据 file:line | Phase | 状态 | 验收标准（可验证） |
|----|------|----------------|-------|------|-------------------|
| AUD-P0-1 | 摇杆 deadzone 0.5 + 7 键位冲突，手柄不可玩 | `project.godot:32-159` `player.gd:568` | Phase1 1.11 | 待修复 | `grep deadzone` 均 0.18；手柄右摇/扳机可完成 `--wildtest`；`grep -r "KEY_" scripts/player` 仍 0；T/V 等冲突为 0 |
| AUD-P0-2 | 载具绕过 InputMap，手柄/重映射失效 | `vehicle.gd:354` `horse.gd:475` `wild_motorcycle.gd:330` `raft.gd:214` | Phase1 1.12 | 待修复 | `is_key_pressed(KEY_W)` 清零；改 `get_action_strength("move_forward/back/left/right")`；手柄左摇可驾驶 20m |
| AUD-P0-3 | 跳跃无 coyote/buffer，楼梯丢跳 ~15% | `player.gd:809` `floor_snap 0.5` | Phase1 1.13 | 待修复 | 墙钟 `coyote 0.15 + buffer 0.18`；探针 100 次楼梯跳成功率 >98% |
| AUD-P0-4 | GLB 同步 `load()` 首刷 hitch 5-15ms×N | `wild_moblin.gd:66` `wild_lizalfos.gd:64` `wild_creature.gd:78` `wild_dragon.gd:54` `wild_npc.gd:67` | Phase1 1.14 | 待修复 | `preload` + 集中注入 + `call_deferred ≤4/帧`；`[boot_t]` 首刷 -60%；`--wildtest` 零 hitch |
| AUD-P0-5 | 描边双遍 draw×2（600+ 实例） | `toon.gd:11,17` | Phase1 1.15 | 待修复 | 草/花/树冠禁 `next_pass`，角色 0.014/建筑 0.018 分级；`--sim` draw calls 峰值 -30% |
| AUD-P0-6 | 弹孔池仅查 `_decals[0]` 悬垂漏检 | `fx.gd:111` | Phase1 1.16 | 待修复 | `filter(is_instance_valid)` 全扫；`--reloadtest` 720 帧零 freed |
| AUD-P0-7 | 烟雾荧光云 + 爆炸黑芯 | `smoke_grenade.gd:63` `remote_bomb.gd:152` | Phase1 1.17 | 待修复 | `disable_fog=false + day_light`；`emission→0` 并行；夜景烟雾 ≤ 白天 40%；爆炸 0.3s 无黑芯 |
| AUD-P0-8 | 水面过算 + 闪电/云未池化 | `water.gdshader:49` `weather.gd:271` `sky_builder.gd:99` | Phase1 1.18 | 待修复 | 水 64→32 + varying；闪电静态化；云 MultiMesh 1 draw；水面 1.4ms→0.7ms |

### AUD-P1（手感/留存/帧率达标）

| ID | 标题 | 证据 file:line | Phase | 状态 | 验收标准 |
|----|------|----------------|-------|------|----------|
| AUD-P1-1 | 地形 GRID 192 单 Mesh 无 LOD | `terrain.gd:8,213` | Phase2 2.10 | 待修复 | `GRID 96 + 四象限 visibility_range`；低端核显 30fps；`--sim` p95 draw≤600 |
| AUD-P1-2 | 建筑 `BoxMesh.new()` 不共享 | `buildings.gd:159` `wild_world.gd:192` | Phase2 2.11 | 待修复 | `shared_box` 单例 + 120/250m 视距；draw calls -15% |
| AUD-P1-3 | 移动/射击曲线不可学习 | `player.gd:794` `weapon.gd:73` | Phase2 2.12 | 待修复 | `ACCEL 20+friction18 / AIR 8 / bloom 0.09/0.65/6.5 + 固定弹道`；`--firetest` TTK 拉开 15% |
| AUD-P1-4 | GPU 粒子池缺失，每发 new Mesh+tween | `fx.gd:59,173,245` | Phase2 2.13 | 待修复 | `GPUParticles3D` 32/64 三套 + MultiMesh 池；SMG 13发/s 零 new Material |
| AUD-P1-5 | 局外零正向成长，仅难度递增 | `main.gd:37,61` | Phase2 2.14 | 待修复 | `total_kills→天赋点` 3选1 写入 `save_v1`；重载生效；二周目可测增强 |
| AUD-P1-6 | 投放固定可背板 | `buildings.gd:42` `wild_world.gd:713` | Phase2 2.15 | 待修复 | `hash(seed) ±6m` 抖动；`--seed 7 vs 13` 布局不一致 |
| AUD-P1-7 | 雨雪零生存代价 | `weather.gd:133` | Phase2 2.16 | 待修复 | 雨 `移速×0.92 攀爬×1.25`；湿时探针达标 |

> AUD 与既有 `C/H/M/L + R` 并列，Phase 划分见 `docs/ROADMAP.md v2`；本段状态随 `fix(AUD-xxx)` 合入逐项更新为“已修（commit）”。

---

## 已验证修复（本轮 headless 均 EXIT:0，待持续回归）

| 项 | 修复提交 | 验证 |
|---|----------|------|
| SOUNDS 4键+shot_bow 实播 | 0161f32 + 4041505 | 资源存在且调用闭环 |
| 昼夜/Boss 三轨 Mixer | fadf566 | 四组合真值表闭合 |
| Guardian 充能 | ca90ced | 仅达 2.2s 后重置，探针 5s 发射 |
| 炸弹双伤 52 | ca90ced | 排除 player/source，去重字典 |
| Wild/BR 终局隔离 | 551f373 | `_map_id!="wild"` 守卫，野杀 8Bot 不锁 |
| 骑乘死亡（基础） | 551f373 + b8cde6c | die/respawn 均 exit+恢复可见/碰撞 |
| 游泳/圈停伤 | 91354fd | zone final DPS 保持，抓鱼可达 |
| target_loot 悬垂 | 51f2958 | 双点 is_instance_valid 守卫 |
| 入树顺序（部分） | 51f2958 | 鱼/圈/动物/飞行器等 5 处先设位置再入树 |
| 背包 10项 | f9bd405 | +6→实际行数，10 项可达 |
| time_scale 泄漏 | b8cde6c | die/respawn 无条件重置 |
| 倒木/守卫桥面 | 029c057 | 碰撞 90° + 仅非 is_on_floor 回落 |
| Bot 超时+搜弹药 | 1f36878 | LOOT 8s 超时+空匣搜 ammo |
| await→queue_free | 5d52784 | 四处 is_inside_tree 守卫 |

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
```

> 本文件为唯一真实来源；`docs/ROADMAP.md` 的 Phase 划分与门禁均以此为准，Top 15 Backlog 以 Critical/High/S 级为序。
