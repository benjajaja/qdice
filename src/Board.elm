module Board exposing (..)

import Html.Lazy
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
    Html.Lazy.lazy Board.View.view
