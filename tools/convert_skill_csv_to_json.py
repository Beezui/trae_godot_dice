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


if __name__ == '__main__':
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    if len(sys.argv) > 1 and sys.argv[1] == '--skill-dices':
        csv_file = os.path.join(script_dir, '..', 'table', 'SkillDices.csv')
        json_file = os.path.join(script_dir, '..', 'table', 'SkillDices.json')
        
        if len(sys.argv) > 2:
            csv_file = sys.argv[2]
        if len(sys.argv) > 3:
            json_file = sys.argv[3]
        
        success = convert_skill_dices_csv_to_json(csv_file, json_file)
        
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
