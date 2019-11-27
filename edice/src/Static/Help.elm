module Static.Help exposing (markdown)

import Markdown


markdown =
    --case tab of
    --1 ->
    --Markdown.toHtml [] """
    --## ¡Qué Dice!
    --### Propósito del juego
    --Conquista el mapa eliminando a tus oponentes. En cada turno puedes lanzar los dados de tus tierras contras los dados de las tierras de tus oponentes.
    --Cuando un jugador se quede sin dados, será eliminado.
    --### Mecánica
    --Únete a una partida, empezará en cuanto haya suficientes jugadores.
    --Para atacar, haz click en la tierra tuya desde la que quieres atacar, y luego en la tierra de tu oponente. Todos los dados de tu tierra serán tirados contra los dedos del oponente. El número más alto gana.
    --![Attack illustration](/assets/gifs/attack.gif)
    --Si un ataque tiene éxito, todos los dados de tu tierra excepto uno tomarán la tierra de tu oponente. Un dado se quedará atrás.
    --Si un ataque falla, tu tierra será reducida a un dado.
    --Después de tu turno recibirás un dado por *tierra conectada*. Si tienes varias "continentes" entonces solo recibirás dados por el número de tierras en tu continente mayor. Si todas tus tierras están a tope de dados, entonces los dados recibidos se ponen en tu reserva, y los recibirás en cuanto haya hueco.
    --> ProTip: no esparzas tus tierras por ahí ni ataques a lo loco. En vez de eso, céntrate en mantener tus tierras conectas y cortar tus oponentes. Eso les mantendrá a raya.
    --### Banderas
    --Es común que un jugador le pida "bandera" a otro. Esto significa que quiere parar de atacar mutuamente, pero se "rinde" bajo la posición del otro. Este le da una ventaja a los dos jugadores sobre los demás. Para clarificar un poco más:
    --* No existe mecánica de juego para hacer cumplir una bandera. Atento a los traidores.
    --* Normalmente una bandera debería ser reconocida como recibida. Un reconocimiento silencioso es sospechoso y ambiguo.
    --* Una bandera no tiene porqué ser aceptada. De hecho, puede ser una desventaja porque puede frenar el crecimiento.
    --* Otros jugadores deberían contraatacar a jugadores con bandera.
    --"""
    --_ ->
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

It is common for one player to flag another player. This means he wants to stop fighting, but "surrenders" below his position. This gives both players an advantage over the rest of the players. Some clarifications about flags:

 * There is no game mechanic to enforce flags. Be wary of backstabbers.
 * Usually a flag should be acknowledged by the receptor. A silent acknowledgement is suspicious.
 * A flag must not be accepted. In fact, it may be disadvantageous because it can cripple growth.
 * Other players should actively counter flagged players.


"""
