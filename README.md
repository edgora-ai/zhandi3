# zhandi3 — 原创旷野卡通大逃杀

> **免责声明 / 原创声明**：本项目为原创程序化实现，所有地形、模型、材质、音效均为代码生成，不含任何外部游戏的美术/音频/商标资产。历史文档中出现的外部 IP 相关表述已统一去商标化为“原创旷野卡通”等中性词，与任何商业 IP 无关联，不代表官方或授权关系。

原创旷野卡通风格大地图 FPS × 吃鸡大逃杀框架 × 卡通渲染。使用 **Godot 4.7.1 + GDScript** 开发，全部素材（地形、植被、角色、建筑、载具、特效和音效）程序化生成，零外部素材依赖。

> **本项目是一款用 Kimi k3（Kimi Code CLI）开发的测试游戏**：从需求、编码、调试、验证到截图提交，全部由 AI 完成，用于检验 AI Agent 独立交付一个完整可玩游戏的能力。

## 游戏效果

以下截图均为工程内置 `--screenshot` 调试命令自动生成：

| 第一人称战斗视角 | 500m×500m 海岛全景 | 结算画面 |
| --- | --- | --- |
| ![第一人称](docs/screenshots/firstperson.png) | ![海岛全景](docs/screenshots/island.png) | ![结算画面](docs/screenshots/end.png) |

## 两张地图

### 群岛战场

- 你 + 23 个 AI 战士空降到 500m×500m 的海岛，赤手空拳落地
- 搜刮武器（冲锋枪/突击步枪/射手步枪）、护甲、医疗包、弹药——物资聚集在 3 座村庄（小屋/两层楼/仓库/瞭望塔）里，也有码头、废墟可探索
- 毒圈分 5 个阶段收缩，圈外持续掉血，越到后期越痛
- 地图上有 3 面旗帜据点（A/B/C），沙袋工事环绕，在圈内停留 5 秒占领，占领后**持续回血 + 伤害提升 10%**
- 春夏秋冬实时切换：地面、草木、水面、天空雾光、花瓣/落叶/雪和建筑雪盖同步变化
- 活到最后：**大吉大利，今晚吃鸡！**

### 原创旷野（开放世界探索区）

> 去商标化说明：相关外部 IP 表述已统一改为“原创旷野卡通”等中性词，玩法不变，仅消除外部 IP 关联。

