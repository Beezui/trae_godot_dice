#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
JSON to CSV Converter
将 JSON 文件转换为 CSV 格式

支持的文件：
- core_nodes.json → core_nodes.csv
"""

import json
import csv
import os
import sys

def convert_core_nodes_json_to_csv(json_path, csv_path):
    """将 core_nodes.json 转换为 CSV 格式"""
    
    print("=" * 50)
    print("Core Nodes JSON to CSV Converter")
    print("=" * 50)
    print()
    
    # 读取 JSON 文件
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        print(f"[SUCCESS] Successfully read JSON file: {json_path}")
    except Exception as e:
        print(f"[ERROR] Error reading JSON file: {e}")
        return False
    
    # 检查数据结构
    if 'core_nodes' not in data:
        print("[ERROR] Error: JSON file does not contain 'core_nodes' key")
        return False
    
    core_nodes = data['core_nodes']
    if not core_nodes:
        print("[ERROR] Error: No core nodes found in JSON file")
        return False
    
    # 提取表头
    header = ['id', 'name', 'next', 'is_start', 'is_end', 'des1', 'des2', 'type', 'enemy', 'npc', 'scene', 'textures']
    print(f"CSV Header: {header}")
    print()
    
    # 写入 CSV 文件
    try:
        with open(csv_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow(header)
            
            for node in core_nodes:
                # 处理 next 字段（数组转分号分隔的字符串）
                next_str = ';'.join(node.get('next', []))
                
                # 提取其他字段
                row = [
                    node.get('id', ''),
                    node.get('name', ''),
                    next_str,
                    node.get('is_start', ''),
                    node.get('is_end', ''),
                    node.get('des1', ''),
                    node.get('des2', ''),
                    node.get('type', ''),
                    node.get('enemy', ''),
                    node.get('npc', ''),
                    node.get('scene', ''),
                    node.get('textures', '')
                ]
                writer.writerow(row)
        print(f"[SUCCESS] Successfully wrote CSV file: {csv_path}")
    except Exception as e:
        print(f"[ERROR] Error writing CSV file: {e}")
        return False
    
    print()
    print("=" * 50)
    print("[SUCCESS] Core Nodes JSON to CSV conversion completed successfully!")
    print(f"  Total core nodes: {len(core_nodes)}")
    print(f"  Output file: {csv_path}")
    print("=" * 50)
    
    return True


if __name__ == '__main__':
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    if len(sys.argv) > 1 and sys.argv[1] == '--core-nodes':
        json_file = os.path.join(script_dir, '..', 'table', 'core_nodes.json')
        csv_file = os.path.join(script_dir, '..', 'table', 'core_nodes.csv')
        
        if len(sys.argv) > 2:
            json_file = sys.argv[2]
        if len(sys.argv) > 3:
            csv_file = sys.argv[3]
        
        success = convert_core_nodes_json_to_csv(json_file, csv_file)
        
        if not success:
            sys.exit(1)
    else:
        print("Usage:")
        print("  python convert_json_to_csv.py --core-nodes [input.json] [output.csv]")
        print()
        print("Example:")
        print("  python convert_json_to_csv.py --core-nodes")
        print("  python convert_json_to_csv.py --core-nodes ../table/core_nodes.json ../table/core_nodes.csv")
        sys.exit(1)
