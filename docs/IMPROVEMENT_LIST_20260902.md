# 改进清单与验收标准 · 2026-09-02

> 来源：双路专业审查（建模/动作/画风 6.2/7.0/7.4/5.8 + 操作/音乐 7.2/6.8/7.0/6.5/5.8）+ 玩家实测反馈（脚步/动物乱跑/死亡卡住）
> 规则：每项 = 改动 + 验收命令/探针；完成后状态置 ✅；涉及渲染外观项默认不碰（历史教训：树草水面被改坏过）
> 基座 HEAD=42e1100

## 一、手感受控项（操作审查）

| # | 项 | 改动 | 验收标准 | 状态 |
|---|----|------|----------|------|
| F1 | 摩擦/AIR 分离 | FRICTION 18→28；AIR_ACCEL 14→8 | 无输入急停 <0.3s；空中 90° 急转半径变大（--movetest 位移对比） | ✅ 42e1100 |
| F2 | recoil 可压枪 | rifle .35→.62 dmr 1.2→1.55 smg .2→.38 sg 1.6→1.9 lmg .5→.7；ADS 差异化保留 | --firetest 连发弹着垂直散布可读（有方向性而非纯随机） | ✅ 42e1100 |
| F3 | bloom 持续压制代价 | smg recovery 4.5→3.2；lmg 3.6→2.8 | 连发 3s 后散布仍偏高（恢复变慢） | ✅ 42e1100 |
| F4 | shake 平滑 | 白噪 → 阻尼正弦 | 高 amp 不再雪花（目检） | ⬜ 未做 |
| F5 | 载具转向曲线统一 | vehicle/moto 线性 → 马方案 pow(1.5) 指数 | 高速转向率明显低于低速（数据可测） | ⬜ 未做 |
| F6 | 摩托引擎音 | 搬 vehicle 引擎块，pitch .85→1.65 | 骑乘可闻 RPM 随速 | ⬜ 未做 |
| F7 | 木筏惯性 | move_toward 4.0 → lerpf(6→3, ratio)+回弹 | 松手滑行减速非瞬停（--ridertest 位移曲线） | ⬜ 未做 |

## 二、音频补缺项（操作审查）

| # | 项 | 改动 | 验收标准 | 状态 |
|---|----|------|----------|------|
| A1 | kill_confirm 击杀音 | SOUNDS 别名+玩家击杀触发 | 击杀时 sfx play kill_confirm 日志 | ✅ 42e1100 |
| A2 | 蹄声独立 | horse 用 footstep_sand pitch 0.75 替代 heavy_impact 复用作蹄 | 疾驰音与重击音不同采样（听感+日志音名） | ⬜ 未做 |
| A3 | 命中层优先级 | hit/headshot 独立小池防枪声抢占 | 8 枪并发时 hit 不丢（日志计数） | ⬜ 未做 |

## 三、模型/一致性项（建模审查）

| # | 项 | 改动 | 验收标准 | 状态 |
|---|----|------|----------|------|
| M1 | 头盒贴合视觉 | 熊 .68→.62 狼 .38→.34 猪 .42→.38 | 爆头判定 ≈ 视觉头 1.10× | ✅ 42e1100 |
| M2 | 屋顶碰撞 | hip/gable 屋顶补 Box col | 无法跳穿屋顶入屋（--ground 出生地旁房顶站立） | ✅ 42e1100 |
| M3 | 野兽死亡轴向 | creatures.py die (0,78,0)→绕X侧倒（需 blender 重导） | 无法在本仓直接验证，标注待 blender 环境 | ⬜ 需blender |
| M4 | wild_world 共享 Mesh | _part 复用 _shared_box_mats 模式 | boot 节点数/内存下降（[boot] mem 对比） | ⬜ 未做 |
| M5 | 血月 rim 同步 | day_night 血月分支 rim/fill 压暗 | 血月角色剪影不再冷白（截图对比） | ⬜ 未做 |

## 四、已修玩家反馈（前序）

| 项 | 状态 |
|----|------|
| 脚步材质化（Terrain.surface_at 雪/沙/岩/草）+ bot 复用 | ✅ 149ef68 |
| 动物逃跑锚定 4s + home 60m（不再乱跑） | ✅ 149ef68 |
| 动物死亡倒地回收（无 die 剪辑侧躺+tween） | ✅ 6fe6271 |
| coyote/buffer/弹孔池巡检/落点弹药 | ✅ 1ad1c1f |
| bot 同队不互射+残血后拉+武器距离窗 | ✅ 6ae1384 |
| 引擎音随速/拾取稀有度升格 | ✅ da06f44/1635607 |
| 视觉回滚（水面/植被/野兽 glb 恢复 a25e2bb） | ✅ 4428984 |

## 验收门禁（每项改动必跑）

```bash
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 600     # 零 SCRIPT ERROR
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 520 -- --wildtest --ground --arm --seed 7  # 全断言
# 动视觉项附 --screenshot 同起点同帧像素对比（阈值 <1.5）
```
