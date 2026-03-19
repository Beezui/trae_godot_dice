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
        
        if len(values) < 10:
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
            'portrait': portrait
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
