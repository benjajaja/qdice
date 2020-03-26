import json
from collections import defaultdict
from pathlib import Path

proj_dir = Path(__file__).parents[1]
ms_path = proj_dir / 'maps' / 'original' / 'map-sources.json'
with open(ms_path) as fp:
    ms = json.load(fp)

maps = ms['maps']

for map_name, map in maps.items():
    adj_dict = defaultdict(list)

    name = map['name']
    index = map['adjacency']['indexes']
    reverse_index = {v: k for k, v in index.items()}
    bool_matrix = map['adjacency']['matrix']
    matrix = [[int(val) for val in line] for line in bool_matrix]

    for i, row in enumerate(bool_matrix):
        for j, val in enumerate(row):
            if val:
                key = reverse_index[i]
                value = reverse_index[j]
                adj_dict[key].append(value)

    out_dict = {'keys': reverse_index, 'reverse_keys': index, 'adj_dict': adj_dict, 'adj_mat': matrix}
    with open(proj_dir / 'maps' / 'original' / f'{name}.json', 'w') as fp:
        print(f"Writing {fp.name}...")
        json.dump(out_dict, fp)
