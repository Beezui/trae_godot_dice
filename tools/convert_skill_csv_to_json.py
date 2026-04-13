#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Skill CSV to JSON Converter
将 skill.csv 转换为 skill.json 格式

CSV 格式说明：
- 使用逗号分隔
- 表头：id, 名称，描述，图标，p1, p2, p3, p4, p5, p6
- p1-p6 为参数计算公式，支持 str（力量）、agi（敏捷）、int（智力）
- 描述中的 p1/p2 等占位符会自动关联到对应的计算公式
"""

import csv
import json
import os
import sys

def convert_csv_to_json(csv_path, json_path):
    """将 CSV 文件转换为 JSON 格式"""
    
    print("=" * 50)
    print("Skill CSV to JSON Converter")
    print("=" * 50)
    print()
    
    # 尝试不同的编码读取 CSV
    encodings = ['utf-8', 'gbk', 'gb2312', 'utf-8-sig']
    content = None
    used_encoding = None
    
    for encoding in encodings:
        try:
            with open(csv_path, 'r', encoding=encoding) as f:
                content = f.read()
                used_encoding = encoding
                print(f"✓ Successfully read CSV with encoding: {encoding}")
                break
        except Exception as e:
            continue
    
    if not content:
        print("✗ Error: Cannot read CSV file with any encoding")
        return False
    
    lines = content.strip().split('\n')
    if len(lines) < 2:
        print("✗ Error: CSV file has no data rows")
        return False
    
    # 读取表头
    header = [h.strip() for h in lines[0].split(',')]
    print(f"CSV Header: {header}")
    print()
    
    # 解析数据
    skills = []
    
    for i in range(1, len(lines)):
        line = lines[i].strip()
        if not line:
            continue
        
        print(f"Processing line {i+1}...")
        
        # 使用 csv 模块解析（处理引号内的逗号）
        try:
            reader = csv.reader([line])
            values = next(reader)
        except Exception as e:
            print(f"  ✗ Error parsing line: {e}")
            continue
        
        if len(values) < 4:
            print(f"  ✗ Warning: Insufficient columns, skipping")
            continue
        
        # 提取基本信息
        skill_id = values[0].strip()
        skill_name = values[1].strip()
        skill_description = values[2].strip()
        skill_icon = values[3].strip() if len(values) > 3 else ''
        
        print(f"  Skill ID: {skill_id}")
        print(f"  Skill Name: {skill_name}")
        
        # 提取参数公式（p1, p2, ...）
        parameters = {}
        attribute_dice = {}
        damage_formulas = {}
        
        # 从表头查找 p1-p6 的索引
        p_indices = {}
        for idx, col_name in enumerate(header):
            if col_name.startswith('p') and col_name[1:].isdigit():
                p_num = col_name[1:]
                p_indices[p_num] = idx
        
        # 解析每个参数
        for p_num in sorted(p_indices.keys()):
            idx = p_indices[p_num]
            if idx < len(values):
                formula = values[idx].strip()
                if formula:
                    parameters[f'p{p_num}'] = formula
                    print(f"  p{p_num} = {formula}")
                    
                    # 分析公式，提取属性类型
                    if 'str' in formula:
                        attribute_dice[p_num] = '力量'
                    elif 'agi' in formula:
                        attribute_dice[p_num] = '敏捷'
                    elif 'int' in formula:
                        attribute_dice[p_num] = '智力'
                    
                    # 添加到伤害公式
                    damage_formulas[f'p{p_num}'] = formula
        
        skill = {
            'id': skill_id,
            'name': skill_name,
            'description': skill_description,
            'icon': skill_icon,
            'parameters': parameters,
            'attribute_dice': attribute_dice,
            'damage_formulas': damage_formulas
        }
        
        skills.append(skill)
        print(f"  ✓ Added skill: {skill_id} - {skill_name}")
        print(f"    Attributes: {attribute_dice}")
    
    # 创建 JSON 结构
    output = {
        'skills': skills
    }
    
    # 写入 JSON 文件（UTF-8 编码）
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print()
    print("=" * 50)
    print("✓ Conversion completed successfully!")
    print(f"  Total skills: {len(skills)}")
    print(f"  Output file: {json_path}")
    print("=" * 50)
    
    return True

def convert_skill_dices_csv_to_json(csv_path, json_path):
    """将 SkillDices.csv 转换为 JSON 格式"""
    
    print("=" * 50)
    print("Skill Dices CSV to JSON Converter")
    print("=" * 50)
    print()
    
    encodings = ['utf-8', 'gbk', 'gb2312', 'utf-8-sig']
    content = None
    used_encoding = None
    
    for encoding in encodings:
        try:
            with open(csv_path, 'r', encoding=encoding) as f:
                content = f.read()
                used_encoding = encoding
                print(f"✓ Successfully read CSV with encoding: {encoding}")
                break
        except Exception as e:
            continue
    
    if not content:
        print("✗ Error: Cannot read CSV file with any encoding")
        return False
    
    lines = content.strip().split('\n')
    if len(lines) < 2:
        print("✗ Error: CSV file has no data rows")
        return False
    
    header = [h.strip() for h in lines[0].split(',')]
    print(f"CSV Header: {header}")
    print()
    
    skill_dices = []
    
    for i in range(1, len(lines)):
        line = lines[i].strip()
        if not line:
            continue
        
        print(f"Processing line {i+1}...")
        
        try:
            reader = csv.reader([line])
            values = next(reader)
        except Exception as e:
            print(f"  ✗ Error parsing line: {e}")
            continue
        
        if len(values) < 3:
            print(f"  ✗ Warning: Insufficient columns, skipping")
            continue
        
        dice_id = values[0].strip()
        face_count = int(values[1].strip()) if values[1].strip().isdigit() else 6
        skill_ids_str = values[2].strip()
        
        print(f"  Dice ID: {dice_id}")
        print(f"  Face Count: {face_count}")
        
        skill_ids = []
        if skill_ids_str:
            skill_ids = [s.strip() for s in skill_ids_str.split(';')]
        
        print(f"  Skill IDs: {skill_ids}")
        
        skill_dice = {
            'id': dice_id,
            'face_count': face_count,
            'skill_ids': skill_ids
        }
        
        skill_dices.append(skill_dice)
        print(f"  ✓ Added skill dice: {dice_id}")
    
    output = {
        'skill_dices': skill_dices
    }
    
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print()
    print("=" * 50)
    print("✓ Skill Dices conversion completed successfully!")
    print(f"  Total skill dices: {len(skill_dices)}")
    print(f"  Output file: {json_path}")
    print("=" * 50)
    
    return True


def convert_attr_dices_csv_to_json(csv_path, json_path):
    """将 AttrDices.csv 转换为 JSON 格式"""
    
    print("=" * 50)
    print("Attribute Dices CSV to JSON Converter")
    print("=" * 50)
    print()
    
    encodings = ['utf-8', 'gbk', 'gb2312', 'utf-8-sig']
    content = None
    used_encoding = None
    
    for encoding in encodings:
        try:
            with open(csv_path, 'r', encoding=encoding) as f:
                content = f.read()
                used_encoding = encoding
                print(f"✓ Successfully read CSV with encoding: {encoding}")
                break
        except Exception as e:
            continue
    
    if not content:
        print("✗ Error: Cannot read CSV file with any encoding")
        return False
    
    lines = content.strip().split('\n')
    if len(lines) < 2:
        print("✗ Error: CSV file has no data rows")
        return False
    
    header = [h.strip() for h in lines[0].split(',')]
    print(f"CSV Header: {header}")
    print()
    
    attr_dices = []
    
    for i in range(1, len(lines)):
        line = lines[i].strip()
        if not line:
            continue
        
        print(f"Processing line {i+1}...")
        
        try:
            reader = csv.reader([line])
            values = next(reader)
        except Exception as e:
            print(f"  ✗ Error parsing line: {e}")
            continue
        
        if len(values) < 3:
            print(f"  ✗ Warning: Insufficient columns, skipping")
            continue
        
        dice_id = values[0].strip()
        attr_name = values[1].strip()
        points_color = values[2].strip()
        
        print(f"  Dice ID: {dice_id}")
        print(f"  Attribute Name: {attr_name}")
        print(f"  Points Color: {points_color}")
        
        attr_dice = {
            'id': dice_id,
            'attr_name': attr_name,
            'points_color': points_color
        }
        
        attr_dices.append(attr_dice)
        print(f"  ✓ Added attribute dice: {dice_id}")
    
    output = {
        'attr_dices': attr_dices
    }
    
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print()
    print("=" * 50)
    print("✓ Attribute Dices conversion completed successfully!")
    print(f"  Total attribute dices: {len(attr_dices)}")
    print(f"  Output file: {json_path}")
    print("=" * 50)
    
    return True


def convert_num_dices_csv_to_json(csv_path, json_path):
    """将 NumDices.csv 转换为 JSON 格式"""
    
    print("=" * 50)
    print("Num Dices CSV to JSON Converter")
    print("=" * 50)
    print()
    
    encodings = ['utf-8', 'gbk', 'gb2312', 'utf-8-sig']
    content = None
    used_encoding = None
    
    for encoding in encodings:
        try:
            with open(csv_path, 'r', encoding=encoding) as f:
                content = f.read()
                used_encoding = encoding
                print(f"✓ Successfully read CSV with encoding: {encoding}")
                break
        except Exception as e:
            continue
    
    if not content:
        print("✗ Error: Cannot read CSV file with any encoding")
        return False
    
    lines = content.strip().split('\n')
    if len(lines) < 2:
        print("✗ Error: CSV file has no data rows")
        return False
    
    header = [h.strip() for h in lines[0].split(',')]
    print(f"CSV Header: {header}")
    print()
    
    num_dices = []
    
    for i in range(1, len(lines)):
        line = lines[i].strip()
        if not line:
            continue
        
        print(f"Processing line {i+1}...")
        
        try:
            reader = csv.reader([line])
            values = next(reader)
        except Exception as e:
            print(f"  ✗ Error parsing line: {e}")
            continue
        
        if len(values) < 4:
            print(f"  ✗ Warning: Insufficient columns, skipping")
            continue
        
        dice_id = values[0].strip()
        face_count = int(values[1].strip()) if values[1].strip().isdigit() else 6
        values_str = values[2].strip()
        textures_str = values[3].strip()
        
        print(f"  Dice ID: {dice_id}")
        print(f"  Face Count: {face_count}")
        
        # 解析点数（处理引号内的逗号）- 使用数组格式
        values = []
        if values_str:
            # 移除引号
            values_str = values_str.strip('"')
            value_array = values_str.split(',')
            for idx in range(len(value_array)):
                values.append(int(value_array[idx].strip()))
        
        print(f"  Values: {values}")
        
        # 解析贴图 ID（处理引号内的逗号）- 使用数组格式
        textures = []
        if textures_str:
            # 移除引号
            textures_str = textures_str.strip('"')
            texture_array = textures_str.split(',')
            for idx in range(len(texture_array)):
                texture_id = texture_array[idx].strip()
                texture_name = "dice_face_" + texture_id
                texture_path = "res://textures/dice/" + texture_name + ".png"
                textures.append(texture_path)
        
        print(f"  Textures: {textures}")
        
        num_dice = {
            'id': dice_id,
            'face_count': face_count,
            'values': values,
            'textures': textures
        }
        
        num_dices.append(num_dice)
        print(f"  ✓ Added num dice: {dice_id}")
    
    output = {
        'num_dices': num_dices
    }
    
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print()
    print("=" * 50)
    print("✓ Num Dices conversion completed successfully!")
    print(f"  Total num dices: {len(num_dices)}")
    print(f"  Output file: {json_path}")
    print("=" * 50)
    
    return True


def convert_hero_csv_to_json(csv_path, json_path):
    """将 hero.csv 转换为 JSON 格式"""
    
    print("=" * 50)
    print("Hero CSV to JSON Converter")
    print("=" * 50)
    print()
    
    encodings = ['utf-8', 'gbk', 'gb2312', 'utf-8-sig']
    content = None
    used_encoding = None
    
    for encoding in encodings:
        try:
            with open(csv_path, 'r', encoding=encoding) as f:
                content = f.read()
                used_encoding = encoding
                print(f"✓ Successfully read CSV with encoding: {encoding}")
                break
        except Exception as e:
            continue
    
    if not content:
        print("✗ Error: Cannot read CSV file with any encoding")
        return False
    
    lines = content.strip().split('\n')
    if len(lines) < 2:
        print("✗ Error: CSV file has no data rows")
        return False
    
    header = [h.strip() for h in lines[0].split(',')]
    print(f"CSV Header: {header}")
    print()
    
    heroes = []
    
    for i in range(1, len(lines)):
        line = lines[i].strip()
        if not line:
            continue
        
        print(f"Processing line {i+1}...")
        
        try:
            reader = csv.reader([line])
            values = next(reader)
        except Exception as e:
            print(f"  ✗ Error parsing line: {e}")
            continue
        
        if len(values) < 11:
            print(f"  ✗ Warning: Insufficient columns, skipping")
            continue
        
        # 提取数据
        hero_id = values[0].strip()
        name = values[1].strip()
        
        # 跳过空数据行
        if not hero_id or not name:
            print(f"  ✗ Warning: Empty hero ID or name, skipping")
            continue
        
        # 使用分号作为数组分隔符
        attr_str = [s.strip() for s in values[2].strip().strip('"').split(';')] if values[2].strip() else []
        attr_agi = [s.strip() for s in values[3].strip().strip('"').split(';')] if values[3].strip() else []
        attr_int = [s.strip() for s in values[4].strip().strip('"').split(';')] if values[4].strip() else []
        attr_hp = values[5].strip()
        skill_slot = values[6].strip()
        # skill_dice_id 现在是个数组
        skill_dice_id = [s.strip() for s in values[7].strip().strip('"').split(';')] if values[7].strip() else []
        texture = [s.strip() for s in values[8].strip().strip('"').split(';')] if values[8].strip() else []
        portrait = values[9].strip()
        # hero_texture 是角色属性骰子的六个状态贴图（idle, hit, attack, anger, happy, die）
        hero_texture = [s.strip() for s in values[10].strip().strip('"').split(';')] if values[10].strip() else []
        
        print(f"  Hero ID: {hero_id}")
        print(f"  Name: {name}")
        print(f"  Strength: {attr_str}")
        print(f"  Agility: {attr_agi}")
        print(f"  Intelligence: {attr_int}")
        print(f"  HP: {attr_hp}")
        print(f"  Skill Slot: {skill_slot}")
        print(f"  Skill Dice ID: {skill_dice_id}")
        print(f"  Texture: {texture}")
        print(f"  Portrait: {portrait}")
        print(f"  Hero Texture: {hero_texture}")
        
        hero = {
            'id': hero_id,
            'name': name,
            'attr_str': attr_str,
            'attr_agi': attr_agi,
            'attr_int': attr_int,
            'attr_hp': attr_hp,
            'skill_slot': skill_slot,
            'skill_dice_id': skill_dice_id,
            'texture': texture,
            'portrait': portrait,
            'hero_texture': hero_texture
        }
        
        heroes.append(hero)
        print(f"  ✓ Added hero: {hero_id}")
    
    output = {
        'heroes': heroes
    }
    
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print()
    print("=" * 50)
    print("✓ Hero conversion completed successfully!")
    print(f"  Total heroes: {len(heroes)}")
    print(f"  Output file: {json_path}")
    print("=" * 50)
    
    return True


def convert_scenes_csv_to_json(csv_path, json_path):
    """将 scenes.csv 转换为 JSON 格式"""
    
    print("=" * 50)
    print("Scenes CSV to JSON Converter")
    print("=" * 50)
    print()
    
    encodings = ['utf-8', 'gbk', 'gb2312', 'utf-8-sig']
    content = None
    used_encoding = None
    
    for encoding in encodings:
        try:
            with open(csv_path, 'r', encoding=encoding) as f:
                content = f.read()
                used_encoding = encoding
                print(f"✓ Successfully read CSV with encoding: {encoding}")
                break
        except Exception as e:
            continue
    
    if not content:
        print("✗ Error: Cannot read CSV file with any encoding")
        return False
    
    lines = content.strip().split('\n')
    if len(lines) < 2:
        print("✗ Error: CSV file has no data rows")
        return False
    
    header = [h.strip() for h in lines[0].split(',')]
    print(f"CSV Header: {header}")
    print()
    
    scenes = []
    
    for i in range(1, len(lines)):
        line = lines[i].strip()
        if not line:
            continue
        
        print(f"Processing line {i+1}...")
        
        try:
            reader = csv.reader([line])
            values = next(reader)
        except Exception as e:
            print(f"  ✗ Error parsing line: {e}")
            continue
        
        if len(values) < 3:
            print(f"  ✗ Warning: Insufficient columns, skipping")
            continue
        
        # 提取数据
        scene_id = values[0].strip()
        scene_name = values[1].strip()
        scene_path = values[2].strip()
        
        # 跳过空数据行
        if not scene_id or not scene_name:
            print(f"  ✗ Warning: Empty scene ID or name, skipping")
            continue
        
        print(f"  Scene ID: {scene_id}")
        print(f"  Scene Name: {scene_name}")
        print(f"  Scene Path: {scene_path}")
        
        scene = {
            'id': scene_id,
            'name': scene_name,
            'path': scene_path
        }
        
        scenes.append(scene)
        print(f"  ✓ Added scene: {scene_id}")
    
    output = {
        'scenes': scenes
    }
    
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print()
    print("=" * 50)
    print("✓ Scenes conversion completed successfully!")
    print(f"  Total scenes: {len(scenes)}")
    print(f"  Output file: {json_path}")
    print("=" * 50)
    
    return True





def convert_core_nodes_csv_to_json(csv_path, json_path):
    """将 core_nodes.csv 转换为 JSON 格式"""
    
    print("=" * 50)
    print("Core Nodes CSV to JSON Converter")
    print("=" * 50)
    print()
    
    encodings = ['utf-8', 'gbk', 'gb2312', 'utf-8-sig']
    content = None
    used_encoding = None
    
    for encoding in encodings:
        try:
            with open(csv_path, 'r', encoding=encoding) as f:
                content = f.read()
                used_encoding = encoding
                print(f"✓ Successfully read CSV with encoding: {encoding}")
                break
        except Exception as e:
            continue
    
    if not content:
        print("✗ Error: Cannot read CSV file with any encoding")
        return False
    
    lines = content.strip().split('\n')
    if len(lines) < 2:
        print("✗ Error: CSV file has no data rows")
        return False
    
    header = [h.strip() for h in lines[0].split(',')]
    print(f"CSV Header: {header}")
    print()
    
    core_nodes = []
    
    for i in range(1, len(lines)):
        line = lines[i].strip()
        if not line:
            continue
        
        print(f"Processing line {i+1}...")
        
        try:
            reader = csv.reader([line])
            values = next(reader)
        except Exception as e:
            print(f"  ✗ Error parsing line: {e}")
            continue
        
        if len(values) < 12:
            print(f"  ✗ Warning: Insufficient columns, skipping")
            continue
        
        # 提取数据
        node_id = values[0].strip()
        name = values[1].strip()
        
        # 跳过空数据行
        if not node_id or not name:
            print(f"  ✗ Warning: Empty node ID or name, skipping")
            continue
        
        # 解析 next 字段（分号分隔的数组）
        next_str = values[2].strip()
        next_nodes = []
        if next_str:
            next_nodes = [n.strip() for n in next_str.split(';')]
        
        # 解析 is_start 和 is_end
        is_start = values[3].strip()
        is_end = values[4].strip()
        
        # 解析描述字段
        des1 = values[5].strip()
        des2 = values[6].strip()
        
        # 解析其他字段
        type_ = values[7].strip()
        enemy = values[8].strip()
        npc = values[9].strip()
        scene = values[10].strip()
        textures = values[11].strip()
        
        print(f"  Node ID: {node_id}")
        print(f"  Name: {name}")
        print(f"  Next Nodes: {next_nodes}")
        print(f"  Is Start: {is_start}")
        print(f"  Is End: {is_end}")
        print(f"  Description 1: {des1}")
        print(f"  Description 2: {des2}")
        print(f"  Type: {type_}")
        print(f"  Enemy: {enemy}")
        print(f"  NPC: {npc}")
        print(f"  Scene: {scene}")
        print(f"  Textures: {textures}")
        
        core_node = {
            'id': node_id,
            'name': name,
            'next': next_nodes,
            'is_start': is_start,
            'is_end': is_end,
            'des1': des1,
            'des2': des2,
            'type': type_,
            'enemy': enemy,
            'npc': npc,
            'scene': scene,
            'textures': textures
        }
        
        core_nodes.append(core_node)
        print(f"  ✓ Added core node: {node_id}")
    
    output = {
        'core_nodes': core_nodes
    }
    
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print()
    print("=" * 50)
    print("✓ Core Nodes conversion completed successfully!")
    print(f"  Total core nodes: {len(core_nodes)}")
    print(f"  Output file: {json_path}")
    print("=" * 50)
    
    return True


def convert_random_nodes_csv_to_json(csv_path, json_path):
    """将 random_nodes.csv 转换为 JSON 格式"""
    
    print("=" * 50)
    print("Random Nodes CSV to JSON Converter")
    print("=" * 50)
    print()
    
    encodings = ['utf-8', 'gbk', 'gb2312', 'utf-8-sig']
    content = None
    used_encoding = None
    
    for encoding in encodings:
        try:
            with open(csv_path, 'r', encoding=encoding) as f:
                content = f.read()
                used_encoding = encoding
                print(f"✓ Successfully read CSV with encoding: {encoding}")
                break
        except Exception as e:
            continue
    
    if not content:
        print("✗ Error: Cannot read CSV file with any encoding")
        return False
    
    lines = content.strip().split('\n')
    if len(lines) < 2:
        print("✗ Error: CSV file has no data rows")
        return False
    
    header = [h.strip() for h in lines[0].split(',')]
    print(f"CSV Header: {header}")
    print()
    
    random_nodes = []
    
    for i in range(1, len(lines)):
        line = lines[i].strip()
        if not line:
            continue
        
        print(f"Processing line {i+1}...")
        
        try:
            reader = csv.reader([line])
            values = next(reader)
        except Exception as e:
            print(f"  ✗ Error parsing line: {e}")
            continue
        
        if len(values) < 6:
            print(f"  ✗ Warning: Insufficient columns, skipping")
            continue
        
        # 提取数据
        node_id = values[0].strip()
        node_name = values[1].strip()
        
        # 跳过空数据行
        if not node_id or not node_name:
            print(f"  ✗ Warning: Empty node ID or name, skipping")
            continue
        
        # 解析 type（整数）
        node_type = int(values[2].strip()) if values[2].strip().isdigit() else 0
        
        # 解析 weight（浮点数）
        weight_str = values[3].strip()
        weight = float(weight_str) if weight_str.replace('.', '').isdigit() else 1.0
        
        des = values[4].strip()
        
        # 解析 npc 字段（分号分隔的数组）
        npc_str = values[5].strip()
        npcs = []
        if npc_str:
            npcs = [n.strip() for n in npc_str.split(';') if n.strip()]
        
        # 解析 scene 字段
        scene = values[6].strip() if len(values) > 6 else ''
        
        print(f"  Node ID: {node_id}")
        print(f"  Node Name: {node_name}")
        print(f"  Type: {node_type}")
        print(f"  Weight: {weight}")
        print(f"  Description: {des}")
        print(f"  NPCs: {npcs}")
        print(f"  Scene: {scene}")
        
        random_node = {
            'id': node_id,
            'name': node_name,
            'type': node_type,
            'weight': weight,
            'des': des,
            'npc': npcs,
            'scene': scene
        }
        
        random_nodes.append(random_node)
        print(f"  ✓ Added random node: {node_id}")
    
    output = {
        'random_nodes': random_nodes
    }
    
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print()
    print("=" * 50)
    print("✓ Random Nodes conversion completed successfully!")
    print(f"  Total random nodes: {len(random_nodes)}")
    print(f"  Output file: {json_path}")
    print("=" * 50)
    
    return True


def convert_boss_csv_to_json(csv_path, json_path):
    """将 boss.csv 转换为 JSON 格式"""
    
    print("=" * 50)
    print("Boss CSV to JSON Converter")
    print("=" * 50)
    print()
    
    encodings = ['utf-8', 'gbk', 'gb2312', 'utf-8-sig']
    content = None
    used_encoding = None
    
    for encoding in encodings:
        try:
            with open(csv_path, 'r', encoding=encoding) as f:
                content = f.read()
                used_encoding = encoding
                print(f"✓ Successfully read CSV with encoding: {encoding}")
                break
        except Exception as e:
            continue
    
    if not content:
        print("✗ Error: Cannot read CSV file with any encoding")
        return False
    
    lines = content.strip().split('\n')
    if len(lines) < 2:
        print("✗ Error: CSV file has no data rows")
        return False
    
    header = [h.strip() for h in lines[0].split(',')]
    print(f"CSV Header: {header}")
    print()
    
    bosses = []
    
    for i in range(1, len(lines)):
        line = lines[i].strip()
        if not line:
            continue
        
        print(f"Processing line {i+1}...")
        
        try:
            reader = csv.reader([line])
            values = next(reader)
        except Exception as e:
            print(f"  ✗ Error parsing line: {e}")
            continue
        
        if len(values) < 7:
            print(f"  ✗ Warning: Insufficient columns, skipping")
            continue
        
        # 提取数据
        boss_id = values[0].strip()
        name = values[1].strip()
        difficulty = values[2].strip()
        level = values[3].strip()
        weight = values[4].strip()
        hero_id = values[5].strip()
        scene_id = values[6].strip()
        
        # 跳过空数据行
        if not boss_id or not name:
            print(f"  ✗ Warning: Empty boss ID or name, skipping")
            continue
        
        print(f"  Boss ID: {boss_id}")
        print(f"  Name: {name}")
        print(f"  Difficulty: {difficulty}")
        print(f"  Level: {level}")
        print(f"  Weight: {weight}")
        print(f"  Hero ID: {hero_id}")
        print(f"  Scene ID: {scene_id}")
        
        boss = {
            'id': boss_id,
            'name': name,
            'difficulty': difficulty,
            'level': level,
            'weight': weight,
            'hero_id': hero_id,
            'scene_id': scene_id
        }
        
        bosses.append(boss)
        print(f"  ✓ Added boss: {boss_id}")
    
    output = {
        'bosses': bosses
    }
    
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print()
    print("=" * 50)
    print("✓ Boss conversion completed successfully!")
    print(f"  Total bosses: {len(bosses)}")
    print(f"  Output file: {json_path}")
    print("=" * 50)
    
    return True


if __name__ == '__main__':
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    if len(sys.argv) > 1 and sys.argv[1] == '--num-dices':
        csv_file = os.path.join(script_dir, '..', 'table', 'NumDices.csv')
        json_file = os.path.join(script_dir, '..', 'table', 'NumDices.json')
        
        if len(sys.argv) > 2:
            csv_file = sys.argv[2]
        if len(sys.argv) > 3:
            json_file = sys.argv[3]
        
        success = convert_num_dices_csv_to_json(csv_file, json_file)
        
        if not success:
            sys.exit(1)
    elif len(sys.argv) > 1 and sys.argv[1] == '--skill-dices':
        csv_file = os.path.join(script_dir, '..', 'table', 'SkillDices.csv')
        json_file = os.path.join(script_dir, '..', 'table', 'SkillDices.json')
        
        if len(sys.argv) > 2:
            csv_file = sys.argv[2]
        if len(sys.argv) > 3:
            json_file = sys.argv[3]
        
        success = convert_skill_dices_csv_to_json(csv_file, json_file)
        
        if not success:
            sys.exit(1)
    elif len(sys.argv) > 1 and sys.argv[1] == '--attr-dices':
        csv_file = os.path.join(script_dir, '..', 'table', 'AttrDices.csv')
        json_file = os.path.join(script_dir, '..', 'table', 'AttrDices.json')
        
        if len(sys.argv) > 2:
            csv_file = sys.argv[2]
        if len(sys.argv) > 3:
            json_file = sys.argv[3]
        
        success = convert_attr_dices_csv_to_json(csv_file, json_file)
        
        if not success:
            sys.exit(1)
    elif len(sys.argv) > 1 and sys.argv[1] == '--hero':
        csv_file = os.path.join(script_dir, '..', 'table', 'hero.csv')
        json_file = os.path.join(script_dir, '..', 'table', 'hero.json')
        
        if len(sys.argv) > 2:
            csv_file = sys.argv[2]
        if len(sys.argv) > 3:
            json_file = sys.argv[3]
        
        success = convert_hero_csv_to_json(csv_file, json_file)
        
        if not success:
            sys.exit(1)
    elif len(sys.argv) > 1 and sys.argv[1] == '--scenes':
        csv_file = os.path.join(script_dir, '..', 'table', 'scenes.csv')
        json_file = os.path.join(script_dir, '..', 'table', 'scenes.json')
        
        if len(sys.argv) > 2:
            csv_file = sys.argv[2]
        if len(sys.argv) > 3:
            json_file = sys.argv[3]
        
        success = convert_scenes_csv_to_json(csv_file, json_file)
        
        if not success:
            sys.exit(1)
    elif len(sys.argv) > 1 and sys.argv[1] == '--core-nodes':
        csv_file = os.path.join(script_dir, '..', 'table', 'core_nodes.csv')
        json_file = os.path.join(script_dir, '..', 'table', 'core_nodes.json')
        
        if len(sys.argv) > 2:
            csv_file = sys.argv[2]
        if len(sys.argv) > 3:
            json_file = sys.argv[3]
        
        success = convert_core_nodes_csv_to_json(csv_file, json_file)
        
        if not success:
            sys.exit(1)
    elif len(sys.argv) > 1 and sys.argv[1] == '--boss':
        csv_file = os.path.join(script_dir, '..', 'table', 'boss.csv')
        json_file = os.path.join(script_dir, '..', 'table', 'boss.json')
        
        if len(sys.argv) > 2:
            csv_file = sys.argv[2]
        if len(sys.argv) > 3:
            json_file = sys.argv[3]
        
        success = convert_boss_csv_to_json(csv_file, json_file)
        
        if not success:
            sys.exit(1)
    else:
        csv_file = os.path.join(script_dir, '..', 'table', 'skill.csv')
        json_file = os.path.join(script_dir, '..', 'table', 'skill.json')
        
        if len(sys.argv) > 1:
            csv_file = sys.argv[1]
        if len(sys.argv) > 2:
            json_file = sys.argv[2]
        
        success = convert_csv_to_json(csv_file, json_file)
        
        if not success:
            sys.exit(1)
