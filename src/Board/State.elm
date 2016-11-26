module Board.State exposing (init, update, subscriptions)

import Board.Types exposing (..)
import Land


init : ( Model, Cmd Msg )
init =
    ( Model ( 850, 600 ) (Land.fullCellMap 30 30), Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        { size, map } =
            model
    in
        case msg of
            Resize size ->
                ( Model size map, Cmd.none )

            ClickLand land ->
                ( Model size (Land.landColor map land Land.Editor), Cmd.none )

            HoverLand land ->
                let
                    map' =
                        Land.highlight True map land

                    -- |> Debug.log "hilite"
                in
                    if map' /= map then
                        let
                            _ =
                                Debug.log "hilite" <| List.length map'.lands
                        in
                            ( Model size map', Cmd.none )
                    else
                        ( model, Cmd.none )

            UnHoverLand land ->
                let
                    map' =
                        (Land.highlight False map land)
                in
                    if map' /= map then
                        ( Model size map', Cmd.none )
                    else
                        ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
