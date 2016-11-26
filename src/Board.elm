module Board exposing (..)

import Board.Types
import Board.State
import Board.View


type alias Msg =
    Board.Types.Msg


type alias Model =
    Board.Types.Model


init =
    Board.State.init


update =
    Board.State.update


subscriptions =
    Board.State.subscriptions


view =
    Board.View.view
