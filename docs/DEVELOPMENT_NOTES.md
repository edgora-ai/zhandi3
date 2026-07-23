# 开发与排障笔记

本文记录项目开发中已经遇到的问题、确认过的根因和可复用的工程方法。后续修改输入、暂停、渲染、程序化网格、音频或大规模场景前，应先阅读本文；解决新问题后，也应按“症状、证据、根因、修复、回归测试”的格式继续补充。

## 1. 工程原则

### 1.1 一切由代码生成

- 场景文件保持简单，建筑、地形、植被、载具、特效和材质由 GDScript 创建。
- 位图贴图通过程序生成，音效通过 `tools/gen_sfx.py` 生成，不依赖外部素材站。
- 重复结构优先提取工厂函数，共享 Mesh、Material、Texture 和 MultiMesh，避免大量重复资源。

这样做有利于版本审查、固定随机种子复现和自动化测试，但也意味着节点生命周期、碰撞层和资源复用必须显式管理。

### 1.2 新类先刷新类缓存

脚本使用 `class_name` 注册全局类。新增类后，引用它的其他脚本可能在类缓存更新前报错，因此第一步必须执行：

```bash
tools/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

不要把“缓存尚未刷新”误判为代码依赖错误。

### 1.3 GDScript 类型要保守

字典取值、`get_nodes_in_group()`、元数据和动态属性通常返回 Variant，不能依赖 `:=` 推断。使用显式类型，例如：

```gdscript
var target: Node3D = value
var position_value: Vector3 = data["position"]
var members: Array = get_tree().get_nodes_in_group("combatant")
```

显式类型既能避免编译错误，也能让物理、AI 和程序化生成代码更容易审查。

## 2. 输入系统的历史问题

### 2.1 持枪后不能转向或开火

症状：徒手状态正常，显示武器和准星后鼠标转向、开火失效。

根因：HUD 中位于屏幕中心的 Control 默认使用 `MOUSE_FILTER_STOP`，捕获模式下鼠标事件仍会被它吞掉，无法到达玩家的 `_unhandled_input()`。

修复：HUD 根节点和所有动态创建的子控件统一使用 `Control.MOUSE_FILTER_IGNORE`。新增 HUD 控件时必须继续遵守这一规则，不能只设置根节点，因为子控件仍可能独立拦截事件。

经验：输入故障要按“系统是否收到事件 → GUI 是否消费事件 → 玩家状态是否允许处理 → 武器是否处于冷却/换弹”逐层排查，不要直接怀疑武器逻辑。

### 2.2 鼠标捕获丢失造成“假死”

症状：画面仍在更新，但玩家不能转向或射击。

根因：Esc、应用切换或系统手势可能把鼠标从 `MOUSE_MODE_CAPTURED` 切回可见模式。

修复：鼠标未捕获时，左键只负责重新捕获，不触发本次射击；Esc 可显式释放或重新捕获。

经验：FPS 必须把“游戏暂停”和“鼠标未捕获”视为两个不同状态。画面是否更新、角色是否移动、鼠标是否可见，是区分它们的关键证据。

## 3. “画面停住但声音继续”复盘

### 3.1 症状与错误方向

试玩时游戏运行一段时间后画面和操作停止，但背景音乐仍在播放。该现象很像主线程死循环、GPU 卡死或内存泄漏，不能仅凭声音继续就下结论。

排查中使用了以下证据：

- 无头比赛心跳持续输出，节点、对象、资源和静态内存没有持续增长。
- 窗口化 3600 帧测试能够正常结束，说明渲染和游戏主循环没有稳定复现的死循环。
- 标准 Finder/Godot 切换会触发焦点暂停和恢复。
- 音频播放线程不会因为 SceneTree 暂停而自动停止，所以“还有声音”不能证明游戏逻辑仍在运行。

### 3.2 根因

窗口失焦时游戏会设置 `get_tree().paused = true`。旧实现只依赖一次 `NOTIFICATION_WM_WINDOW_FOCUS_IN` 来解除暂停；macOS 偶发漏发或错序发送恢复通知时，普通节点已经因 SceneTree 暂停而停止处理，无法自救，而音频线程继续播放，于是表现为永久卡死。

### 3.3 修复设计

- 同时处理窗口级和应用级焦点进入/离开通知。
- 用 `_focus_pause_owned` 记录暂停所有权，只解除本模块发起的暂停，不能覆盖未来菜单等系统的暂停。
- 创建 `PROCESS_MODE_ALWAYS` 的独立 Timer；即使 SceneTree 已暂停，它仍能轮询 `DisplayServer.window_is_focused()` 并恢复。
- 失焦时同步设置所有 AudioStreamPlayer 的 `stream_paused`，恢复时继续播放，让声音状态与游戏状态一致。
- 保留日志：`[focus] paused after focus loss` 和 `[focus] resumed`，方便判断卡住时是否停在焦点链路。

### 3.4 回归测试

使用以下命令模拟“已经暂停但没有收到恢复通知”，确认 ALWAYS Timer 可以自动解锁：

```bash
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 120 -- --noworld --ground --focusrecoverytest
```

期望日志顺序：

```text
[focustest] simulating a lost focus-in notification
[focus] paused after focus loss
[focustest] ALWAYS timer ticked while the scene tree was paused
[focus] resumed
```

经验：任何会暂停自身执行环境的模块，都必须提供在该环境之外运行的恢复路径。

## 4. 程序化渲染与碰撞

### 4.1 Godot 4 API 和 shader 易错点

- 描边材质使用 `grow`，不是 `grow_enabled`。
- shader 中实例变换矩阵使用 `MODEL_MATRIX`，不是 `INSTANCE_TRANSFORM`。
- 自建网格的前向面采用顺时针绕序。绕序错误可能看起来只是剔除问题，但 trimesh 单向碰撞也会失效。
- 地形碰撞已启用 `backface_collision`，其他自建 trimesh 仍应从源头保证绕序正确。

### 4.2 大规模植被

草、花和树冠卡片使用 MultiMesh，避免为每个实例创建节点。需要注意：

- MultiMesh 减少 CPU 和节点开销，不代表 GPU 成本为零；实例数量、每实例顶点数和顶点 shader 噪声计算仍会相乘。
- 尽量共享网格、shader 材质和程序化贴图。
- 关闭不必要的阴影，透明卡片优先使用 alpha scissor；大面积 alpha blend 容易产生过度绘制。
- 无头测试不会覆盖真实渲染压力，视觉功能必须补充窗口化长时运行和截图。

### 4.3 水体和程序化贴图

水体使用解析地形高度烘焙出的单通道高度图，实现深浅水色、岸线泡沫、扩散雨环、冬季冰裂和波浪。经验是把 CPU 上稳定、可复现的地形数据一次性烘焙给 GPU，而不是每帧在脚本中查询大量采样点。

树叶、草叶和花朵贴图集中在 `TexGen` 生成。新增纹理时应复用工厂和固定种子，保证截图可复现。

### 4.4 从 Elemental-Serenity 迁移的方法

本轮对照了 `/Users/ahoo/Documents/kimi/Workspaces/Elemental-Serenity`。参考工程使用 Three.js、外部 GLB 和贴图，不能直接复制到本项目；真正值得迁移的是组件组织与视觉分层方法：

- 一个 SeasonManager 保存每个季节的地面、草、树、岩石、水、天空、雾和灯光配置，再通过事件统一更新消费者。
- 地面不是单一颜色，而是基础生物群落色、宏观噪声、细节噪声、岩层、湿润和积雪的组合。
- 水体拆成基础深浅水色与独立效果层：岸线环、雨滴飞溅、冰层分别由强度参数控制。
- 场景造型依赖二级轮廓：桥板之外有立柱和绳索，墙体之外有梁柱和基座，屋顶之外有屋脊、檐口和雪盖。
- 季节变化不只是换一张颜色表，还会改变天气粒子、花朵显隐、灯光色温、雾色、曝光和水面运动。

在 Godot 版本中已迁移为：

- `SeasonSystem` 统一控制春、夏、秋、冬，支持 `V` 键和 `--season` 参数。
- `ground.gdshader` 叠加多尺度斑驳、坡面岩层、湿润与朝上表面积雪。
- `water.gdshader` 在高度图深度基础上增加雨环和冬季冰裂，并在结冰时减弱顶点波浪。
- 草、阔叶树、松树、花朵、天空、雾、三灯架设和曝光使用同一季节配置。
- 花瓣、秋叶和雪使用 CPU 更新的 MultiMesh。最初使用 GPUParticles，但窗口截图快速退出时 Godot 4.7.1 会报告内部 `ParticlesShaderRD` 未释放，因此改用资源生命周期更可控的 MultiMesh。
- 房屋增加石基、木构梁柱、十字窗棂、屋脊和檐口；仓库增加压条；码头增加高立柱和分段下垂绳索；屋顶预建雪盖并按季节显隐。

### 4.5 尚未迁移的候选项

以下能力仍值得后续按优先级评估，但不能为了“看起来更多”一次性全部塞进主循环：

1. 独立昼夜系统，以及季节 × 昼夜的组合色表、月亮和夜间灯笼。
2. 雨季/雷暴作为四季之外的天气状态，包括雨线、闪电、湿地反光和环境音交叉淡入。
3. 用程序化多通道 biome mask 同时控制道路、草密度、泥土、岩石和局部水塘，而不只是当前的噪声阈值。
4. 不规则池塘/溪流的局部水片和岸边几何。目前主要仍是全局海平面，复杂内陆水系需要与地形生成同步设计。
5. 岩石顶部苔藓、积雪方向遮罩和更丰富的低多边形岩簇。
6. 营地帐篷、篝火、萤火虫、风线等氛围组件；它们应服务于地图兴趣点，而不是平均散布。
7. 地形与植被分块、距离裁剪和 LOD。在继续增加细节前，应优先建立这一性能基础。

迁移原则：吸收配置结构、几何层次和 shader 思路；不引入参考工程的外部模型或纹理；每项迁移都必须有固定种子截图和运行时成本数据。

## 5. 玩法模块的状态边界

### 5.1 载具

玩家进入载具后，移动由 Vehicle 接管，玩家碰撞和可见性切换，摄像机改为载具摄像机；退出时必须对称恢复。输入处理要明确“驾驶中只响应哪些玩家按键”，避免玩家控制器和载具同时消费移动输入。

经验：进入/退出、装备/卸下、暂停/恢复等成对操作，应在同一模块中保持严格对称，尤其是 camera、collision_layer、collision_mask、visible 和引用关系。

### 5.2 烟雾弹与 AI

烟雾不需要创建昂贵的体积视线系统。AI 判断射线后，再计算视线线段与烟雾球的最近距离即可决定是否遮挡。

经验：先选择满足玩法需求的最小几何模型，再考虑更复杂的渲染或物理方案。视觉烟球和 AI 遮挡逻辑可以解耦，但必须共享半径等规则常量。

## 6. 音频生命周期

- 背景音乐和环境音由脚本生成的 WAV 提供，运行时设置循环区间。
- 失焦暂停必须显式设置 `stream_paused`。
- 场景退出或重载时，先停止 AudioStreamPlayer，再把 `stream` 设为 null，并清理缓存引用。
- 音频继续播放不等于 SceneTree 还在处理；诊断时要结合帧心跳和焦点日志。

## 7. 推荐验证流程

每次代码修改至少执行：

```bash
tools/Godot.app/Contents/MacOS/Godot --headless --path . --import
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 600
```

根据修改类型增加：

```bash
# 固定布局，便于复现
tools/Godot.app/Contents/MacOS/Godot --path . -- --seed 7

