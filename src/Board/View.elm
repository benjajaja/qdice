module Board.View exposing (view)

import String
import Board.Types exposing (..)
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Svg.Events exposing (..)
import Color exposing (..)
import Color.Convert exposing (..)
import Color.Manipulate exposing (..)
import Html
import Html.Attributes
import Html.Lazy
import Board.Types exposing (Msg, Model)
import Land exposing (Land, Map, Point, landPath, cellCenter, landCenter)


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

        layout =
            Land.Layout ( cellWidth / sqrt (3), cellWidth * heightScale / 2 ) padding

        land =
            Html.Lazy.lazy <| landElement layout
    in
        Html.div [ class "ed-board" ]
            [ Svg.svg
                [ width "100%"
                , height "100%"
                  -- , Html.Attributes.style
                  --     [ ( "padding", "2px" )
                  --     , ( "box-sizing", "border-box" )
                  --     ]
                , viewBox ("0 0 " ++ sWidth ++ " " ++ sHeight)
                , preserveAspectRatio "none"
                , class "ed-board--svg"
                ]
                (List.concat
                    [ List.map land map.lands
                    , [ Svg.defs []
                            [ Svg.radialGradient [ id "editorGradient" ]
                                [ Svg.stop [ offset "0.8", stopColor "gold" ] []
                                , Svg.stop [ offset "0.9", stopColor (svgColor False Land.Neutral) ] []
                                ]
                            ]
                      , Svg.defs []
                            [ Svg.filter [ id "dropshadow", filterUnits "userSpaceOnUse", colorInterpolationFilters "sRGB" ]
                                [ Svg.feComponentTransfer [ Html.Attributes.attribute "in" "SourceAlpha" ]
                                    [ Svg.feFuncR [ Svg.Attributes.type_ "discrete", tableValues "0" ] []
                                    , Svg.feFuncG [ Svg.Attributes.type_ "discrete", tableValues "0" ] []
                                    , Svg.feFuncB [ Svg.Attributes.type_ "discrete", tableValues "0" ] []
                                    ]
                                , Svg.feGaussianBlur [ stdDeviation "1" ] []
                                , Svg.feOffset [ dx "0", dy "0", result "shadow" ] []
                                , Svg.feComposite [ Html.Attributes.attribute "in" "SourceGraphic", in2 "shadow", operator "over" ] []
                                ]
                            ]
                      ]
                    ]
                )
            ]


landElement : Land.Layout -> Land.Land -> Svg Msg
landElement layout land =
    g
        [ onClick (ClickLand land)
        , onMouseOver (HoverLand land)
        , onMouseOut (UnHoverLand land)
        ]
        ((polygon
            (polygonAttrs layout land)
            []
         )
            :: (landText layout land)
        )


polygonAttrs : Land.Layout -> Land.Land -> List (Svg.Attribute Msg)
polygonAttrs layout land =
    [ fill <| landColor land
    , stroke "black"
    , strokeLinejoin "round"
    , strokeWidth (1 |> toString)
    , Html.Attributes.attribute "vector-effect" "non-scaling-stroke"
    , landPath layout land.cells |> landPointsString |> points
    ]


landPointsString : List Point -> String
landPointsString path =
    path |> List.foldl addPointToString ""


addPointToString : Point -> String -> String
addPointToString point path =
    path ++ (pointToString point) ++ " "


pointToString : Point -> String
pointToString ( x, y ) =
    (x |> toString) ++ "," ++ (y |> toString)


landText : Land.Layout -> Land.Land -> List (Svg Msg)
landText layout land =
    landCenter layout land.cells
        |> (\c ->
                let
                    ( cx, cy ) =
                        c
                in
                    [ Svg.text_
                        [ x <| toString cx
                        , y <| toString cy
                        , textAnchor "middle"
                        , alignmentBaseline "central"
                        ]
                        [ Html.text land.emoji ]
                    ]
           )



--List.map
--(\c ->
--let
--( cx, cy ) =
--cellCenter layout c
--in
--Svg.text_
--[ x <| toString cx
--, y <| toString cy
--, textAnchor "middle"
--, alignmentBaseline "central"
--]
--[ Html.text land.emoji ]
--)
--land.cells


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
