module Static.Help exposing (markdown)

import Markdown


markdown =
    Markdown.toHtml [] """
## How to play

### Goal

Conquer the map by eliminating your opponents. Each turn you can roll the dice of your lands against the dice of your opponent's lands.

If any player has no more lands left, that player will be eliminated.

### Game mechanics

Join a game, it will start when there are enough players or all checked "ready".

To attack, click your land from which you want to attack, then the opponents land. All dice on your land will be rolled against all dices of your opponent's land. The higher number wins, a draw is a loss.

![Attack illustration](/assets/gifs/attack.gif)

If an attack is succesful, then all your land's dice except one will take the opponent's land and your remaining land will be left with one die.

If an attack fails, then your land will be reduced to one die.

After your turn you will receive one die per each **connected land**. If you have multiple connected landmasses, you will receive the amount of the biggest landmass. If all your lands are full of dice, then the extra dice given will be placed in your reserve pocket, and given to you as soon as there is space on your lands.

> Tip: do not scatter your lands around and attack blindly. Instead, focus on keeping your lands connected and cutting off your opponents. That will show them.

Below each player there is a legend such as `5th ⬢ 6 ⚂ 23 + 5 -20✪`. Nth is the current position. ⬢ is the number of lands owned. ⚂ is the total number of dice on table. + is the number of dice in pocket. ✪ is the points to be won or lost, from the position.

> Tip: When attacking with a full stack, 7 dice are needed to refill no matter if won or lost. You can count the number of connected lands + the reserve pocket dice to know exactly how many you will receive. E.g. if all lands are at 8 dice, then an attack is safe (all will be refilled) if (number of lands + reserve dice) is greater then or equal 7. Then 14 for two attacks in one turn and so on.

### Flags

After a certain amount of rounds, it is possible to "flag" or surrender. This mechanic allows to finish a game early, without having to wait out a territorial takeover. **A flag is a signal that a player will not attack players above his position**. Lower positioned players can fight out, and the dominant can simply wait, trusting that a flagged player cannot possibly overturn him.

If you are last, you can click "surrender" and you will exit immediately or when your turn comes.

If you are between last and first, you will be marked as "flagged Nth" where N is your current position. As soon as that position is the last of the game, you will be ejected.

Of course it is also possible to verbally "flag" a single player in chat saying something like "flag blue". The flagging player promises not to attack if the flagged player accepts. This benefits both players and other players should either counter the alliance or also flag and sort out their positions between themselves. But be wary of backstabbing!

> Tip: you can comment on a player's wall, or on a game, if you think someone has backstabbed you, or if a gang of players suspiciously started the game in alliance.

### Capitals

Some tables have capitals assigned randomly on start, one per player. "Pocket" dice that did not fit on the table because all lands were full are put on the capitals, displayed as `+N`. Next time the player receives dice, the pocket dice will be given first into the capital if there is space, then any other lands if there is space, or be kept in the pocket until next time.

When a capital is defeated then all it's dice, including pocket dice, are **stolen** by the attacker. They are put into the attackers pocket/capital immediately, and given out at turn end like usual. A new capital will be assigned to the defender before the next turn.

> Tip: stealing nearby capitals can be a huge dice boost - getting yours stolen can be the end!

### General rules

1. No hate speech (racism, homophobia, etc) (includes avatars)
2. No harassment

### Game rules

1. No pre-game alliances
2. Only one account per player

### Discussion

  * [Qdice reddit](https://www.reddit.com/r/Qdice/) to post any questions or opinion
  * [Discord](https://discord.gg/E2m3Gra) to chat with fellow players
  * [@qdicewtf](https://twitter.com/qdicewtf) on twitter
  * [github](https://github.com/benjajaja/qdice) code and bugs
  * Comment here

"""
