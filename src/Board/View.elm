module Board.View exposing (view, widthElementId)

import Board.Types exposing (..)
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Svg.Events exposing (..)
import Color exposing (..)
import Color.Convert exposing (..)
import Color.Manipulate exposing (..)
import Html
import Html.Attributes
import Hexagons.Layout exposing (orientationLayoutPointy, Layout)
import Board.Types exposing (Msg, Model)
import Hex exposing (Point)
import Land exposing (Land, Map, landPath, center, cellCenter)


widthElementId : String
widthElementId =
    "edice-board"


view : Model -> Html.Html Msg
view model =
    board 100 model.map


heightScale : Float
heightScale =
    0.5


padding : Float
padding =
    0


board : Int -> Land.Map -> Svg Msg
board w map =
    let
        cellWidth =
            (toFloat w - padding) / (((toFloat map.width) + 0.5))

        -- actual cell width
        cellHeight =
            cellWidth * heightScale

        -- 0.75 + (cellWidth * 0.25) |> round |> toFloat
        sWidth =
            toString w

        sHeight =
            cellHeight * 0.75 * (toFloat map.height + 1 / 3) + padding |> toString
    in
        Html.div [ id widthElementId ]
            [ Svg.svg
                [ width "100%"
                , height "100%"
                , Html.Attributes.style
                    [ ( "padding", "2px" )
                    , ( "box-sizing", "border-box" )
                    ]
                , viewBox ("0 0 " ++ sWidth ++ " " ++ sHeight)
                , preserveAspectRatio "none"
                ]
                (List.concat
                    [ List.map (landSvg (myLayout ( cellWidth / sqrt (3), cellWidth * heightScale / 2 ) padding)) map.lands
                    , [ Svg.defs []
                            [ Svg.radialGradient [ id "editorGradient" ]
                                [ Svg.stop [ offset "0.8", stopColor "gold" ] []
                                , Svg.stop [ offset "0.9", stopColor (svgColor False Land.Neutral) ] []
                                ]
                            ]
                      ]
                    ]
                )
            ]


myLayout : ( Float, Float ) -> Float -> Hexagons.Layout.Layout
myLayout ( cellWidth, cellHeight ) padding =
    { orientation = orientationLayoutPointy
    , size = ( cellWidth, cellHeight )
    , origin = ( padding / 2, -cellHeight / 2 + padding / 2 )
    }


landSvg : Hexagons.Layout.Layout -> Land.Land -> Svg Msg
landSvg layout land =
    g []
        ((polygon
            [ fill <| landColor land
            , stroke "black"
            , strokeLinejoin "round"
            , strokeWidth (2 |> toString)
            , Html.Attributes.attribute "vector-effect" "non-scaling-stroke"
            , landPath layout land.hexagons |> landPointsString |> points
            , onClick (ClickLand land)
            , onMouseOver (HoverLand land)
            , onMouseOut (UnHoverLand land)
            ]
            []
         )
            :: []
         --(landText layout land)
        )


landPointsString : List Hex.Point -> String
landPointsString path =
    path |> List.foldl addPointToString ""


addPointToString : Hex.Point -> String -> String
addPointToString point path =
    path ++ (pointToString point) ++ " "


pointToString : Hex.Point -> String
pointToString ( x, y ) =
    (x |> toString) ++ "," ++ (y |> toString)


landColor : Land -> String
landColor land =
    case land.color of
        Land.EditorSelected ->
            "url(#editorGradient)"

        _ ->
            svgColor land.selected land.color


svgColor : Bool -> Land.Color -> String
svgColor highlight color =
    (case color of
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

        Land.Editor ->
            Color.rgb 255 128 0

        Land.EditorSelected ->
            Color.rgb 255 0 255
    )
        |> Color.Manipulate.lighten
            (if highlight then
                0.5
             else
                0.0
            )
        |> Color.Convert.colorToCssRgb


landText : Hexagons.Layout.Layout -> Land -> List (Svg Msg)
landText layout land =
    let
        ( x'', y'' ) =
            center layout land.hexagons

        x' =
            toString x''

        y' =
            toString y''
    in
        List.map
            (\c ->
                let
                    cellPoint =
                        cellCenter layout c

                    -- text' [ x (toString (x'' + 0)), y (toString (y'' + 0)) ] [ Svg.text <| x' ++ "," ++ y' ]
                in
                    text' [ x <| toString <| fst cellPoint, y <| toString <| snd cellPoint ] [ Svg.text <| toString <| Land.cellCubicCoords c ]
            )
            land.hexagons
