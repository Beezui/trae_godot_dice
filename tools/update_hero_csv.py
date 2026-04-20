#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Hero CSV Updater
为 hero.csv 添加 attr_mp 和 mp_name 列
"""

import csv
import os
import sys

def update_hero_csv(csv_path):
    """为 hero.csv 添加 MP 属性列"""

    print("=" * 50)
    print("Hero CSV Updater - Add MP Columns")
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
    print(f"Original lines: {len(lines)}")
    print(f"Original header: {lines[0]}")
    print()

    # 解析原有数据
    reader = csv.reader(lines)
    rows = list(reader)

    # 新表头
    new_header = ['id', 'name', 'attr_str', 'attr_agi', 'attr_int', 'attr_hp', 'attr_mp', 'mp_name', 'skill_slot', 'skill_dice_id', 'texture', 'portrait', 'hero_texture']

    # 新数据行
    new_rows = [new_header]

    # 角色 MP 配置数据
    hero_mp_config = {
        '1': {'attr_mp': '50', 'mp_name': '魔法值'},
        '2': {'attr_mp': '30', 'mp_name': '体力值'}
    }

    for i in range(1, len(rows)):
        row = rows[i]
        if len(row) < 11:
            print(f"[SKIP] Row {i+1}: insufficient columns")
            continue

        # 原有字段
        hero_id = row[0]
        name = row[1]
        attr_str = row[2]
        attr_agi = row[3]
        attr_int = row[4]
        attr_hp = row[5]
        skill_slot = row[6]
        skill_dice_id = row[7]
        texture = row[8]
        portrait = row[9]
        hero_texture = row[10]

        # 查找对应的 MP 配置
        mp_config = hero_mp_config.get(hero_id, {'attr_mp': '50', 'mp_name': '魔法值'})
        attr_mp = mp_config['attr_mp']
        mp_name = mp_config['mp_name']

        new_row = [hero_id, name, attr_str, attr_agi, attr_int, attr_hp, attr_mp, mp_name, skill_slot, skill_dice_id, texture, portrait, hero_texture]
        new_rows.append(new_row)
        print(f"[OK] Hero {hero_id}: {name}, MP={attr_mp}, MP 名称={mp_name}")

    # 写入新文件
    with open(csv_path, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(new_rows)

    print()
    print("=" * 50)
    print(f"[SUCCESS] Successfully updated {len(new_rows)} rows")
    print(f"New header: {new_header}")
    print("=" * 50)

    return True


if __name__ == '__main__':
    script_dir = os.path.dirname(os.path.abspath(__file__))
    csv_file = os.path.join(script_dir, '..', 'table', 'hero.csv')

    if len(sys.argv) > 1:
        csv_file = sys.argv[1]

    success = update_hero_csv(csv_file)

    if not success:
        sys.exit(1)
