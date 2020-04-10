module Board exposing (LandUpdate, Model, Msg, animations, canMove, clearCssAnimations, init, update, updateAnimations, view)

import Animation
import Animation.Messenger
import Board.State
import Board.Types exposing (BoardMove, Model)
import Board.View
import Dict
import Html.Lazy
import Land exposing (Color, Emoji, Land, Map, findLand)
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
    Html.Lazy.lazy3 Board.View.view


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


canAttackFrom : Map -> Color -> Land -> Result String ()
canAttackFrom map playerColor land =
    if land.points <= 1 then
        Err "land has no points"

    else if land.color /= playerColor then
        Err "land is not player's color"

    else
        case Land.hasAttackableNeighbours map land of
            Ok bool ->
                if bool == True then
                    Ok <| ()

                else
                    Err "no possible targets"

            Err err ->
                Err err


canMove : Model -> Color -> Emoji -> Result String BoardMove
canMove board playerColor emoji =
    case findLand emoji board.map.lands of
        Just land ->
            case board.move of
                Board.Types.Idle ->
                    case canAttackFrom board.map playerColor land of
                        Ok () ->
                            Ok <| Board.Types.From land

                        Err err ->
                            Err err

                Board.Types.From from ->
                    if land == from then
                        -- same land: deselect
                        Ok Board.Types.Idle

                    else if land.color == playerColor then
                        -- same color and...
                        if land.points > 1 then
                            case canAttackFrom board.map playerColor land of
                                Ok () ->
                                    -- can change selection
                                    Ok <| Board.Types.From land

                                Err err ->
                                    Err err

                        else
                            -- could not move: do nothing
                            Err "cannot select other land: no points"

                    else
                        case Land.isBordering board.map land from of
                            Ok isBordering ->
                                if isBordering then
                                    -- is bordering, different land and color: attack!
                                    Ok <| Board.Types.FromTo from land

                                else
                                    -- not bordering: do nothing
                                    Err <|
                                        "cannot attack far land: "
                                            ++ from.emoji
                                            ++ "->"
                                            ++ land.emoji

                            Err err ->
                                Err err

                Board.Types.FromTo _ _ ->
                    Err "ongoing attack"

        Nothing ->
            Err <| "error: ClickLand not found: " ++ emoji