# 完整比赛心跳和内存观察
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 30000 -- --sim --seed 7

# 视觉检查
tools/Godot.app/Contents/MacOS/Godot --path . -- --screenshot /tmp/x.png --frames 300 --seed 7

# 射击和移动专项检查
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300 -- --firetest --ground --arm
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300 -- --movetest --ground

# 四季配置消费者联动检查
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 120 -- --noworld --ground --seasontest
```

视觉改动不能只看编译通过；运行时问题不能只看单张截图。

## 8. 卡死问题的推荐排障顺序

1. 先记录画面、AI、HUD、音乐、音效、鼠标指针中哪些仍在变化。
2. 检查 Godot 日志最后一条游戏心跳和 `[focus]` 日志，不要只看系统“应用无响应”。
3. 用固定种子和 `--sim` 排除脚本死循环、对象增长和比赛阶段相关问题。
4. 用窗口化长时测试覆盖 GPU、shader、透明材质和真实音频路径。
5. 主动切换应用、释放鼠标、进入载具、投掷烟雾、死亡和重开，检查状态切换是否对称。
6. 如果出现 macOS 崩溃报告，先核对 PID、时间、父进程和启动参数；诊断工具自身的崩溃不能混作游戏崩溃。
7. 找到根因后增加专用命令行自检，避免只依赖人工复现。

## 9. 版本库边界

- 提交源脚本、程序化生成脚本、必要的 WAV、Godot `.import` 和 `.uid` 元数据。
- 不提交 `.godot/`、`tools/Godot.app`、`tools/godot.zip`、系统日志和 `/tmp` 截图。
- 提交前运行 `git diff --check`，确认没有空白错误；提交后确认工作区干净。

## 10. 维护本文

以后每个值得保留的问题至少记录：

- 用户看见的症状；
- 用来排除错误方向的证据；
- 最终根因；
- 修复为何有效，以及状态边界；
- 能自动执行的回归测试；
- 是否产生新的性能或资源生命周期风险。

目标不是积累零散踩坑，而是让同一类问题第二次出现时可以直接按证据路径定位。
