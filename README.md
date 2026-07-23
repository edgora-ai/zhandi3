# 战地3 (zhandi3)

战地式大地图 FPS × 吃鸡大逃杀框架 × 旷野之息卡通渲染。使用 **Godot 4.7.1 + GDScript** 开发，全部素材（地形、植被、武器模型、音效）程序化生成，零外部素材依赖。

> **本项目是一款用 Kimi k3（Kimi Code CLI）开发的测试游戏**：从需求、编码、调试、验证到截图提交，全部由 AI 完成，用于检验 AI Agent 独立交付一个完整可玩游戏的能力。

## 游戏效果

以下截图均为工程内置 `--screenshot` 调试命令自动生成：

| 第一人称战斗视角 | 500m×500m 海岛全景 | 结算画面 |
| --- | --- | --- |
| ![第一人称](docs/screenshots/firstperson.png) | ![海岛全景](docs/screenshots/island.png) | ![结算画面](docs/screenshots/end.png) |

## 玩法

- 你 + 23 个 AI 战士空降到 500m×500m 的海岛，赤手空拳落地
- 搜刮武器（冲锋枪/突击步枪/射手步枪）、护甲、医疗包、弹药——物资聚集在 3 座村庄（小屋/两层楼/仓库/瞭望塔）里，也有码头、废墟可探索
- 毒圈分 5 个阶段收缩，圈外持续掉血，越到后期越痛
- 地图上有 3 面旗帜据点（A/B/C），沙袋工事环绕，在圈内停留 5 秒占领，占领后**持续回血 + 伤害提升 10%**
- 春夏秋冬实时切换：地面、草木、水面、天空雾光、花瓣/落叶/雪和建筑雪盖同步变化
- 活到最后：**大吉大利，今晚吃鸡！**

## 操作

| 按键 | 功能 |
| --- | --- |
| W A S D | 移动 |
| 鼠标 | 视角 |
| 左键 | 射击 |
| 右键 | 机瞄（射手步枪带高倍镜） |
| Shift | 冲刺 |
| 空格 | 跳跃（在瞭望塔梯子处按 W 攀爬） |
| C | 趴下（更慢，扩散大幅降低） |
| G | 投掷烟雾弹（烟球遮挡 AI 视线，初始 3 枚） |
| F | 靠近吉普车驾驶 / 下车（W/S 油门倒车，A/D 转向） |
| V | 循环切换春 / 夏 / 秋 / 冬 |
| R | 换弹 / 结算后重开 |
| E | 拾取 |
| 1 / 2 | 切换武器槽 |
| Esc | 释放鼠标（点击左键或再按 Esc 重新锁定） |
| — | 窗口失去焦点自动暂停，切回自动继续 |

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
  world/props.gd         # 树木/灌木/岩石/草（树冠/草丛 MultiMesh + 行进风场 shader）
  world/season_system.gd # 四季总控：地表/植被/水片/天空雾光/天气联动
  world/tex_gen.gd       # 程序化贴图工厂：叶簇/草叶/花朵 alpha 贴图
  world/buildings.gd     # 程序化建筑：村庄（小屋/两层楼/仓库/瞭望塔/废墟）、据点沙袋工事、码头小船
  world/toon.gd          # 卡通材质工厂（toon 光照 + grow 描边）
  player/player.gd       # FPS 控制器（移动/空降/伤害/武器槽/拾取）
  player/weapon.gd       # hitscan 武器逻辑 + 程序化视模型
  player/hud.gd          # 全套 HUD（中文用内置 Noto Sans SC 渲染）
  bots/bot.gd            # AI 状态机：空降→搜刮→跑圈→占点→交战
  game/zone.gd           # 毒圈：5 阶段收缩、圈外伤害、圈墙可视化
  game/capture_point.gd  # 据点：占领进度、旗帜变色、增益归属
  game/loot.gd           # 战利品：光柱稀有度、拾取逻辑
  game/vehicle.gd        # 吉普车：F 上下车、街机驾驶、贴地形
  game/smoke_grenade.gd  # 烟雾弹：引信起烟、遮挡 AI 视线
  fx/fx.gd               # 曳光/命中特效
  fx/sfx_bank.gd         # 音效池（2D/3D）
assets/
  shaders/ground.gdshader # 多尺度地表斑驳 + 岩层 + 积雪/湿润
  shaders/grass.gdshader # 草叶广告牌化 + 行进风场阵风 + 三段色带
  shaders/water.gdshader # 深度水色 + 岸线环 + 雨滴扩散 + 冬季冰裂
  sfx/*.wav              # tools/gen_sfx.py 生成（Python 标准库），含音乐/环境音循环
  fonts/                 # Noto Sans SC（HUD 中文）
tools/
  Godot.app              # Godot 4.7.1 编辑器/运行时
  gen_sfx.py             # 音效合成脚本
```

### 调试参数（`--` 之后传入）

```bash
# 截图（窗口模式，N 帧后存图退出）
tools/Godot.app/Contents/MacOS/Godot --path . -- --screenshot /tmp/shot.png [--frames 2700] [--cam x,y,z,tx,ty,tz]
# 无头模拟整场比赛并打印进度
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 30000 -- --sim
# 玩家直接落地 + 自带步枪
tools/Godot.app/Contents/MacOS/Godot --path . -- --ground --arm
# 固定随机种子（可复现的比赛布局，便于调试/截图定位）
tools/Godot.app/Contents/MacOS/Godot --path . -- --seed 7
# 指定初始季节（spring / summer / autumn / winter）
tools/Godot.app/Contents/MacOS/Godot --path . -- --season winter
# 射击链路自检（生成测试bot并开火，打印血量）
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
- `--firetest` / `--movetest`：射击链路与移动的脚本化自检
- `--sim`：无头模拟整场比赛（24 人 + 完整毒圈流程），可挂内存/对象数探针做压测

### 真人试玩驱动修复的真实案例

- **持枪后无法转向/开火**：试玩发现「徒手正常、持枪失灵」，定位为屏幕中心准星控件（`mouse_filter=STOP`）吞掉捕获模式下的全部鼠标事件 → HUD 全部改为 `IGNORE`
- **鼠标捕获丢失后游戏「假死」**：点击左键重新锁定鼠标（标准 FPS 行为）
- **「玩着玩着卡住」**：用无头模拟赛 + 心跳/内存探针复现排查，确认游戏无泄漏、无死循环；同时针对 macOS 窗口失焦导致输入全断的问题，增加失焦自动暂停、切回自动继续
