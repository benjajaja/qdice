module Board.Colors exposing (animationColor, base, baseCssRgb, colorIndex, colorName, cssRgb, highlight, hover)

import Animation
import Color
import Color.Convert exposing (colorToHex)
import Color.Manipulate exposing (darken, lighten)
import Land exposing (Color(..))


base : Color -> Color.Color
base color =
    case color of
        Neutral ->
            Color.rgb255 240 240 240

        Black ->
            Color.rgb255 52 52 52

        Red ->
            Color.rgb255 196 2 51

        Green ->
            Color.rgb255 0 159 107

        Blue ->
            Color.rgb255 0 135 189

        Yellow ->
            Color.rgb255 255 211 0

        Magenta ->
            Color.rgb255 187 86 149

        Cyan ->
            Color.rgb255 64 224 208

        -- 103 189 170
        Orange ->
            Color.rgb255 245 130 48

        Brown ->
            Color.rgb255 175 135 90


highlight : Color.Color -> Color.Color
highlight =
    lighten 0.5


hover : Color.Color -> Color.Color
hover =
    darken 0.15


cssRgb : Color.Color -> String
cssRgb =
    colorToHex


baseCssRgb : Color -> String
baseCssRgb =
    base >> cssRgb


colorName : Color -> String
colorName color =
    case color of
        Neutral ->
            "neutral"

        Black ->
            "black"

        Red ->
            "red"

        Green ->
            "green"

        Blue ->
            "blue"

        Yellow ->
            "yellow"

        Magenta ->
            "magenta"

        Cyan ->
            "cyan"

        Orange ->
            "orange"

        Brown ->
            "brown"


animationColor : Color -> Animation.Color
animationColor c =
    let
        color =
            base c |> Color.toRgba
    in
    { red = round color.red
    , green = round color.green
    , blue = round color.blue
    , alpha = color.alpha
    }


colorIndex : Color -> Int
colorIndex color =
    case color of
        Red ->
            1

        Blue ->
            2

        Green ->
            3

        Yellow ->
            4

        Magenta ->
            5

        Cyan ->
            6

        Orange ->
            7

        Brown ->
            8

        Black ->
            9

        Neutral ->
            0
