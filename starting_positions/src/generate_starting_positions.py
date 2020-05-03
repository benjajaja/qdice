import argparse
import json
import random
from pathlib import Path

import networkx as nx

from src.read_adj_mat_source import generate_adj_mat

proj_dir = Path(__file__).parents[1]
random.seed(42)


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out_dir', type=Path, default=proj_dir / 'maps' / 'output',
                        help='Where to put the starting positions')
    parser.add_argument('--adj_mat_dir', type=Path, default=proj_dir / 'maps' / 'adj_mat',
                        help='Where to put the adj_mat intermediate files')
    parser.add_argument('--adj_mat_source', type=Path, default=proj_dir / 'maps' / 'map-sources.json',
                        help='If you want to specify the map-sources.json')
    parser.add_argument('--player_min', type=int, default=2,
                        help='Min num of players to generate starting positions for')
    parser.add_argument('--player_max', type=int, default=9,
                        help='Max num of players to generate starting positions for')
    args = parser.parse_args()
    return args


def get_map_str(lands, map_name):
    map_path = proj_dir / 'maps' / 'emoji' / f'{map_name}.txt'
    map_text = map_path.read_text()

    for num, land in enumerate(lands):
        map_text = map_text.replace(land, str(num))
    return map_text


def get_map_starting_positions(G, player_min, player_max, out_dir):
    # Get max shortest path info
    shortest_paths = list(nx.shortest_path_length(G))
    max_shortest_path = 0
    for node, dist_dict in shortest_paths:
        for k, v in dist_dict.items():
            max_shortest_path = max(max_shortest_path, v)
    # print(f'Max Shortest Path:\t{max_shortest_path}')

    Gw = nx.Graph()
    for current_path_length in range(max_shortest_path + 1, 1, -1):
        sep = current_path_length - 1
        # Adding shortest path info of current_path_length
        for node, dist_dict in nx.shortest_path_length(G):
            for other_node, weight in dist_dict.items():
                if weight >= current_path_length:
                    Gw.add_weighted_edges_from([(node, other_node, weight)])
        cliques = list(nx.find_cliques(Gw))

        for clique_size in range(player_min, player_max):
            k_sized_cliques = []
            for clique in cliques:
                if len(clique) == clique_size:
                    k_sized_cliques.append(clique)
            if k_sized_cliques and len(k_sized_cliques) > 1:
                print(f'{G.name} with {sep} separation and {clique_size} players:\t{len(k_sized_cliques)}')
                with open(out_dir / f'{G.name}_{sep}_sep_{clique_size}_players.json', 'w', encoding='utf-8') as fp:
                    json.dump(k_sized_cliques, fp)


def get_map_graph(map_path):
    with open(map_path) as fp:
        sab_json = json.load(fp)

    # Get Graph
    G = nx.convert.from_dict_of_lists(sab_json['adj_dict'])

    return G


def main():
    args = get_args()

    # To generate adj_mats
    maps = generate_adj_mat(adj_mat_source_path=args.adj_mat_source, adj_mat_out_dir=args.adj_mat_dir)

    # For all the relevant maps as some dont need starting positions
    Path(args.out_dir).mkdir(parents=True, exist_ok=True)
    Path(args.adj_mat_dir).mkdir(parents=True, exist_ok=True)
    for map_name in maps:
        print(f'{map_name} starting positions')
        map_json = args.adj_mat_dir / f'{map_name}.json'
        G = get_map_graph(map_json)
        G.name = map_name
        get_map_starting_positions(G, player_min=args.player_min, player_max=args.player_max, out_dir=args.out_dir)


if __name__ == '__main__':
    main()
