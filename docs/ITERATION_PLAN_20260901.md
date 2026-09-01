# 迭代排期 · 2026-09-01 四维打磨

> 基线 `main@a25e2bb` · 关联 `docs/REVIEW_20260901.md` / `docs/ROADMAP.md v2` / `docs/ISSUES.md AUD-` · 约定 `fix(AUD-xxx):` + `// FIX: AUD-xxx` · 门禁见 ROADMAP v2 §1-2

## 分支策略

| 分支 | 覆盖 | 合入条件 |
|------|------|----------|
| `aud/p0-hotfix` | AUD-P0 8 项 + G-P0-3 落点 | 每项 headless 全绿 + 探针/截图 后合入 main |
| `aud/p1-iteration` | AUD-P1 7 项 | 同上，帧率门禁 P50≥60 |
| `aud/p2-polish` | 打磨项（云/水/据点/任务/Stinger） | 视觉抽检 + 长测不发散 |

> 单项单分支单验证，不批量合入；每周至少一次窗口截图抽检。

## Phase 1 热修 1-2d（阻断，不修则手柄不可玩/首刷卡/穿帮）

| 顺序 | ID | 一句话 | 负责人 | 分支 | 验收锚点 |
|------|----|--------|--------|------|----------|
| 1 | AUD-P0-1 | 摇杆 deadzone+7 冲突 | — | aud/p0-hotfix | `grep deadzone` 0.18；手柄完成一局 |
| 2 | AUD-P0-2 | 载具 InputMap 化 | — | aud/p0-hotfix | `is_key_pressed` 清零；手柄驾驶 20m |
| 3 | AUD-P0-3 | coyote+buffer | — | aud/p0-hotfix | 100 次楼梯跳 >98% |
| 4 | AUD-P0-4 | GLB preload 池化 | — | aud/p0-hotfix | `[boot_t]` -60% |
| 5 | AUD-P0-6 | 弹孔池全检 | — | aud/p0-hotfix | `--reloadtest` 零 freed |
| 6 | AUD-P0-7 | 烟雾/爆炸昼夜雾一致 | — | aud/p0-hotfix | 夜景烟雾 ≤40% |
| 7 | AUD-P0-8 | 水面/闪电/云池化 | — | aud/p0-hotfix | 水面 1.4→0.7ms；云 1 draw |
| 8 | G-P0-3 | 落点补 ammo 45 | — | aud/p0-hotfix | 空手进圈率 0 |
| 9 | AUD-P0-5 | 描边分级 | — | aud/p0-hotfix | draw -30% |

**Phase 1 准出**：`--wildtest` / `--sim` / `--feedtest` / `--focusrecoverytest` / `--seasontest` --reloadtest 全绿且零 ERROR；窗口手柄/跳跃/骑乘/烟雾/夜景各 1 次无回退。预计落地后 `docs/ISSUES.md` 9 行状态改为“已修”。

## Phase 2 迭代 1 周

| 顺序 | ID | 一句话 | 验收 |
|------|----|--------|------|
| 1 | AUD-P1-3 | 移动/射击曲线可学习 | `--firetest` TTK 拉开 15% |
| 2 | AUD-P1-4 | GPU 粒子池 | 零 new Material |
| 3 | AUD-P1-1 | 地形 LOD | 低端 30fps |
| 4 | AUD-P1-2 | 建筑共享 | draw -15% |
| 5 | AUD-P1-5 | 局外天赋 | 重载生效 |
| 6 | AUD-P1-6 | 种子化地标 | 7 vs 13 不一致 |
| 7 | AUD-P1-7 | 雨雪生存化 | 湿时探针达标 |

**Phase 2 准出**：帧率门禁 + 探针全绿 + 长测经济不发散。

## Phase 3 打磨 按需

- 云 MultiMesh 收口、水面 varying 化收口、据点雷达、任务二段、Stinger 专用采样、`*.import` 分级、PBR/Toon 收敛

## 验证矩阵（每项必跑）

```bash
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 600
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 520 -- --wildtest --ground --arm --seed 7
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 120 -- --noworld --ground --focusrecoverytest
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 120 -- --noworld --ground --seasontest
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 30  -- --noworld --feedtest
tools/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --quit-after 30000 --path . -- --sim --seed 7
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300 -- --firetest --ground --arm --seed 7
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 720 -- --reloadtest --seed 7  # AUD-P0-6
tools/Godot.app/Contents/MacOS/Godot --path . -- --screenshot /tmp/aud_night.png --frames 300 --seed 7  # AUD-P0-7/8
```

## 跟踪

- 每项合入时同步更新 `docs/ISSUES.md` 对应行 `状态=已修(commit)` 并在 `docs/REVIEW_20260901.md` 打勾
- 视觉任务附前后截图；数值任务附 KPI 行可 grep
