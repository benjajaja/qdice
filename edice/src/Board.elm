module Board exposing (LandUpdate, Model, Msg, animations, canAttackFrom, canMove, init, update, updateAnimations, view)

import Animation
import Board.State
import Board.Types exposing (BoardMove, Model)
import Board.View
import Html
import Html.Lazy
import Land exposing (Color, Emoji, Land, Map, findLand)


type alias Msg =
    Board.Types.Msg


type alias Model =
    Board.Types.Model


type alias LandUpdate =
    Board.Types.LandUpdate


init : Land.Map -> Model
init =
    Board.State.init


update : Msg -> Model -> ( Model, Cmd Msg )
update =
    Board.State.update


view : Model -> Maybe Land.Emoji -> Bool -> Html.Html Msg
view =
    Html.Lazy.lazy3 Board.View.view


animations : Model -> List Animation.State
animations model =
    case model.animations.stack of
        Just ( _, a ) ->
            [ a ]

        Nothing ->
            []


updateAnimations : Model -> Animation.Msg -> Model
updateAnimations model animMsg =
    let
        animations_ =
            model.animations

        stack =
            Maybe.map (Tuple.mapSecond (Animation.update animMsg)) animations_.stack
    in
    { model
        | animations = { animations_ | stack = stack }
    }


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