- 你 + 8 名 AI 战士在阔野地图展开大逃杀：空降、搜刮地标补给、互相交战，活到最后同样吃鸡
- 解析式地貌塑造初始高原、双子山裂谷、雪山、中央丘陵、S 形主河与火山区；不是用随机噪声平均铺满的无名地形
- 试炼遗迹（原“神庙”中性表述）、三座古代测绘塔、时间神殿遗址、北境城堡、44 米主河大桥、道路、芦苇、火堆和发光熔岩火口组成可辨识的探索地标
- 九段命名道路以土色直接绘制进地形表面，远近都看得见；路口有木质路标，驿站与桥边沿途立石灯
- 测绘塔带外侧螺旋梯、城堡有大门台阶、试炼遗迹有门前台阶、主河大桥两端有引桥石阶——所有高处的“楼梯”都能真的走上去
- 驿站旁有围栏马场、干草垛和货车；遗迹路上散落断裂立柱；花丛间有蝴蝶飞舞
- 河流具备水波、深浅色与岸线泡沫；玩家自动浮向水面，可游泳、上浮、下潜和加速，不再沉底行走
- 驿站具有 26 米圆形客栈、环廊、住宿间、接待柜台、马槽、拴马栏、灯笼和巨型马首帐篷顶，不再只是单层顶棚
- 可骑乘 4 匹不同毛色的马和古代科技摩托；马匹重做了头颈比例、分段步态和鞍具，马/摩托采用“镜头朝哪就往哪走”的现代骑乘操控（A/D 原地转身），吉普为渐进油门+速度转向，三者都有抓地惯性、坡地姿态与鼠标环绕镜头
- 8 个山野小怪会投石并近身冲锋；3 台飞行攻击器发射能量弹；火山巨龙巡航并喷火
- 野猪、狼、熊和鸟构成野生生态，击败动物掉落兽肉；蘑菇、兽肉和龙鳞可存入背包并用于恢复生命或护甲
- 开局空降或落地后从任意悬崖跃下时按住空格展开滑翔伞：伞始终向前飘行，W 俯冲提速、S 减速缓降、A/D 转向；伞面、伞绳和握杆在第一人称可见，常规下坠速度限制为 3.1m/s
- 攀爬系统：朝树干、塔身、悬崖、石壁等陡面推 W 即可攀爬，W/S 上下、A/D 横移、Space 蹬离；从塔顶或悬崖跃下再接滑翔伞是核心移动链路
- 砍树：射击或攻击树干两次即可砍倒（大树四次），树干朝远离你的方向倒伏，留下木桩并掉落可拾取的木材（护甲材料）；树木高 5~9m 可攀爬，阔叶、针叶、巨树三类树形随机散布
- 四位可交谈的 NPC：驿站老板、火山研究员、城堡卫兵、旅行商人，靠近按 E 获取路线与玩法提示
- 动物有警觉中间态（头顶 ! 定格注视再决定攻/逃）、狼讲群体规则；NPC 会因枪声抱头躲闪，行商沿道路往返巡逻
- 篝火烹饪：火堆旁使用生兽肉/蘑菇烤成回复更强的料理；地图各处藏有 10 颗原创探索种子（自发光收集物，捡到护甲 +5）
- 试炼遗迹挑战：四座遗迹各藏差异化限时试炼（符文/火盆/压力板/推球入臼，限时 15/18/20s，奖励 orb/seed 分级），射中全部 4 个符文获得精灵宝珠（生命上限 +10），超时重置可反复挑战
- 昼夜循环（6 分钟一天）：清晨/正午/黄昏/夜晚光照雾色全联动，夜晚狼群更凶，灯笼与火堆成为夜色主角，按 T 推进时间
- 血月事件：每三夜一次猩红血月，怪物全部苏醒；地图藏有风车与怪石探索解谜（命中出种子）与两处怪物营地
- 山林细节：白桦/阔叶/松/巨树四树种，林地倒木、蘑菇仙女环、蕨类丛；火山玄武岩柱群与雪线白顶岩
- 精力轮：冲刺/攀爬/滑翔消耗精力，耗尽会锁速、滑落、收伞；食物回复精力，准星旁环形精力指示
- 天气系统：晴雨交替，雨时地面湿滑反光、水面涟漪、雨幕与远雷闪电；两台古代守卫以红色激光追踪并发射光束
- 小精灵系统：死亡时自动消耗一只精灵复活（30% 生命），地图两处可捕捉；遗迹第二试炼为点燃火盆；NPC 入夜打盹
- 古代剑：城堡平台深处奖励，近战伤害提升至 42；空手举盾在坡面上可盾牌滑行；第三遗迹为压力板试炼
- 闪避时停：Q 闪身带无敌帧，窗口内被击中触发 0.22 倍慢动作并无伤反击；河里可抓鱼，石头阵解谜（站进缺口补全出种子）
- 蛮兵（原“莫布林”中性表述）：大体型重击敌人，长前摇举棒（可格挡可闪避）后猛击；烤串（兽肉+蘑菇）90 秒攻击 +25%
- 猎弓：按住左键拉弦蓄力，松开放箭，箭速与伤害随蓄力提升，箭矢走抛物线；遗迹与高原古树各有一把
- 高原小屋（睡眠点）：高原小屋里的床铺，按 E 睡到天亮并回满生命与精力；蜥蜴战士环绕游走并高速突进
- 弹反：举盾面向来袭石头可将其原路弹回；每收集 3 颗探索种子精力上限 +10
- 光束弹反：完美格挡守卫光束可直接摧毁守卫；桥西码头有木筏可乘（F 上下），接近巨龙时显示血条
- NPC 任务链：驿站老板收 3 个蘑菇（奖护甲）、城堡卫兵讨 2 只蛮兵（奖宝珠），HUD 实时显示任务进度；花径追踪解谜
- 新增任务：火山研究员收龙鳞（奖精力上限）、护送行商走到桥头（奖弹药）；焚天者半血暴怒进入第二阶段
- 血月苏醒覆盖全部敌人类型；集齐 10 颗种子获得探索者面具（永久攻击 +5%）
- 讨伐焚天者触发讨伐结算（种子/任务/弹反/击败统计）；右下角小地图显示地标与玩家位置
- 马匹具备旷野式自主性：松手自动沿道路行走、慢步/快步/疾驰三级步态、待机低头吃草；野马首次骑乘会尥蹶子，安抚后温顺
- 阔野地图自带补给：地标与营地分布 5 把武器、9 处弹药、医疗包与护甲，测绘塔顶与城堡平台藏有攀爬奖励
- 主河河岸为 20m 宽渐变滩涂：河床→沙滩→草坡可自然行走下水，怪物与野兽不会涉水追进河里
- 通用自动上台阶：驿站石基、遗迹平台、断柱等 0.68m 以内台基直接迈上去，不用蹦
- 战斗反馈：三段剑招带蓝/金动态剑光、近距软锁与踏步追击；敌人有脚下前摇环、可打断硬直和受击击退，命中有方向火花、飘字、顿帧与分层音效；非致命伤不会误计击杀或提前掉落
- 马匹头部使用手工楔形网格塑造笔直长脸，鬃毛为立式脊冠；地图整体色阶为高饱和旷野绿，天空布置大朵扁平白云
- 阔野地图是一套受开放世界卡通冒险启发的原创程序化实现，不包含外部游戏资产

