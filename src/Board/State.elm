port module Board.State exposing (init, update, updateLands)

import Board.Types exposing (..)
import Board.PathCache exposing (createPathCache)
import Land


init : Land.Map -> Model
init map =
    Model map Nothing Idle <| createPathCache map


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        HoverLand land ->
            { model | hovered = Just land } ! []

        UnHoverLand land ->
            case model.hovered of
                Just l ->
                    if l == land then
                        { model | hovered = Nothing } ! []
                    else
                        model ! []

                Nothing ->
                    model ! []

        ClickLand land ->
            model ! []


updateLands : Model -> List LandUpdate -> Maybe BoardMove -> Model
updateLands model update move =
    let
        map =
            model.map

        lands =
            List.map (updateLand update) map.lands

        map_ =
            { map | lands = lands }

        move_ =
            case move of
                Just move ->
                    move

                Nothing ->
                    model.move
    in
        { model | map = map_, move = move_ }


updateLand : List LandUpdate -> Land.Land -> Land.Land
updateLand updates land =
    let
        update =
            List.filter (\l -> l.emoji == land.emoji) updates
    in
        case List.head update of
            Just update ->
                { land | color = update.color, points = update.points }

            Nothing ->
                land
