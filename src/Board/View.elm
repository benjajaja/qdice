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
    board 100
        model.map
        (case model.move of
            Disabled ->
                []

            Idle ->
                []

            From land ->
                [ land ]

            FromTo from to ->
                [ from, to ]
        )
        model.hovered


heightScale : Float
heightScale =
    0.5


padding : Float
padding =
    0


board : Int -> Land.Map -> List Land -> Maybe Land -> Svg Msg
board w map selected hovered =
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

        landF =
            Html.Lazy.lazy <| landElement layout selected hovered
    in
        Html.div [ class "ed-board" ]
            [ Svg.svg
                [ width "100%"
                , height "100%"
                , viewBox ("0 0 " ++ sWidth ++ " " ++ sHeight)
                , preserveAspectRatio "none"
                , class "ed-board--svg"
                ]
                (List.concat
                    [ List.map landF map.lands
                    , [ Svg.defs []
                            [ Svg.radialGradient [ id "editorGradient" ]
                                [ Svg.stop [ offset "0.8", stopColor "gold" ] []
                                , Svg.stop [ offset "0.9", stopColor (svgColor False False Land.Neutral) ] []
                                ]
                            , Svg.radialGradient [ id "selectedGradient" ]
                                [ Svg.stop [ offset "0.8", stopColor "gold" ] []
                                , Svg.stop [ offset "0.9", stopColor ("rgba(0,0,0,0)") ] []
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


landElement : Land.Layout -> List Land.Land -> Maybe Land -> Land.Land -> Svg Msg
landElement layout selected hovered land =
    let
        isSelected =
            List.member land selected

        isHovered =
            case hovered of
                Just l ->
                    l == land

                Nothing ->
                    False
    in
        g
            [ onClick (ClickLand land)
            , onMouseOver (HoverLand land)
            , onMouseOut (UnHoverLand land)
            ]
            [ polygon (polygonAttrs layout isSelected isHovered land) []
            , landText layout land
            , landDies layout land
            ]


polygonAttrs : Land.Layout -> Bool -> Bool -> Land.Land -> List (Svg.Attribute Msg)
polygonAttrs layout selected hovered land =
    [ fill <| landColor selected hovered land
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


landDies : Land.Layout -> Land.Land -> Svg Msg
landDies layout land =
    g [ color <| landColor False False land ] <|
        List.map
            (landDie
                (landCenter
                    layout
                    land.cells
                )
                land.points
            )
        <|
            List.range
                0
                (land.points - 1)


landDie : ( Float, Float ) -> Int -> Int -> Svg Msg
landDie ( cx, cy ) points index =
    let
        xOffset =
            if points > 4 then
                if index >= 4 then
                    1.0
                else
                    2.75
            else
                1.5

        yOffset =
            if index >= 4 then
                1.15
            else
                1.5
    in
        --die
        --(toString <| cx - xOffset)
        --(toString <| cy - yOffset - (toFloat (index % 4) * 1.8))
        Svg.image
            [ x <| toString <| cx - xOffset
            , y <| toString <| cy - yOffset - (toFloat (index % 4) * 1.8)
            , textAnchor "middle"
            , alignmentBaseline "central"
            , class "edBoard--dies"
            , xlinkHref "die.svg"
            , height "3"
            , width "3"
            ]
            []


landText : Land.Layout -> Land.Land -> Svg Msg
landText layout land =
    landCenter layout land.cells
        |> (\c ->
                let
                    ( cx, cy ) =
                        c
                in
                    Svg.text_
                        [ x <| toString cx
                        , y <| toString cy
                        , textAnchor "middle"
                        , alignmentBaseline "central"
                        , class "edBoard--emoji"
                        ]
                        [ Html.text land.emoji ]
           )


landColor : Bool -> Bool -> Land -> String
landColor selected hovered land =
    case land.color of
        Land.EditorSelected ->
            "url(#editorGradient)"

        _ ->
            --"url(#selectedGradient) " ++
            (svgColor selected hovered land.color)


svgColor : Bool -> Bool -> Land.Color -> String
svgColor selected hovered color =
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
        |> (if selected then
                Color.Manipulate.lighten 0.5
            else if hovered then
                Color.Manipulate.darken 0.1
            else
                identity
           )
        |> Color.Convert.colorToCssRgb