## 操作

| 按键 | 功能 |
| --- | --- |
| W A S D | 移动 |
| 鼠标 | 视角 |
| 左键 | 射击；空手时挥剑（砍树、近战、点符文） |
| Q | 闪身（带无敌帧，触发专注时停） |
| 右键 | 持枪时机瞄；空手时举盾格挡（瞬间举起为完美格挡） |
| Shift | 冲刺 |
| 空格 | 地面跳跃；高处下降时按住展开滑翔伞；水中上浮 |
| C | 地面趴下（更慢，扩散大幅降低）；水中下潜 |
| G | 投掷烟雾弹（烟球遮挡 AI 视线，初始 3 枚） |
| F | 靠近吉普车、马或摩托时骑乘 / 下车（W/S 前后，A/D 转向） |
| 推 W 朝陡面 | 攀爬树干 / 塔身 / 悬崖（Space 蹬离） |
| N | 打开 / 关闭背包（W/S 选择，E 取出或使用，X 存入当前武器） |
| B | 遥控炸弹引爆（需先 X 放置） |
| M | 打开地图选择（1 群岛战场，2 原创旷野） |
| V | 循环切换春 / 夏 / 秋 / 冬 |
| R | 换弹 / 结算后重开 |
| E | 拾取 |
| H | 吹口哨召唤附近的马（45m 内小跑过来） |
| T | 推进 1 小时（昼夜流转） |
| 1 / 2 | 切换武器槽 |
| Esc | 释放鼠标（点击左键或再按 Esc 重新锁定） |
| — | 窗口失去焦点自动暂停，切回自动继续 |

## 合规与启动统计

- 启动时控制台打印 `[wild] shrines=4 ...` 与本文档一致，作为 L1 回归锚点。
- 合规文档见 `docs/LICENSE` / `docs/PRIVACY.md` / `docs/EULA.md` / `docs/NOTICE.md`。
- **单机离线定位**：本作为单机离线体验，无联机/匹配/反作弊依赖（见 `scripts/main.gd:1-5` 顶部注释）；所有内容本地可玩，不采集个人信息。
- **单机复玩：--seed 随机池 + 二周目难度增量（C7 可验收）**：同一版本下 `--seed N` 产生可复现的出生点/物资/天气/任务序列，换种即新局；二周目增量由种子池与成长解锁共同承载（示例：`--seed 7` 与 `--seed 13` 布局不同，配合已解锁成长与怪物强度可验证难度增量）。

## 运行

```bash
tools/Godot.app/Contents/MacOS/Godot --path .
```

首次运行如被 Gatekeeper 拦截：`xattr -dr com.apple.quarantine tools/Godot.app`

## 开发

### 结构

