# Purpose
To find a distribution of lands on [Qdice](qdice.wtf) for better starting positions. These are listed in `./maps/output`

# To Install
1. Install Python 3
1. `cd qdice_starting_position`
1. `pip install -r requirements.txt`

# To Use
1. `cd qdice_starting_position`
1. `python ./src/build_adjacency_matrix.py` _Optional_
1. `python ./src/shotest_path.py`


# Example output
Land: Sabicas 

Players: 8

Seperation: 1

```　　　　　　　　　　　　　　　　　🎩🎩🎩🎩　　　　　　　　　　　2222
 　　　　　　　　　　　　🥑🥑🎩　🎩🎩🎩🎩🎩　　　🍏🍏　　22222222
　　　　　　　　　　　　🥑🥑🎩🎩🎩🎩　🎩🎩🎩🍏🍏🍏🍏🎵🎵22222👀👀👀
 　　　　　　　　　　　🥑🥑🎩🎩🎩🎩👙7🍏🍏🍏🍏🍏🍏🎵🎵🎵🎵222👀👀👀👀
　　　　　　　55🥑🥑🥑🥑🎩👙👙🎩👙77🍏🍏🍏🍏🍏🍏🎵🎵🎵🎵2👀👀👀👀👀
 　　　　5555🥑🥑🥑🥑👙👙👙👙👙77🍏🍏🍏🍏🍏🍏🍏🍏🎵🎵🎵👀👀👀👀👀👀
　　　5555555🥑🥑　👙👙👙👙777🐟🐟🐟🐟🐧🐧🐧🐧🐧🎵🎵33333
 　🐸🐸5555555🥑🥑　👙👙77777🐟🐟🐟🐟🐟🐧🐧🐧🐧🐧🎵33333
　　🐸🐸🐸😺😺😺😺55　　　🏰🏰7777🐟🐟🐟🐟🐟🐧🐧🐧🐧🐧333333
 　🐸🐸🐸😺😺😺😺😺💰5　　🏰🏰77777🐟🐟🐟🐟🐟🐟🐟🐧🐧🐧🐧333
　🐸🐸🐸😺😺😺😺😺💰💰　　🏰🏰🏰777777🐟🐟🐰🐟🐟🐧🐧🐧　　　33
 🐸🐸🐸🐸😺😺😺😺😺💰💰　　🏰🏰🏰　🍷77🐰🐰🐰🐰🐰🐰　　　　　　　
🍋🐸🐸🐸🐸🐸😺😺💰💰💰　🏰🏰🏰🏰🏰🍷🍷🍷7🐰🐰🐰🐰
 🍋🍋🐸🐸💰💰💰💰💰💰　👻👻👻　🍷🍷🍷🍷🍷🍷🐰🐰🐰
🍋🍋🍋🍋🍋💰💰💰💰　　👻👻👻👻🍷🍷🍷🍷🍷🐰🐰🐰
 🍋🍋🍋🍋🍋🍋444444👻👻👻👻　🍷🍷🍷　　　　　
　　🍋🍋🍋🍋4444444👻👻👻6🍷🍷🍷
 　🍋🍋🍋🍋444444👻👻👻👻666
　🍋🍋444444　　👻👻🌴🌴🌴666　　　　　　　　
 🔥🔥🔥🔥🔥🔥🌙🌙　🌴🌴🌴🌴🌴🌴666　　　　　　　　　　　　　
　🔥🔥🔥🔥🔥🔥🌙🌙🌙🌙🌴🌴🌴66666　　　　　　　　　　　　　　
 　🔥🔥🔥🔥🔥🌙🌙🌙🌙🌴🌴🌴🌴6666　　　　　　　　　　　　　　　
　　　　🔥🌙🌙🌙🌙🌙🌙🌙🌴🌴🌴🌴💥66💋　　　　　　　　　　　　000
 　　　　　🌙🌙🌙🌙🌙🌙🌴🌴🌴🌴💥💥6💋💋💋　　　　　　　　💀💀💀0000
　　　　　　　　　💥💥💥💥💥💥💥💥💥💋💋💋💋💋　　　1💀💀💀💀💀💀💀00
 　　　　　　　　　💥💥💥💥💥💥💥💥💥💊💋💋💋💋1111💀💀💀💀💀💀💀00
　　　　　　　　　💥💥💥💥💥💥💥💊💊💊💊💋💋1111💧💧💧💧💧💧💀00
 　　　　　　　　　💥💥💥💥💊💊💊💊💊💊💊💋1111💧💧💧💧💧💧💧
　　　　　　　　　　　　　　　　💊💊💊💊💊💊　11　💧💧💧💧
 　　　　　　　　　　　　　　　　　　💊💊💊💊💊11💧💧💧💧
　　　　　　　　　　　　　　　　　　　　　💊💊💊💊
```

# Stats
| Map     | Separation | # of Players | # of Configurations |
|---------|------------|--------------|---------------------|
| Sabicas | 2          | 5            | 1418                |
| Sabicas | 2          | 6            | 232                 |
| Sabicas | 1          | 6            | 1                   |
| Sabicas | 1          | 7            | 27                  |
| Sabicas | 1          | 8            | 653                 |
| Sabicas | 1          | 9            | 2146                |
| Sabicas | 1          | 10           | 1858                |
| Sabicas | 1          | 11           | 521                 |
| Planeta | 4          | 5            | 3                   |
| Planeta | 3          | 5            | 1263                |
| Planeta | 3          | 6            | 592                 |
| Planeta | 2          | 5            | 156                 |
| Planeta | 2          | 6            | 4259                |
| Planeta | 2          | 7            | 11044               |
| Planeta | 2          | 8            | 1647                |
| Planeta | 2          | 9            | 25                  |
| Planeta | 1          | 9            | 40                  |
| Planeta | 1          | 10           | 836                 |
| Planeta | 1          | 11           | 6448                |

# Potential Issues
It doesnt quite make sense to me that Sabicas, 1, 6 only has 1 entry. 