port module Board.State exposing (init, update, updateLands)

import Board.Types exposing (..)
import Land


init : Land.Map -> Model
init map =
    Model map


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        HoverLand land ->
            let
                map =
                    Land.highlight True model.map land
            in
                if map /= model.map then
                    ( { model | map = map }, Cmd.none )
                else
                    ( model, Cmd.none )

        UnHoverLand land ->
            let
                map =
                    (Land.highlight False model.map land)
            in
                if map /= model.map then
                    ( Model map, Cmd.none )
                else
                    ( model, Cmd.none )

        _ ->
            ( model, Cmd.none )


updateLands : Model -> List LandUpdate -> Model
updateLands model update =
    let
        map =
            model.map

        lands =
            List.map (updateLand update) map.lands

        map_ =
            { map | lands = lands }
    in
        { model | map = map_ }


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
