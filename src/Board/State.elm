port module Board.State exposing (init, update)

import Board.Types exposing (..)
import Land


init : Land.Map -> Model
init map =
    (Model map)


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
