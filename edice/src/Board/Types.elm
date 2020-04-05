module Board.Types exposing (AnimationState(..), Animations, BoardMove(..), LandUpdate, Model, Msg(..), PathCache, getLandDieKey, getLayout)

import Animation exposing (px)
import Animation.Messenger
import Dict
import Land exposing (Land, Map, MapSize)
import Time exposing (Posix)


type Msg
    = ClickLand Land.Emoji
    | HoverLand Land.Emoji
    | UnHoverLand Land.Emoji
    | AnimationDone String


type alias Model =
    { map : Map
    , hovered : Maybe Land.Emoji
    , move : BoardMove
    , pathCache : PathCache
    , layout : ( MapSize, String )
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


getLayout : Map -> ( MapSize, String )
getLayout map =
    let
        heightScale =
            0.5

        mapWidth =
            toFloat map.width

        mapHeight =
            toFloat map.height

        cellWidth =
            100 / (mapWidth + 0.5) / sqrt 3

        cellHeight =
            cellWidth * heightScale

        sWidth =
            100 |> String.fromFloat

        sHeight =
            100
                * ((mapHeight + 1)
                    / mapWidth
                  )
                * heightScale
                * 0.8
                -- 2/3rds
                |> String.fromFloat
    in
    ( ( cellWidth, cellHeight )
    , "0 0 " ++ sWidth ++ " " ++ sHeight
    )
