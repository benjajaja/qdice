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


view =
    Board.View.view
