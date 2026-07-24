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

### 3.5 相同症状的第二个根因：延迟删除导致无限循环

四季改动后再次出现“画面停止、声音仍在播放”，但这次活动监视器显示 Godot 占用约 88GB 内存。现场证据与失焦暂停完全不同：

- 固定种子战局在第 6 条季节/占点/击杀播报附近停止心跳，主线程接近 100% CPU。
- macOS `sample` 显示进程 physical footprint 已达 42.4GB，主线程持续进入 `malloc`；终止测试时记录到 67.4GB 峰值 footprint。
- 引擎内 `Performance.MEMORY_STATIC` 仍显示约 180MB，说明只看 Godot 静态内存监控会漏掉这类主线程分配风暴。

根因是 HUD 用下面的逻辑限制播报数量：

```gdscript
while container.get_child_count() > 5:
    container.get_child(0).queue_free()
```

`queue_free()` 只把节点标记为帧末删除，当前循环里的 `get_child_count()` 不会下降。因此第 6 条播报加入后条件永久为真，同一个节点被反复排队删除，CPU 和内存会在单帧内失控。

正确做法是先让容器状态立即收敛，再延迟释放：

```gdscript
while container.get_child_count() > MAX_ITEMS:
    var oldest := container.get_child(0)
    container.remove_child(oldest)
    oldest.queue_free()
```

专用回归测试会一次加入 12 条播报，并确认最终只保留 5 条：

```bash
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 30 -- --noworld --feedtest
```

期望日志：`[feedtest] items=5 expected=5`。经验：不要在同一循环中依赖任何延迟执行 API 改变循环条件；`queue_free()`、`call_deferred()` 和 `set_deferred()` 都应按这个原则审查。

### 3.6 macOS 崩溃报告可能发生在游戏尚未启动之前

用户提供的一份 `EXC_BAD_ACCESS / SIGABRT` 报告中，Godot 从启动到退出只有约 1.3 秒，工作线程都停在条件变量等待，主线程栈只有未符号化的 Godot 引擎地址，没有任何项目启动日志。这与“玩了一段时间后内存达到 88GB”的 HUD 无限循环不是同一次故障。

本轮自动化复测中，在短时间并行启动多个 Godot 进程后复现了相同形态的引擎启动崩溃，崩溃前先输出：

```text
Failed to open 'user://logs/godot<timestamp>.log'
handle_crash: Program crashed with signal 11
```

证据更符合 Godot 4.7.1 macOS 版本在默认 `user://logs` 轮转或并发写入时的引擎侧竞态，而不是游戏场景运行后的资源泄漏。验证时采用以下规避方式：

- 同一项目的 Godot 长测串行执行，不要让多个进程共用默认用户日志；
- 每个自动化进程传入唯一日志，例如 `--log-file /tmp/zhandi3-wild-long.log`；
- 报告崩溃时先核对启动时长和 `[boot]` 是否出现。没有 `[boot]` 的 1 秒启动崩溃不能用来判断玩法脚本；
- 仍需用节点数、对象数、RSS/footprint 和固定帧心跳独立验证游戏运行期内存。

经验：系统崩溃报告、游戏卡死和测试工具自身失败可能同时存在，必须先按 PID、时间、启动参数和最后一条项目日志把事件分开。

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

### 4.6 旷野地图：先塑造地理叙事，再填充细节

阔野地图没有把“更高还原度”理解为增加同一种树、石头或噪声的数量。纯噪声地形容易处处有变化却处处没有名字，玩家也无法形成方向感。本轮采用“解析式命名地貌 + 低频噪声细节”的分层方法：

- 先用可计算的距离场和曲线确定初始高原、双子山裂谷、西北雪山、东北火山、中央丘陵、S 形主河和东南支流；
- 再把噪声限制在坡面起伏、岩层和地表斑驳，不允许噪声破坏河槽、道路和兴趣点落脚面；
- 神庙、驿站、遗迹、桥和火口放在地貌节点或视线轴线上，让轮廓承担导航功能；
- 建筑先做一级剪影，再补二级结构。神庙由多边主体、穹顶、环形符文、门框和冠刺组成；驿站由厚石基、开放木架、大屋顶、柜台、马槽和灯笼组成，避免“一个发光方盒就是神庙”；
- 河流不是只放一张水平水片：地形函数必须先挖出连续河槽，水 shader 再根据高度图表达深浅、波浪和岸线泡沫，桥梁与芦苇最后沿同一条解析河线布置。

经验：程序化地图的“还原感”主要来自地貌关系、尺度层级和地标布局，而不是几何数量。每个区域都应能用一句话描述、能从远处认出，并且与玩法资源或移动方式发生关系。

### 4.7 卡通开放世界风格的边界

