module Board.Colors exposing (animationColor, base, baseCssRgb, colorIndex, colorName, contrastColors, cssRgb, cssRgba, downlight, highlight, hover)

import Animation
import Color
import Color.Accessibility
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


highlight : Float -> Color.Color -> Color.Color
highlight amount =
    lighten amount


downlight : Float -> Color.Color -> Color.Color
downlight amount =
    darken amount


hover : Color.Color -> Color.Color
hover =
    darken 0.15


cssRgb : Color.Color -> String
cssRgb =
    colorToHex


cssRgba : Float -> Color.Color -> String
cssRgba alpha color =
    let
        { red, green, blue } =
            Color.toRgba color
    in
    Color.rgba red green blue alpha
        |> Color.Convert.colorToCssRgba


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

        Black ->
            8

        Brown ->
            9

        Neutral ->
            0


contrastColors : Color -> ( Int, Int ) -> ( Color.Color, Color.Color )
contrastColors from ( min, max ) =
    let
        color =
            Color.Accessibility.maximumContrast (base from)
                [ Color.rgb255 min min min, Color.rgb255 max max max ]
                |> Maybe.withDefault (Color.rgb255 min min min)

        oppositeColor =
            Color.Accessibility.maximumContrast color
                [ Color.rgb255 min min min, Color.rgb255 max max max ]
                |> Maybe.withDefault (Color.rgb255 255 255 255)
    in
    ( color, oppositeColor )
