module Static.View exposing (view, update)

import Types exposing (..)
import Html exposing (..)
import Markdown
import Material.Tabs as Tabs
import Material.Options as Options
import Material.Icon as Icon
import Static.Types


view : Model -> StaticPage -> Html Msg
view model page =
    case page of
        Help ->
            Tabs.render Mdl
                []
                model.mdl
                [ Tabs.ripple
                , Tabs.onSelectTab (Static.Types.SelectTab >> StaticPageMsg)
                , Tabs.activeTab model.staticPage.help.tab
                ]
                [ Tabs.label
                    [ Options.center ]
                    [ text "English" ]
                , Tabs.label
                    [ Options.center ]
                    [ text "Español" ]
                ]
                [ case model.staticPage.help.tab of
                    1 ->
                        Markdown.toHtml [] """
## ¡Qué Dice!

### Propósito del juego

Conquista el mapa eliminando a tus oponentes. En cada turno puedes lanzar los dados de tus tierras contras los dados de las tierras de tus oponentes.

Cuando un jugador se quede sin dados, será eliminado.

### Mecánica

Únete a una partida, empezará en cuanto haya suficientes jugadores.

Para atacar, haz click en la tierra tuya desde la que quieres atacar, y luego en la tierra de tu oponente. Todos los dados de tu tierra serán tirados contra los dedos del oponente. El número más alto gana.

![Attack illustration](/assets/gifs/attack.gif)

Si un ataque tiene éxito, todos los dados de tu tierra excepto uno tomarán la tierra de tu oponente. Un dado se quedará atrás.

Si un ataque falla, tu tierra será reducida a un dado.

Después de tu turno recibirás un dado por *tierra conectada*. Si tienes varias "continentes" entonces solo recibirás dados por el número de tierras en tu continente mayor. Si todas tus tierras están a tope de dados, entonces los dados recibidos se ponen en tu reserva, y los recibirás en cuanto haya hueco.

> ProTip: no esparzas tus tierras por ahí ni ataques a lo loco. En vez de eso, céntrate en mantener tus tierras conectas y cortar tus oponentes. Eso les mantendrá a raya.
"""

                    _ ->
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
"""
                ]

        About ->
            Markdown.toHtml [] """
## About *¡Qué Dice!*

A dice game, written in [Elm](https://elm-lang.org). A simplified Risk, inspired by [dicewars](http://www.gamedesign.jp/games/dicewars/) and its successor.

Created by <ste3ls@gmail.com>.
"""


update : Model -> Static.Types.Msg -> ( Model, Cmd Msg )
update model msg =
    case msg of
        Static.Types.SelectTab idx ->
            let
                staticPage =
                    model.staticPage

                help =
                    staticPage.help
            in
                ( { model | staticPage = { staticPage | help = { help | tab = idx } } }, Cmd.none )
