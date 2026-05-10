#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Hero CSV to JSON Converter (Standalone)
将 hero.csv 转换为 hero.json 格式（支持 MP 属性）
"""

import csv
import json
import os
import sys

def convert_hero_csv_to_json(csv_path, json_path):
    """将 hero.csv 转换为 JSON 格式（支持 MP 属性）"""

    print("=" * 50)
    print("Hero CSV to JSON Converter (with MP support)")
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
                print(f"[SUCCESS] Successfully read CSV with encoding: {encoding}")
                break
        except Exception as e:
            continue

    if not content:
        print("[ERROR] Cannot read CSV file with any encoding")
        return False

    lines = content.strip().split('\n')
    if len(lines) < 2:
        print("[ERROR] CSV file has no data rows")
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
            print(f"  [ERROR] Error parsing line: {e}")
            continue

        if len(values) < 16:
            print(f"  [SKIP] Warning: Insufficient columns (got {len(values)}, need 16), skipping")
            continue

        # 提取数据
        hero_id = values[0].strip()
        name = values[1].strip()
        # 角色类型和阶段
        hero_type = int(values[2].strip()) if values[2].strip().isdigit() else 1
        stage = int(values[3].strip()) if values[3].strip().isdigit() else 1

        # 跳过空数据行
        if not hero_id or not name:
            print(f"  [SKIP] Empty hero ID or name, skipping")
            continue

        # 使用分号作为数组分隔符
        attr_str = [s.strip() for s in values[4].strip().strip('"').split(';')] if values[4].strip() else []
        attr_agi = [s.strip() for s in values[5].strip().strip('"').split(';')] if values[5].strip() else []
        attr_int = [s.strip() for s in values[6].strip().strip('"').split(';')] if values[6].strip() else []
        attr_hp = values[7].strip()
        attr_mp = values[8].strip()
        mp_name = values[9].strip()
        skill_slot = values[10].strip()
        blank_dice_id = values[11].strip()
        skill_ids = [s.strip() for s in values[12].strip().strip('"').split(';')] if values[12].strip() else []
        texture = [s.strip() for s in values[13].strip().strip('"').split(';')] if values[13].strip() else []
        portrait = values[14].strip()
        hero_texture = [s.strip() for s in values[15].strip().strip('"').split(';')] if values[15].strip() else []

        print(f"  Hero ID: {hero_id}")
        print(f"  Name: {name}")
        print(f"  Type: {hero_type}")
        print(f"  Stage: {stage}")
        print(f"  Strength: {attr_str}")
        print(f"  Agility: {attr_agi}")
        print(f"  Intelligence: {attr_int}")
        print(f"  HP: {attr_hp}")
        print(f"  MP: {attr_mp}")
        print(f"  MP Name: {mp_name}")
        print(f"  Skill Slot: {skill_slot}")
        print(f"  Blank Dice ID: {blank_dice_id}")
        print(f"  Skill IDs: {skill_ids}")
        print(f"  Texture: {texture}")
        print(f"  Portrait: {portrait}")
        print(f"  Hero Texture: {hero_texture}")

        hero = {
            'id': hero_id,
            'name': name,
            'type': hero_type,
            'stage': stage,
            'attr_str': attr_str,
            'attr_agi': attr_agi,
            'attr_int': attr_int,
            'attr_hp': attr_hp,
            'attr_mp': attr_mp,
            'mp_name': mp_name,
            'skill_slot': skill_slot,
            'blank_dice_id': blank_dice_id,
            'skill_ids': skill_ids,
            'texture': texture,
            'portrait': portrait,
            'hero_texture': hero_texture
        }

        heroes.append(hero)
        print(f"  [OK] Added hero: {hero_id}")

    output = {
        'heroes': heroes
    }

    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print()
    print("=" * 50)
    print("[SUCCESS] Hero conversion completed successfully!")
    print(f"  Total heroes: {len(heroes)}")
    print(f"  Output file: {json_path}")
    print("=" * 50)

    return True


if __name__ == '__main__':
    script_dir = os.path.dirname(os.path.abspath(__file__))
    csv_file = os.path.join(script_dir, '..', 'table', 'hero.csv')
    json_file = os.path.join(script_dir, '..', 'table', 'hero.json')

    if len(sys.argv) > 1:
        csv_file = sys.argv[1]
    if len(sys.argv) > 2:
        json_file = sys.argv[2]

    success = convert_hero_csv_to_json(csv_file, json_file)

    if not success:
        sys.exit(1)
