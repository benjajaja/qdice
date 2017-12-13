module Board.Types exposing (..)

import Land exposing (Map, Land, Layout)


type Msg
    = ClickLand Land
    | HoverLand Land
    | UnHoverLand Land


type alias Model =
    { map : Map
    , hovered : Maybe Land
    , move : BoardMove
    , pathCache : PathCache
    }


type alias PathCache =
    Layout -> Land -> String


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
            cellHeight * 0.75 * (toFloat mapHeight + 1 / 3) + padding |> toString
    in
        ( Layout ( cellWidth / sqrt (3), cellWidth * heightScale / 2 ) padding
        , sWidth
        , sHeight
        )
