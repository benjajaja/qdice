module Board exposing (LandUpdate, Model, Msg, animations, init, update, updateAnimations, view)

import Animation
import Animation.Messenger
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
    Html.Lazy.lazy2 Board.View.view


animations : Model -> List Board.Types.AnimationState
animations model =
    Dict.values model.animations


updateAnimations : Model -> Animation.Msg -> ( Model, Cmd Msg )
updateAnimations model animMsg =
    let
        updates =
            model.animations
                |> Dict.toList
                |> List.map (updateAnimation animMsg)

        animations_ =
            updates
                |> List.map (\( k, v, _ ) -> ( k, v ))
                |> Dict.fromList

        cmds =
            updates
                |> List.map (\( _, _, c ) -> c)
    in
    ( { model
        | animations = animations_
      }
    , Cmd.batch cmds
    )


updateAnimation : Animation.Msg -> ( String, Board.Types.AnimationState ) -> ( String, Board.Types.AnimationState, Cmd Msg )
updateAnimation msg ( k, v ) =
    let
        ( new, cmd ) =
            Animation.Messenger.update msg v
    in
    ( k, new, cmd )
