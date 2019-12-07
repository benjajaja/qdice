module Static.Help exposing (markdown)

import Markdown


markdown =
    Markdown.toHtml [] """
## ¡Qué Dice!

### Goal

Conquer the map by eliminating your opponents. Each turn you can roll the dice of your lands against the dice of your opponent's lands.

If any player has no more lands left, that player will be eliminated.

### Game mechanics

Join a game, it will start when there are enough players.

To attack, click your land from which you want to attack, then the opponents land. All dices on your land will be rolled against all dices of your opponent's land. The higher number wins.

![Attack illustration](/assets/gifs/attack.gif)

If an attack is succesful, then all your land's dice except one will take the opponent's land and your remaining land will be left with one die.

If an attack fails, then your land will be reduced to one die.

After your turn you will receive one die per each **connected land**. If you have multiple connected landmasses, you will receive the amount of the biggest landmass. If all your lands are full of dice, then the extra dice given will be placed in your reserve pocket, and given to you as soon as there is space on your lands.

> Tip: do not scatter your lands around and attack blindly. Instead, focus on keeping your lands connected and cutting off your opponents. That will show them.

### Flags

After a certain amount of rounds, it is possible to "flag" or surrender. This mechanic allows to finish a game early, without having to wait out a territorial takeover. It also allows an obviously dominant first player to step back and let others fight out their positions.

If you are last, you can click "surrender" and you will exit immediately or when your turn comes.

If you are between last and first, you will be marked as "flagged Nth" where N is your current position. As soon as that position is the last of the game, you will be ejected.

"""
