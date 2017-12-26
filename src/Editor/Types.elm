module Editor.Types exposing (..)

import Board
import Land exposing (Land)


type Msg
    = BoardMsg Board.Msg
    | RandomLandColor Land.Land Land.Color
    | EmojiInput String


type alias Model =
    { board : Board.Model
    , emojiMap : String
    }
