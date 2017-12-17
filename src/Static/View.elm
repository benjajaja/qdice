module Static.View exposing (view)

import Types exposing (..)
import Html
import Markdown


view : Model -> StaticPage -> Html.Html Types.Msg
view model page =
    case page of
        Help ->
            Markdown.toHtml [] """
## ¡Qué Dice!

### Game rules

Conquer the map by eliminating your opponents. Each turn you can roll the dice of your lands against the dice of your opponent's lands.

If any player has no more lands left, that player will be eliminated.

### Game mechanics

Join a game, it will start when there are enough players.

To attack, click your land from which you want to attack, then the opponents land. All dices on your land will be rolled against all dices of your opponent's land. The higher number wins.

If an attack is succesful, then all your land's dice except one will take the opponent's land and your remaining land will be left with one die.

If an attack fails, then your land will be reduced to one die.

After your turn you will receive one die per each **connected land**. If you have multiple connected landmasses, you will receive the amount of the biggest landmass. If all your lands are full of dice, then the extra dice given will be placed in your reserve pocket, and given to you as soon as there is space on your lands.

> Tip: do not scatter your lands around and attack blindly. Instead, focus on keeping your lands connected and cutting off your opponents. That will show them.
"""

        About ->
            Markdown.toHtml [] """
![Emergency whoolies](http://i.imgur.com/RLqGplY.jpg)
"""
