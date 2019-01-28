module Board.Colors exposing (base, baseCssRgb, cssRgb, highlight, hover, colorName)

import Color
import Color.Convert exposing (colorToCssRgb)
import Color.Manipulate exposing (darken, lighten)
import Land exposing (Color)


base : Color -> Color.Color
base color =
    case color of
        Land.Neutral ->
            Color.rgb 240 240 240

        Land.Black ->
            Color.rgb 52 52 52

        Land.Red ->
            Color.rgb 196 2 51

        Land.Green ->
            Color.rgb 0 159 107

        Land.Blue ->
            Color.rgb 0 135 189

        Land.Yellow ->
            Color.rgb 255 211 0

        Land.Magenta ->
            Color.rgb 187 86 149

        Land.Cyan ->
            Color.rgb 103 189 170

        Land.Orange ->
            Color.rgb 245 130 48

        Land.Beige ->
            Color.rgb 255 250 200

        Land.Editor ->
            Color.rgb 255 128 0

        Land.EditorSelected ->
            Color.rgb 255 0 255


highlight : Color.Color -> Color.Color
highlight =
    lighten 0.5


hover : Color.Color -> Color.Color
hover =
    darken 0.15


cssRgb : Color.Color -> String
cssRgb =
    colorToCssRgb


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