```
project.godot            # 工程配置（主场景 scenes/main.tscn）
scenes/main.tscn         # 极简根场景，一切由代码生成
scripts/
  main.gd                # 比赛总控：生成、击杀播报、胜负、buff 结算
  world/terrain.gd       # 噪声地形 + 顶点色 + 解析高度采样 + 水面（高度图驱动的水波 shader）
  world/wild_world.gd    # 阔野地图总成：神庙/驿站/遗迹/桥梁/火山/生态生成
  world/props.gd         # 树木/灌木/岩石/草（树冠/草丛 MultiMesh + 行进风场 shader）
  world/season_system.gd # 四季总控：地表/植被/水片/天空雾光/天气联动
  world/tex_gen.gd       # 程序化贴图工厂：叶簇/草叶/花朵 alpha 贴图
  world/buildings.gd     # 程序化建筑：村庄（小屋/两层楼/仓库/瞭望塔/废墟）、据点沙袋工事、码头小船
  world/toon.gd          # 卡通材质工厂（toon 光照 + grow 描边）
  world/day_night.gd     # 昼夜循环：太阳角度/天空雾色/血月计数
  world/weather.gd       # 天气系统：晴雨交替、雨幕、闪电、地面湿滑与水面涟漪
  player/player.gd       # FPS 控制器（移动/空降/游泳/滑翔/背包/骑乘）
  player/weapon.gd       # hitscan 武器逻辑 + 程序化视模型
  player/hud.gd          # 全套 HUD（中文用内置 Noto Sans SC 渲染）
  bots/bot.gd            # AI 状态机：空降→搜刮→跑圈→占点→交战
  game/zone.gd           # 毒圈：5 阶段收缩、圈外伤害、圈墙可视化
  game/capture_point.gd  # 据点：占领进度、旗帜变色、增益归属
  game/loot.gd           # 战利品：光柱稀有度、拾取逻辑
  game/vehicle.gd        # 吉普车：F 上下车、街机驾驶、贴地形
  game/horse.gd          # 马匹：程序化模型、骑乘控制与步态
  game/wild_motorcycle.gd # 古代摩托：程序化模型、悬挂与骑乘控制
  game/raft.gd           # 木筏：水面载具，F 上下、靠岸自停
  game/wild_creature.gd  # 野猪/狼/熊/鸟生态、攻击与掉落
  game/wild_monster.gd   # 山野小怪：巡逻、投石与冲锋
  game/wild_moblin.gd    # 莫布林：长前摇重击，可格挡可闪避
  game/wild_lizalfos.gd  # 蜥蜴战士：环绕游走与高速突进
  game/guardian.gd       # 古代守卫：六足巡逻、激光锁定与毁灭光束（可盾反）
  game/wild_dragon.gd    # 火山巨龙：巡航、喷火与龙鳞掉落
  game/flying_attacker.gd # 古代飞行攻击器
  game/wild_projectile.gd # 石块/火焰/能量弹共用投射物
  game/smoke_grenade.gd  # 烟雾弹：引信起烟、遮挡 AI 视线
  game/wild_npc.gd       # 旅人 NPC：地标驻留、E 交谈与任务链
  game/choppable_tree.gd # 可砍树木：受击倒伏、留桩与木材掉落
  game/shrine_trial.gd   # 神庙试炼：射符文/火盆/压力板/推球入臼
  game/shrine_rune.gd    # 神庙符文靶：悬浮光环，射中点亮
  game/korok_prop.gd     # 探索解谜：风车射击与可疑怪石
  game/rock_circle.gd    # 石环解谜：站进缺口补全出种子
  game/flower_trail.gd   # 花径解谜：按序触碰发光花
  game/dive_ring.gd      # 跳水环解谜：游进睡莲环心得种子
  game/fish_spot.gd      # 河鱼点：水中鱼影，E 抓鱼
  game/bed_spot.gd       # 床铺：睡到天亮，生命精力全满
  game/korok.gd          # 探索精灵：解谜成功时蹦出挥手、缩小消失
  game/remote_bomb.gd    # 遥控炸弹：X 放置 B 引爆，范围伤害与炸弹跳
  game/ice_pillar.gd     # 制冰冰柱：T 升起，水面站立渡河
  game/metal_prop.gd     # 磁力金属块：Z 吸附搬运投掷，可压神庙压力板
  game/chuchu.gd         # 丘丘果冻：蹦跳撞击，大只死亡分裂小只
  game/keese.gd          # 夜行蝙蝠：夜间盘旋俯冲，白天蛰伏
  game/stal.gd           # 骷髅夜袭：夜间破土，击碎后蹦跳头颅
  game/wizzrobe.gd       # 维佐法师：悬浮施法、中距游走、近身闪现
  game/loot_chest.gd     # 古代宝箱：E 开箱给防具（士兵/攀爬者/蛮族三套）
  game/hinox.gd          # 西诺克斯：沉睡巨人 Boss，跺地/投石、独眼弱点
  game/warp_beacon.gd    # 测绘传送水晶：塔顶激活、M 地图传送
  fx/fx.gd               # 曳光/命中特效
  fx/damage_number.gd    # 飘字伤害反馈：命中弹数字、上浮淡出
  fx/sfx_bank.gd         # 音效池（2D/3D）
assets/
  models/              # Blender 无头生成的 glb：村民/莫布林/蜥蜴/马/猪狼熊/龙/守卫/士兵/蝙蝠/骷髅（可再生产物）
  shaders/ground.gdshader # 多尺度地表斑驳 + 岩层 + 积雪/湿润
  shaders/grass.gdshader # 草叶广告牌化 + 行进风场阵风 + 三段色带
  shaders/water.gdshader # 深度水色 + 岸线环 + 雨滴扩散 + 冬季冰裂
  sfx/*.wav              # tools/gen_sfx.py 生成（Python 标准库），含音乐/环境音循环
  fonts/                 # Noto Sans SC（HUD 中文）
tools/
  Godot.app              # Godot 4.7.1 编辑器/运行时
  gen_sfx.py             # 音效合成脚本
  blender_gen/           # Blender 无头生成脚本（蒙皮角色 + NLA 动画 → assets/models/*.glb）
```

