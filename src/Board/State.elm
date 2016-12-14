port module Board.State exposing (init, update, subscriptions)

import Window
import Task
import Board.Types exposing (..)
import Board.View exposing (widthElementId)
import Land


init : Land.Map -> ( Model, Cmd Msg )
init map =
    ( Model 850 map
    , Task.perform (\a -> Debug.log "?" a) sizeToMsg Window.size
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        { width, map } =
            model
    in
        case msg of
            WindowResize size ->
                ( model, queryWidth widthElementId )

            Resize width ->
                ( Model width map, Cmd.none )

            HoverLand land ->
                let
                    map' =
                        Land.highlight True map land
                in
                    if map' /= map then
                        ( { model | map = map' }, Cmd.none )
                    else
                        ( model, Cmd.none )

            UnHoverLand land ->
                let
                    map' =
                        (Land.highlight False map land)
                in
                    if map' /= map then
                        ( Model width map', Cmd.none )
                    else
                        ( model, Cmd.none )

            _ ->
                ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Window.resizes sizeToMsg
        , width (\w -> (Resize w))
        ]


sizeToMsg : Window.Size -> Msg
sizeToMsg size =
    Debug.log "size" (WindowResize ( size.width, size.height ))


port queryWidth : String -> Cmd msg


port width : (Int -> msg) -> Sub msg
