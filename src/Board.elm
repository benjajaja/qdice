module Board exposing (LandUpdate, Model, Msg, animations, init, update, updateAnimations, view)

import Animation
import Board.State
import Board.Types
import Board.View
import Dict
import Html.Lazy


type alias Msg =
    Board.Types.Msg


type alias Model =
    Board.Types.Model


type alias LandUpdate =
    Board.Types.LandUpdate


init =
    Board.State.init


update =
    Board.State.update


view =
    Html.Lazy.lazy Board.View.view


animations : Model -> List Animation.State
animations model =
    Dict.values model.animations


updateAnimations : Model -> (Animation.State -> Animation.State) -> Model
updateAnimations model mapper =
    { model
        | animations = Dict.map (\k -> mapper) model.animations
    }
