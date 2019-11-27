module Board.Colors exposing (base, baseCssRgb, cssRgb, highlight, hover, colorName, animationColor)

import Color
import Color.Convert exposing (colorToHex)
import Color.Manipulate exposing (darken, lighten)
import Land exposing (Color)
import Animation


base : Color -> Color.Color
base color =
    case color of
        Land.Neutral ->
            Color.rgb255 240 240 240

        Land.Black ->
            Color.rgb255 52 52 52

        Land.Red ->
            Color.rgb255 196 2 51

        Land.Green ->
            Color.rgb255 0 159 107

        Land.Blue ->
            Color.rgb255 0 135 189

        Land.Yellow ->
            Color.rgb255 255 211 0

        Land.Magenta ->
            Color.rgb255 187 86 149

        Land.Cyan ->
            Color.rgb255 103 189 170

        Land.Orange ->
            Color.rgb255 245 130 48

        Land.Beige ->
            Color.rgb255 255 250 200

        Land.Editor ->
            Color.rgb255 255 128 0

        Land.EditorSelected ->
            Color.rgb255 255 0 255


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
        Land.Neutral ->
            "neutral"

        Land.Black ->
            "black"

        Land.Red ->
            "red"

        Land.Green ->
            "green"

        Land.Blue ->
            "blue"

        Land.Yellow ->
            "yellow"

        Land.Magenta ->
            "magenta"

        Land.Cyan ->
            "cyan"

        Land.Orange ->
            "orange"

        Land.Beige ->
            "beige"

        Land.Editor ->
            "editor"

        Land.EditorSelected ->
            "editor-selected"


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