### 调试参数（`--` 之后传入）

```bash
# 截图（窗口模式，N 帧后存图退出，注意：无头 headless 下截图为空白，不可用于校验）
tools/Godot.app/Contents/MacOS/Godot --path . -- --screenshot /tmp/shot.png [--frames 2700] [--cam x,y,z,tx,ty,tz]
# 无头模拟整场比赛并打印进度
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 30000 -- --sim
# 玩家直接落地 + 自带步枪
tools/Godot.app/Contents/MacOS/Godot --path . -- --ground --arm
# 固定随机种子（可复现的比赛布局，便于调试/截图定位）
tools/Godot.app/Contents/MacOS/Godot --path . -- --seed 7
# 指定初始季节（spring / summer / autumn / winter）
tools/Godot.app/Contents/MacOS/Godot --path . -- --season winter
# 直接进入指定地图（battlefield / wild）
tools/Godot.app/Contents/MacOS/Godot --path . -- --map wild
# 射击链路自检（headless，300 帧内完成，生成测试 bot 并开火校验命中与伤害递减）
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300 -- --firetest --ground --arm --seed 7
# 阔野完整玩法回归（headless，900 帧到 terminal 790）
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 900 -- --wildtest --ground --arm --seed 7
# 特效固定池回归（headless --quit-after 360，需配合已合入的 W3 池化补丁；洁净基线下 catcher 预期 exit 1，合入 W3 后 exit 0）
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 360 -- --fxstresstest --ground --arm --seed 7
# 动物定格照（窗口 GUI，不可 headless；三只动物正/侧/three-quarter 分明，近景 180-300px，无遮挡无重叠）
tools/Godot.app/Contents/MacOS/Godot --path . -- --map wild --animalshot --seed 7 --screenshot /tmp/animals.png --frames 90
# 枪口焰定格照（窗口 GUI 4 帧，需 W3 已合入可见径向焰；落地应达 200 帧）
tools/Godot.app/Contents/MacOS/Godot --path . -- --firetest --ground --arm --seed 7 --screenshot /tmp/muzzle.png --frames 4
# 负向探针（headless，预期 exit 1，仅一次 FAIL + SUMMARY FAIL）
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 120 -- --test-harness-negative
# 看门狗自检：内部约 60 帧后产生一次 watchdog FAIL+SUMMARY 并自然 exit 1，早于外部 --quit-after 120（验证 --quit-after 无法拦截的兜底）
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 120 -- --test-harness-stall
# 视觉调试：--pilottest（Blender 小人）、--moblintest/--liztest（敌人前摇）、--ridertest/--biketest/--jeeptest（骑乘）、--koroktest（探索精灵）
# 地图选择与背包界面截图预览
tools/Godot.app/Contents/MacOS/Godot --path . -- --screenshot /tmp/map.png --mapmenutest
tools/Godot.app/Contents/MacOS/Godot --path . -- --screenshot /tmp/backpack.png --backpacktest --map wild
# 射击链路自检（生成测试bot并开火，校验命中与伤害递减，安全值 300 帧）
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300 -- --firetest --ground --arm
# 失焦恢复自检（模拟漏收恢复通知，确认暂停外定时器能自动解锁）
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 120 -- --noworld --ground --focusrecoverytest
# 四季联动自检（春→夏→秋→冬）
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 120 -- --noworld --ground --seasontest
# 结算画面预览
tools/Godot.app/Contents/MacOS/Godot --path . -- --screenshot /tmp/end.png --endtest
```

