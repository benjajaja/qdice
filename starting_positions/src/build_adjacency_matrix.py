import json
from collections import defaultdict
from pathlib import Path


def get_adj_tiles(row: int, col: int, arr: list, max_len: int):
    left, right, up, down = None, None, None, None
    if row > 0:
        left = arr[row - 1][col]
    if row < len(arr) - 1:
        right = arr[row + 1][col]
    if col > 0:
        up = arr[row][col - 1]
    if col < max_len - 1:
        down = arr[row][col + 1]
    return left, right, up, down


def text_to_adj_mat(lines: list):
    """
    takes text map and created adj mat
    :param lines: list of lists of text map
    :return:
    """
    max_len = max([len(line) for line in lines])
    padded_lines = [line + ' ' * (max_len - len(line)) for line in lines]

    spaces = ['\u3000', ' ']
    adj_dict = defaultdict(set)
    for i in range(len(padded_lines)):
        for j in range(max_len):
            tile = padded_lines[i][j]
            # We dont want spaces in our adj_mat
            if tile in spaces:
                continue
            for adj in get_adj_tiles(i, j, padded_lines, max_len):
                # No self loops
                if adj not in [tile, None] + spaces:
                    adj_dict[tile].add(adj)

    keys = list(adj_dict.keys())
    adj_mat = [[0 for _ in range(len(keys))] for _ in range(len(keys))]
    for i, key in enumerate(keys):
        for adj in adj_dict[key]:
            # i is the row
            # we find the column by looking in our adj_dict keys
            adj_mat[i][keys.index(adj)] = 1

    # Converting to list to be serializable
    for k, v in adj_dict.items():
        adj_dict[k] = list(v)

    return keys, adj_mat, adj_dict


def txt_to_json(path: Path, out_path: Path = None, to_print: bool = False):
    """
    Full process from txt map to json with keys and adj matrix
    :param path:
    :param out_path:
    :param to_print:
    :return:
    """
    if not out_path:
        out_path = path.with_suffix('.json')

    if not isinstance(path, Path):
        path = Path(path)

    lines = path.read_text().split('\n')
    keys, adj_mat, adj_dict = text_to_adj_mat(lines)
    if to_print:
        print(keys)
        for key, line in zip(keys, adj_mat):
            print(key, line)

    out_dict = {'keys': keys, 'adj_mat': adj_mat, 'adj_dict': adj_dict}

    with open(out_path, 'w') as fp:
        print(f'Writing {fp.name}...')
        json.dump(out_dict, fp)


if __name__ == '__main__':
    proj_dir = Path(__file__).parents[1]
    sab = proj_dir / 'maps' / 'emoji_maps' / 'Sabicas.txt'

    txt_to_json(sab, to_print=True)
