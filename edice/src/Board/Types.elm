module Board.Types exposing (AnimationState(..), Animations, BoardMove(..), LandUpdate, Model, Msg(..), PathCache, getLandDieKey, getLayout)

import Animation exposing (px)
import Animation.Messenger
import Dict
import Land exposing (Land, Layout, Map)
import Time exposing (Posix)


type Msg
    = ClickLand Land
    | HoverLand Land.Emoji
    | UnHoverLand Land.Emoji
    | AnimationDone String


type alias Model =
    { map : Map
    , hovered : Maybe Land.Emoji
    , move : BoardMove
    , pathCache : PathCache
    , layout : ( Layout, String, String )
    , animations : Animations
    }


type alias PathCache =
    Dict.Dict String String


type AnimationState
    = Animation (Animation.Messenger.State Msg)
    | CssAnimation Posix


type alias Animations =
    Dict.Dict String AnimationState


getLandDieKey : Land -> Int -> String
getLandDieKey land die =
    land.emoji ++ "_" ++ String.fromInt die


type BoardMove
    = Idle
    | From Land
    | FromTo Land Land


type alias LandUpdate =
    { emoji : Land.Emoji
    , color : Land.Color
    , points : Int
    }


getLayout : Map -> ( Layout, String, String )
getLayout map =
    let
        widthScale =
            100

        heightScale =
            0.5

        mapWidth =
            map.width

        mapHeight =
            map.height

        padding =
            0

        cellWidth =
            (toFloat widthScale - padding) / (toFloat mapWidth + 0.5)

        cellHeight =
            cellWidth * heightScale

        sWidth =
            String.fromInt widthScale

        sHeight =
            cellHeight * toFloat (mapHeight - 1) * 0.75 |> String.fromFloat
    in
    ( Layout ( cellWidth / sqrt 3, cellWidth * heightScale / 2 ) padding
    , sWidth
    , sHeight
    )