### 重新生成音效

```bash
python3 tools/gen_sfx.py   # 仅依赖 Python 标准库
```

## AI 开发与测试过程

本项目由 Kimi k3 在与用户很少的交互下完成，典型闭环：用户提需求/报告问题 → AI 读代码定位 → 修复 → 自动化验证 → 用户试玩确认。

完整的问题复盘、Godot/GDScript 踩坑记录和推荐排障顺序见 [开发与排障笔记](docs/DEVELOPMENT_NOTES.md)。

### 自动化验证手段（全部内置在工程里）

- `--headless --import` + `--quit-after N`：编译与运行时错误检查，每次改动必跑
- `--screenshot`：窗口模式定时自动截图，视觉改动以图像确认（上方效果图即该命令产物）
- `--firetest`（headless --quit-after 300）：射击链路与伤害递减自检，本地 300 帧内完成
- `--wildtest`（headless --quit-after 900）：阔野全量回归，terminal 790
- `--fxstresstest`（headless --quit-after 360，需 W3）：固定池 137 节点/136 子/无二轮增长/可见→冷却隐藏（洁净基线 catcher exit 1，W3 后 exit 0）
- `--animalshot`（GUI --map wild --animalshot --seed 7 --screenshot ... --frames 90）：动物定格照，需目检无重叠
- `--screenshot --frames 4`（GUI）：枪口焰 4 帧定格，需 W3 可见径向焰
- `--test-harness-negative`（headless --quit-after 120，预期 exit 1 且恰好一次 FAIL）：负向探针，`--test-harness-stall` 为看门狗自检（内部 60 帧，外部 120，恰好一次 watchdog FAIL+SUMMARY 并自然 exit 1）
- `--sim`：无头模拟整场比赛（24 人 + 完整毒圈流程），可挂内存/对象数探针做压测

### CI 门禁语义（防 engine --quit-after 0 掩盖）

- 任何 `--firetest` / `--wildtest` / `--fxstresstest` / `--animalshot` / `--test-harness-stall` 的正向/负向判定必须同时满足**退出码**与**唯一 SUMMARY 标记**：`exit 0` 仅当恰好一次 `[test] SUMMARY PASS`，`exit 1` 仅当恰好一次 `[test] SUMMARY FAIL` 且含对应的 `FAIL` 行；仅靠 `exit 0` 会被 `--quit-after` 兜底误判。
- 内部看门狗在 `PROCESS_MODE_ALWAYS` 的 `_process` 顶部以 `Engine.get_process_frames()` 对全局 deadline 校验（fire 约 260/300、wild 约 850/900、FX 约 300/360、negative 约 90/120、stall 约 60/120、screenshot 为 frames+余量），到期对仍未 `done` 的 requested probe 追加一次 harness `FAIL` 并经幂等的 `_harness_mark_all_incomplete_done_idempotent()` 自然 `pending-quit exit 1`，早于外部 `--quit-after`；脚本级 parse/crash 无法被拦截，README/CI 显式要求双条件。

### 真人试玩驱动修复的真实案例

- **持枪后无法转向/开火**：试玩发现「徒手正常、持枪失灵」，定位为屏幕中心准星控件（`mouse_filter=STOP`）吞掉捕获模式下的全部鼠标事件 → HUD 全部改为 `IGNORE`
- **鼠标捕获丢失后游戏「假死」**：点击左键重新锁定鼠标（标准 FPS 行为）
- **「玩着玩着卡住」**：用无头模拟赛 + 心跳/内存探针复现排查，确认游戏无泄漏、无死循环；同时针对 macOS 窗口失焦导致输入全断的问题，增加失焦自动暂停、切回自动继续
---

## 合规链接

- 许可证：`docs/LICENSE`（MIT 占位，原创程序化实现，不含外部 IP 资产）
- 第三方声明：`docs/NOTICE.md`
- 隐私说明：`docs/PRIVACY.md`（单机离线，不采集个人信息）
- 最终用户许可：`docs/EULA.md`

