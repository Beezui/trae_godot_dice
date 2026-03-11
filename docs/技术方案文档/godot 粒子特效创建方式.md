# Godot 粒子特效创建方式

**创建日期**: 2026-03-09  
**Godot 版本**: 4.6.1.stable  
**用途**: 记录 Godot 4.x 中粒子系统的创建方式、核心代码和常见问题解决办法

## 一、粒子系统概述

Godot 4.x 提供两种粒子系统：
1. **GPUParticles3D** - GPU 加速的粒子系统（推荐）
2. **CPUParticles3D** - CPU 计算的粒子系统

### 选择建议
- **GPUParticles3D**: 性能更好，支持更多粒子，适合复杂效果
- **CPUParticles3D**: 兼容性好，但性能较低，适合简单效果

## 二、GPUParticles3D 创建方式

### 2.1 场景文件配置 (.tscn)

```tscn
[gd_scene format=3 uid="uid://example"]

# 定义粒子处理材质
[sub_resource type="ParticleProcessMaterial" id="ParticleProcessMaterial_1"]
emission_shape = 0
direction = Vector3(0, 1, 0)
spread = 45.0
initial_velocity_min = 5.0
initial_velocity_max = 10.0
gravity = Vector3(0, -9.8, 0)
scale_min = 0.5
scale_max = 1.5

# 定义粒子网格
[sub_resource type="SphereMesh" id="SphereMesh_1"]
radius = 0.3
height = 0.6

[node name="ExplosionParticles" type="GPUParticles3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
emitting = false
amount = 200
lifetime = 2.0
one_shot = true
explosiveness = 1.0
process_material = SubResource("ParticleProcessMaterial_1")
draw_pass_1 = SubResource("SphereMesh_1")
```

### 2.2 脚本动态创建

```gdscript
func _setup_particles():
	var particles = GPUParticles3D.new()
	particles.name = "ExplosionParticles"
	particles.position = Vector3(0, 0, 0)
	particles.emitting = false
	particles.amount = 200
	particles.lifetime = 2.0
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	# 创建粒子处理材质
	var process_material = ParticleProcessMaterial.new()
	process_material.direction = Vector3(0, 1, 0)
	process_material.spread = 45.0
	process_material.initial_velocity_min = 5.0
	process_material.initial_velocity_max = 10.0
	process_material.gravity = Vector3(0, -9.8, 0)
	process_material.scale_min = 0.5
	process_material.scale_max = 1.5
	
	# 创建粒子网格
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.3
	sphere_mesh.height = 0.6
	
	# 设置属性
	particles.process_material = process_material
	particles.draw_pass_1 = sphere_mesh
	
	add_child(particles)
```

### 2.3 触发粒子效果

```gdscript
@onready var particles = $ExplosionParticles

func _input(event):
	if event.is_action_pressed("ui_accept"):  # 空格键
		if particles:
			# 重启粒子系统
			particles.emitting = false
			particles.restart()
```

## 三、核心配置参数说明

### 3.1 GPUParticles3D 属性

| 属性 | 类型 | 说明 | 示例值 |
|------|------|------|--------|
| emitting | bool | 是否发射粒子 | false |
| amount | int | 粒子数量 | 200 |
| lifetime | float | 生命周期（秒） | 2.0 |
| one_shot | bool | 单次发射 | true |
| explosiveness | float | 爆炸性（0-1） | 1.0 |
| process_material | Material | 粒子处理材质 | ParticleProcessMaterial |
| draw_pass_1 | Mesh | 粒子网格 | SphereMesh |

### 3.2 ParticleProcessMaterial 常用属性

| 属性 | 类型 | 说明 | 示例值 |
|------|------|------|--------|
| emission_shape | int | 发射形状 | 0=点，1=球体，2=盒体 |
| direction | Vector3 | 发射方向 | Vector3(0, 1, 0) |
| spread | float | 扩散角度 | 45.0 |
| initial_velocity_min | float | 最小初始速度 | 5.0 |
| initial_velocity_max | float | 最大初始速度 | 10.0 |
| gravity | Vector3 | 重力 | Vector3(0, -9.8, 0) |
| scale_min | float | 最小缩放 | 0.5 |
| scale_max | float | 最大缩放 | 1.5 |

