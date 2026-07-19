# AGENTS.md

## 项目

Godot 4.7.1 + GDScript 的单机 3D FPS（战地玩法 × 吃鸡框架 × 旷野之息卡通渲染）。结构、玩法、调试命令见 README.md。

## 约定

- **一切由代码生成**：不手写复杂 .tscn；物体、材质、特效、音效全部程序化（GDScript 或 tools/gen_sfx.py）
- 脚本用 `class_name` 注册全局类；新增类后需跑一次 `--headless --import` 刷新类缓存才能编译引用它的脚本
- Godot 4 注意：描边用 `grow`（不是 grow_enabled）；shader 里实例矩阵是 `MODEL_MATRIX`（不是 INSTANCE_TRANSFORM）；**前向面是顺时针绕序**（自建网格三角形绕反会导致 trimesh 碰撞单向失效——踩过坑，terrain 已开 `backface_collision`）
- 中文文本一律走 HUD 的主题字体（assets/fonts/NotoSansCJKsc-Regular.otf），不要依赖系统字体或字形回退链
- GDScript 对 Variant 不能用 `:=` 推断（字典取值、get_nodes_in_group 返回值等），写显式类型

## 验证（改完必跑）

```bash
tools/Godot.app/Contents/MacOS/Godot --headless --path . --import            # 刷新类缓存
tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 600  # 编译+运行错误检查
tools/Godot.app/Contents/MacOS/Godot --path . -- --screenshot /tmp/x.png   # 视觉改动需截图确认
```

## 边界

- tools/Godot.app（约 100MB）与 tools/godot.zip 是本地运行时，不进版本库
- 不要引入外部素材站资源；保持工程自包含
