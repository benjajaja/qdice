module Board.Types exposing (..)

import Dict
import Land exposing (Map, Land, Layout)
import Animation exposing (px)


type Msg
    = ClickLand Land
    | HoverLand Land
    | UnHoverLand Land


type alias Model =
    { map : Map
    , hovered : Maybe Land
    , move : BoardMove
    , pathCache : PathCache
    , animations : Animations
    }


type alias PathCache =
    Layout -> Land -> String


type alias Animations =
    Dict.Dict String Animation.State


getLandDieKey : Land -> Int -> String
getLandDieKey land die =
    land.emoji ++ "_" ++ (toString die)


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
            (toFloat widthScale - padding) / (((toFloat mapWidth) + 0.5))

        cellHeight =
            cellWidth * heightScale

        sWidth =
            toString widthScale

        sHeight =
            cellHeight * (toFloat mapHeight) * 0.6 |> toString
    in
        ( Layout ( cellWidth / sqrt (3), cellWidth * heightScale / 2 ) padding
        , sWidth
        , sHeight
        )