### 3.3 常用粒子网格

```gdscript
# 球体网格
var sphere_mesh = SphereMesh.new()
sphere_mesh.radius = 0.3
sphere_mesh.height = 0.6

# 盒体网格
var box_mesh = BoxMesh.new()
box_mesh.size = Vector3(0.5, 0.5, 0.5)

# 平面网格
var plane_mesh = PlaneMesh.new()
plane_mesh.size = Vector2(0.5, 0.5)
```

## 四、完整示例场景

### 4.1 场景文件 (sandbox_particle_test.tscn)

```tscn
[gd_scene format=3 uid="uid://sandbox_particle_test"]

[ext_resource type="Script" path="res://scenes/sandbox_particle_test.gd" id="1_particle_test"]

[sub_resource type="ParticleProcessMaterial" id="ParticleProcessMaterial_1"]
emission_shape = 0
direction = Vector3(0, 1, 0)
spread = 45.0
initial_velocity_min = 5.0
initial_velocity_max = 10.0
gravity = Vector3(0, -9.8, 0)
scale_min = 0.5
scale_max = 1.5

[sub_resource type="SphereMesh" id="SphereMesh_1"]
radius = 0.3
height = 0.6

[node name="SandboxParticleTest" type="Node3D"]
script = ExtResource("1_particle_test")

[node name="ExplosionParticles" type="GPUParticles3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
emitting = false
amount = 200
lifetime = 2.0
one_shot = true
explosiveness = 1.0
process_material = SubResource("ParticleProcessMaterial_1")
draw_pass_1 = SubResource("SphereMesh_1")
```

### 4.2 脚本文件 (sandbox_particle_test.gd)

```gdscript
extends Node3D

@onready var particles = $ExplosionParticles

func _ready():
	_setup_particles()
	print("按空格键触发粒子效果")

func _setup_particles():
	if particles:
		# 创建粒子网格
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.3
		sphere_mesh.height = 0.6
		
		# 设置粒子系统属性
		particles.draw_pass_1 = sphere_mesh
		
		print("粒子系统初始化完成，位于场景中心 (0, 0, 0)")

func _input(event):
	if event.is_action_pressed("ui_accept"):
		print("空格键被按下，触发粒子效果...")
		if particles:
			particles.emitting = false
			particles.restart()
			print("粒子效果已触发")
```

## 五、常见问题及解决办法

### 5.1 粒子不可见

**问题**: 粒子系统存在但看不到效果

**可能原因**:
1. 粒子位置不在摄像机视野内
2. 粒子太小或透明
3. 光照不足
4. 粒子被其他物体遮挡

**解决办法**:
```gdscript
# 1. 确认粒子位置在摄像机视野内
particles.position = Vector3(0, 0, 0)  # 场景中心

# 2. 增大粒子尺寸
var sphere_mesh = SphereMesh.new()
sphere_mesh.radius = 0.5  # 增大半径

# 3. 添加光源
var light = DirectionalLight3D.new()
light.position = Vector3(10, 10, 10)
add_child(light)
```

### 5.2 材质属性错误

**问题**: `Invalid assignment of property or key 'color_initial'`

**原因**: Godot 4.x 中 ParticleProcessMaterial 的属性名称与旧版本不同

**解决办法**:
```gdscript
# 错误写法（Godot 3.x）
var material = ParticlesMaterial.new()
material.color_initial = Color(1, 0, 0)

# 正确写法（Godot 4.x）
var material = ParticleProcessMaterial.new()
material.emission_color = Color(1, 0, 0)
```

### 5.3 粒子系统崩溃

**问题**: 创建 GPUParticles3D 时 Godot 崩溃

**原因**: 
1. 子资源定义顺序错误
2. 材质配置不完整

