# 战地3 (zhandi3)

战地式大地图 FPS × 吃鸡大逃杀框架 × 旷野之息卡通渲染。使用 **Godot 4.7.1 + GDScript** 开发，全部素材（地形、植被、武器模型、音效）程序化生成，零外部素材依赖。

## 玩法

- 你 + 23 个 AI 战士空降到 500m×500m 的海岛，赤手空拳落地
- 搜刮武器（冲锋枪/突击步枪/射手步枪）、护甲、医疗包、弹药
- 毒圈分 5 个阶段收缩，圈外持续掉血，越到后期越痛
- 地图上有 3 面旗帜据点（A/B/C），在圈内停留 5 秒占领，占领后**持续回血 + 伤害提升 10%**
- 活到最后：**大吉大利，今晚吃鸡！**

## 操作

| 按键 | 功能 |
| --- | --- |
| W A S D | 移动 |
| 鼠标 | 视角 |
| 左键 | 射击 |
| 右键 | 机瞄（射手步枪带高倍镜） |
| Shift | 冲刺 |
| 空格 | 跳跃 |
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
  world/terrain.gd       # 噪声地形 + 顶点色 + 解析高度采样 + 水面
  world/props.gd         # 树木/岩石/草（MultiMesh + 风摆 shader）
  world/toon.gd          # 卡通材质工厂（toon 光照 + grow 描边）
  player/player.gd       # FPS 控制器（移动/空降/伤害/武器槽/拾取）
  player/weapon.gd       # hitscan 武器逻辑 + 程序化视模型
  player/hud.gd          # 全套 HUD（中文用内置 Noto Sans SC 渲染）
  bots/bot.gd            # AI 状态机：空降→搜刮→跑圈→占点→交战
  game/zone.gd           # 毒圈：5 阶段收缩、圈外伤害、圈墙可视化
  game/capture_point.gd  # 据点：占领进度、旗帜变色、增益归属
  game/loot.gd           # 战利品：光柱稀有度、拾取逻辑
  fx/fx.gd               # 曳光/命中特效
  fx/sfx_bank.gd         # 音效池（2D/3D）
assets/
  shaders/grass.gdshader # 草叶风摆 + 双色渐变
  sfx/*.wav              # tools/gen_sfx.py 生成（Python 标准库）
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
# 射击链路自检（生成测试bot并开火，打印血量）
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300 -- --firetest --ground --arm
# 结算画面预览
tools/Godot.app/Contents/MacOS/Godot --path . -- --screenshot /tmp/end.png --endtest
```

### 重新生成音效

```bash
python3 tools/gen_sfx.py   # 仅依赖 Python 标准库
```
