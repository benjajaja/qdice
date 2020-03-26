import json
from pathlib import Path

import networkx as nx


def get_map_str(lands, map_name):
    map_path = proj_dir / 'maps' / 'emoji' / f'{map_name}.txt'
    map_text = map_path.read_text()

    for num, land in enumerate(lands):
        map_text = map_text.replace(land, str(num))
    return map_text


def get_map_configurations(G):
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

        for clique_size in range(5, 12):
            k_sized_cliques = []
            for clique in cliques:
                if len(clique) == clique_size:
                    k_sized_cliques.append(clique)
            if k_sized_cliques:
                print(f'{map} with {sep} separation and {clique_size} players:\t{len(k_sized_cliques)}')
                with open(proj_dir / 'maps' / 'output' / f'{map}_{sep}_sep_{clique_size}_players.json', 'w',
                          encoding='utf-8') as fp:
                    json.dump(k_sized_cliques, fp)


def get_map_graph(map_path):
    with open(map_path) as fp:
        sab_json = json.load(fp)

    # Get Graph
    G = nx.convert.from_dict_of_lists(sab_json['adj_dict'])

    return G


if __name__ == '__main__':
    proj_dir = Path(__file__).parents[1]
    for map in ('Sabicas', 'Planeta'):
        map_txt = proj_dir / 'maps' / 'original' / f'{map}.json'
        G = get_map_graph(map_txt)
        get_map_configurations(G)
