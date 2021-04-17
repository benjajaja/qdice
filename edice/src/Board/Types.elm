module Board.Types exposing (AnimationState, BoardAnimations, BoardMove(..), BoardOptions, BoardPlayer, DiceAnimations, Model, Msg(..), PathCache, getLayout)

import Animation
import Array exposing (Array)
import Dict exposing (Dict)
import Land exposing (Color, DiceSkin, Emoji, Land, Map, MapSize)


type Msg
    = ClickLand Land.Emoji
    | HoverLand Land.Emoji
    | UnHoverLand Land.Emoji


type alias Model =
    { map : Map

    -- , hovered : Maybe Land.Emoji
    , move : BoardMove
    , pathCache : PathCache
    , layout : MapSize
    , viewBox : String
    , animations : BoardAnimations
    , avatarUrls : Maybe (List ( Color, String ))
    }


type alias BoardOptions =
    { diceVisible : Bool
    , showEmojis : Bool
    , height : Maybe Int
    }


type alias BoardAnimations =
    { stack : Maybe ( Emoji, AnimationState )
    , dice : DiceAnimations
    }


type alias DiceAnimations =
    Dict Emoji (Array Bool)


type alias PathCache =
    Dict String String


type alias AnimationState =
    Animation.State


type BoardMove
    = Idle
    | From Land
    | FromTo Land Land


type alias BoardPlayer =
    { color : Color
    , skin : DiceSkin
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