**解决办法**:
```tscn
# 确保子资源在使用之前定义
[sub_resource type="ParticleProcessMaterial" id="ParticleProcessMaterial_1"]
# ... 配置参数

[sub_resource type="SphereMesh" id="SphereMesh_1"]
# ... 配置参数

[node name="ExplosionParticles" type="GPUParticles3D"]
process_material = SubResource("ParticleProcessMaterial_1")
draw_pass_1 = SubResource("SphereMesh_1")
```

### 5.4 粒子方法不存在

**问题**: `Nonexistent function 'stop_emitting' in base 'CPUParticles3D'`

**原因**: Godot 4.x 中移除了 stop_emitting() 方法

**解决办法**:
```gdscript
# 错误写法（Godot 3.x）
particles.stop_emitting()

# 正确写法（Godot 4.x）
particles.emitting = false
```

### 5.5 粒子效果不触发

**问题**: 按空格键没有粒子效果

**可能原因**:
1. 粒子系统未正确初始化
2. emitting 属性未设置
3. restart() 调用时机不对

**解决办法**:
```gdscript
func _input(event):
	if event.is_action_pressed("ui_accept"):
		if particles:
			# 先停止发射
			particles.emitting = false
			# 然后重启
			particles.restart()
			# 可选：重新设置 emitting
			# particles.emitting = true
```

### 5.6 粒子颜色不显示（灰色）

**问题**: 粒子系统正常工作，但粒子显示为灰色，设置的橙红色无效

**调试过程**:
1. 在场景文件的 `ParticleProcessMaterial` 中设置 `color = Color(1, 0.5, 0, 1)` 无效
2. 在脚本中通过 `mat.color = Color(1, 0.5, 0, 1)` 设置也无效
3. 粒子速度、方向等参数正常，唯独颜色不生效

**原因分析**:
1. `ParticleProcessMaterial` 的 `color` 属性在某些情况下可能不被正确应用
2. GPUParticles3D 的渲染需要使用 `material_override` 来覆盖默认材质
3. 默认材质可能没有启用自发光，导致颜色暗淡

**解决办法**: 使用 StandardMaterial3D 设置自发光材质
```gdscript
func _setup_particles():
	if particles:
		# 创建粒子网格
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 1.0  # 增大粒子尺寸
		sphere_mesh.height = 2.0
		particles.draw_pass_1 = sphere_mesh
		
		# 创建自发光的 StandardMaterial3D
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(1, 0.5, 0, 1)  # 橙红色基础色
		material.emission_enabled = true  # 启用自发光
		material.emission = Color(1, 0.5, 0, 1)  # 橙红色自发光
		material.emission_energy_multiplier = 3.0  # 增强发光强度
		
		# 应用材质到粒子系统
		particles.material_override = material
		
		print("材质已设置为橙红色自发光")
```

**关键点**:
1. 使用 `StandardMaterial3D` 而不是依赖 `ParticleProcessMaterial` 的颜色属性
2. 启用 `emission_enabled = true` 让粒子自发光，不受场景光照影响
3. 设置 `emission_energy_multiplier` 增强发光效果（建议 2.0-3.0）
4. 使用 `material_override` 属性应用材质
5. 增大粒子尺寸（半径 1.0，高度 2.0）让效果更明显
6. 降低粒子速度（20-40）让粒子更容易观察

**完整示例**:
```gdscript
@onready var particles = $ExplosionParticles

func _setup_particles():
	if particles:
		# 创建粒子网格（增大尺寸）
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 1.0
		sphere_mesh.height = 2.0
		particles.draw_pass_1 = sphere_mesh
		
		# 创建自发光材质
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(1, 0.5, 0, 1)
		material.emission_enabled = true
		material.emission = Color(1, 0.5, 0, 1)
		material.emission_energy_multiplier = 3.0
		
		# 应用材质
		particles.material_override = material
		
		# 调整粒子速度（降低以便观察）
		if particles.process_material:
			var mat = particles.process_material
			mat.initial_velocity_min = 20.0
			mat.initial_velocity_max = 40.0
			mat.spread = 5.0
```

## 六、最佳实践

### 6.1 性能优化