本项目吸收的是低多边形轮廓、色块分层、空气透视、暖冷光照和可交互地标等设计方法，不复制外部游戏的模型、贴图、关卡数据或具体资产。所有地形、建筑、角色、载具和特效继续由工程代码生成。

这条边界同时有工程价值：风格由共享 `Toon` 材质、颜色配置和几何工厂控制，季节或曝光调整可以全局生效；固定随机种子可以重建相同画面；版本库也不会逐渐变成不可审查的二进制素材集合。

## 5. 玩法模块的状态边界

### 5.1 载具

玩家进入载具后，移动由 Vehicle 接管，玩家碰撞和可见性切换，摄像机改为载具摄像机；退出时必须对称恢复。输入处理要明确“驾驶中只响应哪些玩家按键”，避免玩家控制器和载具同时消费移动输入。

经验：进入/退出、装备/卸下、暂停/恢复等成对操作，应在同一模块中保持严格对称，尤其是 camera、collision_layer、collision_mask、visible 和引用关系。

### 5.2 烟雾弹与 AI

烟雾不需要创建昂贵的体积视线系统。AI 判断射线后，再计算视线线段与烟雾球的最近距离即可决定是否遮挡。

经验：先选择满足玩法需求的最小几何模型，再考虑更复杂的渲染或物理方案。视觉烟球和 AI 遮挡逻辑可以解耦，但必须共享半径等规则常量。

### 5.3 骑乘接口必须统一状态边界

马、摩托和吉普车都通过 `driver`、`mount_player()`、`dismount_player()` 以及玩家的 `vehicle` 引用形成同一种状态协议。具体速度、转向、贴地和动画由载具自身处理，玩家只负责寻找最近的可骑乘对象并发起上下骑乘。

上下骑乘必须对称恢复以下状态：玩家可见性、碰撞层、碰撞遮罩、位置、朝向、相机归属和 `vehicle/driver` 双向引用。只恢复其中一半，常见结果是下车后隐身、没有碰撞或两个控制器同时消费 WASD。

### 5.4 游泳与滑翔要控制速度，不要直接改位置

游泳使用水平目标速度、垂直输入和水面浮力共同驱动 `CharacterBody3D`：没有输入时把角色原点拉向水面下固定深度，空格上浮、C 下潜、Shift 提速。这样玩家能稳定露头，同时保留碰撞和连续速度；把 `global_position.y` 每帧硬设为水面会导致岸边抖动和穿越碰撞。

滑翔同样继续走速度积分：将水平速度朝输入方向收敛，并把最大下坠速度限制为 `-3.1m/s`。落地、入水或松开空格时显式收起斗篷。专用回归不能只检查布尔值，还要记录高度差、垂直速度和水平位移，避免“动画展开了但物理没变”的假通过。

### 5.5 生态和投射物使用有界生命周期

石块、龙焰和能量弹共用 `WildProjectile`，只把材质、速度、伤害、尺寸和寿命作为参数。每个投射物必须同时有碰撞终止和超时终止，命中后立即退出；敌人攻击冷却也必须有下限，否则长时运行时节点数会随射击次数持续增长。

动物死亡统一通过战利品系统生成兽肉，巨龙生成龙鳞。阔野回归测试依次验证投射物实际扣血、动物死亡前后 loot 数量变化，并在结束时打印总节点数和静态内存。固定 3600 帧测试中应重复观察节点数，不能只看退出时的单点值。

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

# HUD 播报数量上限（覆盖 queue_free 延迟删除陷阱）
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 30 -- --noworld --feedtest

# 阔野玩法链路与长时生命周期
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 520 -- --wildtest --ground --arm --seed 7
tools/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/zhandi3-wild-long.log --path . --fixed-fps 60 --quit-after 3600 -- --map wild --ground --sim --seed 7
```

视觉改动不能只看编译通过；运行时问题不能只看单张截图。

### 7.1 2026-07-24 阔野版本基线

- 群岛战场固定种子运行 600 帧通过，启动时约 4634 个节点、176MB Godot 静态内存；
- `--wildtest` 依次通过背包装取、游泳浮力、滑翔限速、骑马、投射物伤害、动物肉类掉落和摩托移动；结束时约 3390 个节点、176MB 静态内存；
- 阔野固定 3600 帧长测中，第 599 到 3599 帧节点数始终为 3391，静态内存始终为 159MB，进程退出码为 0；
- HUD 播报压力测试最终保持 5 条，失焦恢复测试在 SceneTree 暂停后由 ALWAYS Timer 成功解锁；
- 鸟类飞行在速度接近竖直方向时跳过 `look_at(..., Vector3.UP)`，消除了 `Target and up vectors are colinear` 警告。

这些数字是同一 Godot 版本、固定随机种子和当前内容规模下的回归基线，不是所有机器上的硬性性能承诺。后续增加生态、粒子或建筑时，应关注趋势而不是只比较一次峰值。

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
