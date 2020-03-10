module Board exposing (LandUpdate, Model, Msg, animations, clearCssAnimations, init, update, updateAnimations, view)

import Animation
import Animation.Messenger
import Board.State
import Board.Types
import Board.View
import Dict
import Html.Lazy
import Time


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


animations : Model -> List (Animation.Messenger.State Msg)
animations model =
    Dict.values model.animations
        |> List.map
            (\v ->
                case v of
                    Board.Types.Animation anim ->
                        [ anim ]

                    Board.Types.CssAnimation _ ->
                        []
            )
        |> List.concat


clearCssAnimations : Model -> Time.Posix -> Model
clearCssAnimations model posix =
    { model
        | animations =
            Dict.filter
                (\_ ->
                    \v ->
                        case v of
                            Board.Types.Animation _ ->
                                True

                            Board.Types.CssAnimation time ->
                                Time.posixToMillis posix - Time.posixToMillis time < 600
                )
                model.animations
    }


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
    case v of
        Board.Types.Animation anim ->
            let
                ( new, cmd ) =
                    Animation.Messenger.update msg anim
            in
            ( k, Board.Types.Animation new, cmd )

        Board.Types.CssAnimation _ ->
            ( k, v, Cmd.none )