```gdscript
# 1. 使用 one_shot 模式减少持续计算
particles.one_shot = true

# 2. 合理设置粒子数量
particles.amount = 200  # 根据效果需求调整

# 3. 设置合适的生命周期
particles.lifetime = 2.0  # 避免过长

# 4. 使用 explosiveness 控制爆发效果
particles.explosiveness = 1.0  # 瞬间爆发
```

### 6.2 代码组织

```gdscript
# 将粒子配置封装为独立函数
func _setup_particles():
	# 配置代码

# 将触发逻辑封装为独立函数
func trigger_particle_effect():
	if particles:
		particles.emitting = false
		particles.restart()
```

### 6.3 调试技巧

```gdscript
func _setup_particles():
	print("粒子系统初始化完成")
	print("位置：", particles.position)
	print("数量：", particles.amount)
	print("生命周期：", particles.lifetime)

func _input(event):
	if event.is_action_pressed("ui_accept"):
		print("触发粒子效果...")
		if particles:
			print("粒子系统存在")
			particles.restart()
			print("粒子效果已触发")
```

## 七、参考资源

- [Godot 官方文档 - GPUParticles3D](https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html)
- [Godot 官方文档 - ParticleProcessMaterial](https://docs.godotengine.org/en/stable/classes/class_particleprocessmaterial.html)
- 项目测试场景：`res://scenes/sandbox_particle_test.tscn`
- 项目模板场景：`res://scenes/sandbox_template.tscn`

## 八、更新日志

- 2026-03-09: 初始版本，记录 Godot 4.6.1 中 GPUParticles3D 的创建方式
- 记录了常见问题及解决办法
- 提供了完整的示例代码

- 2026-03-10: 新增"粒子颜色不显示（灰色）"问题及解决方案
  - 详细记录了调试过程
  - 说明使用 StandardMaterial3D 自发光材质的解决方案
  - 提供了完整的代码示例和关键配置参数
  - 强调使用 material_override 属性的重要性

- 2026-03-10: 新增"CPUParticles3D 实现火焰爆炸渐变效果"完整方案
  - 参考官方演示场景 demo/particles/test.tscn 的配置
  - 详细说明 CPUParticles3D 的渐变配置方法
  - 记录了从 GPUParticles3D 切换到 CPUParticles3D 的全过程
  - 提供了完整的场景文件配置示例

## 九、CPUParticles3D 实现火焰爆炸渐变效果（2026-03-10）

### 9.1 问题背景

**需求**: 创建一个火焰爆炸粒子效果，需要实现从黄色渐变到橙红色再到透明的效果

**初始尝试**: 使用 GPUParticles3D + ParticleProcessMaterial.color_ramp

**遇到的问题**:
1. **GPUParticles3D 渐变失效**: 设置了 color_ramp 但粒子显示为单一颜色
2. **StandardMaterial3D 覆盖渐变**: 使用 material_override 设置自发光材质时，覆盖了 color_ramp 的渐变效果
3. **Gradient API 错误**: 尝试访问 `gradient.get_point_color()` 方法不存在（Godot 4.x API 变更）
4. **粒子显示全白**: albedo_color 设置为 Color(4, 4, 4, 1) 超白色覆盖了渐变

### 9.2 解决方案

参考官方演示场景 `demo/particles/test.tscn` 中的 `CPUParticlesExplosion` 配置，改用 **CPUParticles3D**。

#### 9.2.1 为什么选择 CPUParticles3D

1. **官方推荐**: 官方演示中的爆炸效果使用 CPUParticles3D
2. **渐变稳定**: color_ramp 工作可靠，不会像 GPUParticles3D 那样失效
3. **配置简单**: 直接在场景文件中配置，无需复杂脚本
4. **性能足够**: 对于 400 个粒子的爆炸效果，性能完全够用

#### 9.2.2 完整配置示例

**场景文件** (sandbox_particle_test.tscn):

```tscn
[gd_scene format=3 uid="uid://dqihgtesi0ymh"]

[ext_resource type="Script" path="res://scenes/sandbox_particle_test.gd" id="1_particle_test"]

# 1. 定义渐变（火焰爆炸颜色：深灰→浅橙→蓝→橙→红→黑→透明）
[sub_resource type="Gradient" id="Gradient_1"]
interpolation_mode = 2
offsets = PackedFloat32Array(0, 0.131579, 0.184211, 0.321053, 0.473684, 0.752632, 1)
colors = PackedColorArray(
    0.25098, 0.25098, 0.25098, 1,      # 0%: 深灰色
    1, 0.802991, 0.664426, 1,           # 13%: 浅橙色
    1, 0.682353, 0, 1,                  # 18%: 蓝色
    1, 0.601, 0.37, 1,                  # 32%: 橙色
    1, 0.25, 0.1, 0.447059,             # 47%: 红色半透明
    0, 0, 0, 0.184314,                  # 75%: 黑色透明
    0.25098, 0.25098, 0.25098, 0        # 100%: 深灰色透明
)

# 2. 定义材质（关键：不设置 albedo_color）
[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_1"]
transparency = 1
shading_mode = 0
vertex_color_use_as_albedo = true
billboard_mode = 3
particles_anim_h_frames = 1
particles_anim_v_frames = 1
particles_anim_loop = false
proximity_fade_enabled = true
proximity_fade_distance = 0.5
# 注意：不要设置 albedo_color，让 color_ramp 控制颜色

# 3. 定义网格（关联材质）
[sub_resource type="QuadMesh" id="QuadMesh_1"]
size = Vector2(0.5, 0.5)
material = SubResource("StandardMaterial3D_1")

# 4. 定义 CPUParticles3D
[node name="ExplosionParticles" type="CPUParticles3D" parent="."]
emitting = false
amount = 400
lifetime = 1.3
explosiveness = 1.0
mesh = SubResource("QuadMesh_1")
emission_shape = 2
emission_sphere_radius = 0.25
spread = 180.0
gravity = Vector3(0, 0, 0)
initial_velocity_min = 4.0
initial_velocity_max = 4.0
angular_velocity_max = 720.0
damping_min = 3.25
damping_max = 3.25
scale_amount_min = 0.0
scale_amount_max = 1.0
angle_max = 360.0
color = Color(4, 4, 4, 1)
color_ramp = SubResource("Gradient_1")
```

**脚本文件** (sandbox_particle_test.gd):

```gdscript
extends Node3D

@onready var particles = $ExplosionParticles  # CPUParticles3D

func _ready():
    _setup_particles()
    print("按空格键触发粒子效果")

func _setup_particles():
    if particles:
        print("=== CPUParticles3D 火焰爆炸粒子配置 ===")
        print("粒子数量：", particles.amount)
        print("生命周期：", particles.lifetime, "秒")
        print("爆炸性：", particles.explosiveness)
        print("======================================")

func _input(event):
    if event.is_action_pressed("ui_accept"):  # 空格键
        print("触发粒子效果...")
        if particles:
            particles.emitting = false
            particles.restart()
            print("粒子效果已触发")
```

### 9.3 关键配置要点

#### 9.3.1 Gradient 配置

1. **interpolation_mode = 2**: 使用常量插值，颜色突变更明显
2. **offsets 和 colors**: 必须成对设置，定义颜色渐变的关键帧
3. **直接使用 Gradient**: 不要用 GradientTexture1D 包装

#### 9.3.2 StandardMaterial3D 配置

**关键要点**:
1. ✅ **vertex_color_use_as_albedo = true**: 让顶点颜色（来自 color_ramp）控制实际颜色
2. ✅ **shading_mode = 0**: 未着色模式，不受光照影响
3. ✅ **billboard_mode = 3**: 广告牌模式，粒子始终面向摄像机
4. ❌ **不要设置 albedo_color**: 会覆盖 color_ramp 的渐变效果
5. ❌ **不要使用 material_override**: 在 CPUParticles3D 中会让渐变失效

#### 9.3.3 CPUParticles3D 配置

1. **color = Color(4, 4, 4, 1)**: 高亮白色，增强整体亮度（不是渐变颜色）
2. **color_ramp = Gradient**: 应用渐变效果
3. **explosiveness = 1.0**: 瞬间爆发
4. **damping_min/max = 3.25**: 快速减速，让粒子留在爆炸区域
5. **angular_velocity_max = 720.0**: 快速旋转，增加动态效果

### 9.4 遇到的问题及解决办法

#### 问题 1: GPUParticles3D 渐变失效

**现象**: 设置了 color_ramp 但粒子显示为单一黄色

**原因**: GPUParticles3D 的 color_ramp 在某些配置下可能不工作

**解决**: 改用 CPUParticles3D，官方演示也使用 CPUParticles3D 实现爆炸效果

#### 问题 2: 粒子显示全白

**现象**: 粒子爆炸效果正常，但颜色是全白色

**原因**: 
- StandardMaterial3D 的 albedo_color 设置为 Color(4, 4, 4, 1)（超白色）
- CPUParticles3D 的 color 也设置为 Color(4, 4, 4, 1)

**解决**: 
- 移除 StandardMaterial3D 的 albedo_color 设置
- 保持 CPUParticles3D 的 color = Color(4, 4, 4, 1) 增强亮度

#### 问题 3: Gradient API 错误

**错误信息**: `Invalid access to property or key 'gradient' on a base object of type 'Gradient'`

**原因**: 脚本中尝试访问 `particles.color_ramp.gradient`，但 color_ramp 直接是 Gradient 类型，不是 GradientTexture1D

**解决**: 直接访问 Gradient 的方法：
```gdscript
# 错误写法（适用于 GradientTexture1D）
if particles.color_ramp.gradient:
    print(particles.color_ramp.gradient.get_point_count())

# 正确写法（直接使用 Gradient）
if particles.color_ramp:
    print(particles.color_ramp.get_point_count())
```

#### 问题 4: QuadMesh 没有材质

**现象**: 粒子变成透明贴图，没有材质

**原因**: QuadMesh 没有关联 StandardMaterial3D

**解决**: 在 QuadMesh 定义中添加 material 属性：
```tscn
[sub_resource type="QuadMesh" id="QuadMesh_1"]
size = Vector2(0.5, 0.5)
material = SubResource("StandardMaterial3D_1")
```

### 9.5 与 GPUParticles3D 的对比

| 特性 | GPUParticles3D | CPUParticles3D |
|------|----------------|----------------|
| 性能 | 优秀（GPU 加速） | 良好（CPU 计算） |
| 粒子数量 | 支持数千个 | 支持数百个 |
| color_ramp 稳定性 | ⚠️ 可能失效 | ✅ 稳定工作 |
| 配置复杂度 | 较复杂 | 简单 |
| 官方演示使用 | 少 | 多（爆炸效果） |
| 推荐场景 | 持续粒子效果 | 爆炸、爆发效果 |

### 9.6 最佳实践总结

1. **爆炸效果首选 CPUParticles3D**: 官方演示都这么用
2. **不要在 StandardMaterial3D 设置 albedo_color**: 让 color_ramp 控制颜色
3. **使用 vertex_color_use_as_albedo = true**: 启用顶点颜色
4. **Gradient 直接使用，不要包装**: 避免使用 GradientTexture1D
5. **color 设置为高亮白色**: Color(4, 4, 4, 1) 增强整体亮度
6. **QuadMesh 必须关联材质**: 否则粒子是透明贴图
7. **使用 billboard_mode = 3**: 让粒子始终面向摄像机

### 9.7 参考资源

- 官方演示场景：`demo/particles/test.tscn`（CPUParticlesExplosion 节点）
- 项目测试场景：`scenes/sandbox_particle_test.tscn`
- Godot 官方文档：[CPUParticles3D](https://docs.godotengine.org/en/stable/classes/class_cpuparticles3d.html)
- Godot 官方文档：[Gradient](https://docs.godotengine.org/en/stable/classes/class_gradient.html)

---

## 十、更新日志