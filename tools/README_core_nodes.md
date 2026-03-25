# 核心节点 CSV 转 JSON 工具使用说明

## ✅ 功能已添加

已成功在 `convert_skill_csv_to_json.py` 工具中添加核心节点转换功能。

---

## 🚀 使用方法

### 命令行参数

```bash
python convert_skill_csv_to_json.py --core-nodes
```

### 可选参数

```bash
# 使用默认路径（推荐）
python convert_skill_csv_to_json.py --core-nodes

# 指定输入 CSV 文件
python convert_skill_csv_to_json.py --core-nodes "path/to/core_nodes.csv"

# 指定输入和输出文件
python convert_skill_csv_to_json.py --core-nodes "path/to/core_nodes.csv" "path/to/core_nodes.json"
```

---

## 📊 转换结果

### 输入文件
- **路径**: `table/core_nodes.csv`
- **格式**: CSV（GBK 编码）
- **字段**: id, name, next, is_start, is_end, des, type, enemy, Npc

### 输出文件
- **路径**: `table/core_nodes.json`
- **格式**: JSON（UTF-8 编码）
- **结构**:
```json
{
  "core_nodes": [
    {
      "id": "1",
      "name": "初始测试 1",
      "next": ["2", "4"],
      "is_start": true,
      "is_end": false,
      "des": "起源",
      "type": 2,
      "enemy": [],
      "Npc": ["1"]
    }
  ]
}
```

---

## 📝 字段说明

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| id | string | 核心节点 ID | "1" |
| name | string | 节点名称 | "初始测试 1" |
| next | array | 下一个节点 ID 列表 | ["2", "4"] |
| is_start | boolean | 是否为初始节点 | true |
| is_end | boolean | 是否为终局节点 | false |
| des | string | 节点描述 | "起源" |
| type | number | 节点类型（1=战斗，2=奇遇，3=交易，4=奖励） | 2 |
| enemy | array | 敌人 ID 列表 | ["1"] |
| Npc | array | NPC ID 列表 | ["1"] |

---

## 🎯 转换特性

### 自动处理
- ✅ **编码识别**: 自动尝试 utf-8, gbk, gb2312, utf-8-sig
- ✅ **数组解析**: 分号分隔的字段自动转为数组（next, enemy, Npc）
- ✅ **布尔转换**: 0/1 自动转为 false/true
- ✅ **数字转换**: type 字段自动转为数字
- ✅ **空行过滤**: 自动跳过空行和无效数据

### 数据验证
- ✅ 检查最少列数（9 列）
- ✅ 验证节点 ID 和名称不为空
- ✅ 跳过无效数据行

---

## 📋 示例数据

当前转换成功的示例数据包含 5 个核心节点：

1. **初始测试 1** (id: 1)
   - 类型：奇遇关卡
   - 下一个节点：2, 4
   - NPC: 1

2. **中转测试 2** (id: 2)
   - 类型：战斗关卡
   - 下一个节点：3, 5
   - 敌人：1

3. **终点测试 3** (id: 3)
   - 类型：战斗关卡
   - 终局节点
   - 敌人：1

4. **中转测试 7** (id: 4)
   - 类型：战斗关卡
   - 下一个节点：3, 5
   - 敌人：1

5. **终点测试 5** (id: 5)
   - 类型：战斗关卡
   - 终局节点
   - 敌人：1

---

## 🔧 工具位置

```
d:\Godot\Godot_v4.6.1-stable_win64.exe\game\晋升吧骰子\tools\convert_skill_csv_to_json.py
```

---

## 📚 相关文档

- [关卡系统.md](res://docs/开发文档/关卡系统.md) - 关卡系统设计文档
- [core_nodes.csv](res://table/core_nodes.csv) - 核心节点配置表

---

## ✨ 版本历史

- **v1.0** (2026-03-21)
  - 初始版本
  - 支持 core_nodes.csv 转 JSON
  - 自动编码识别
  - 完整的字段解析和类型转换

---

**最后更新**: 2026-03-21  
**状态**: ✅ 已完成并测试通过
