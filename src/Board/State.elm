port module Board.State exposing (init, update, updateLands)

import Board.Types exposing (..)
import Land


init : Land.Map -> Model
init map =
    Model map Nothing Disabled


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
            clickLand model land


updateLands : Model -> List LandUpdate -> Bool -> Model
updateLands model update hasTurn =
    let
        map =
            model.map

        lands =
            List.map (updateLand update) map.lands

        map_ =
            { map | lands = lands }

        move =
            if not hasTurn then
                Disabled
            else if model.move == Disabled then
                Idle
            else
                model.move
    in
        { model | map = map_, move = move }


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


clickLand : Model -> Land.Land -> ( Model, Cmd Msg )
clickLand model land =
    case model.move of
        Disabled ->
            model ! []

        Idle ->
            { model | move = From land } ! []

        From from ->
            let
                _ =
                    Debug.log "FromTo" ( from, land )
            in
                { model | move = FromTo from land } ! []

        FromTo from to ->
            { model | move = Idle } ! []
