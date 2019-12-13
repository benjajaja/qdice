module Board.View exposing (view)

import Animation
import Board.Colors
import Board.Types exposing (..)
import Dict
import Helpers exposing (dataTestId, dataTestValue)
import Html
import Html.Attributes
import Html.Lazy
import Land exposing (Land, Layout, Map, Point, cellCenter, landCenter, playerColors)
import String
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Svg.Events exposing (..)


view : Model -> Maybe Land -> Html.Html Msg
view model hovered =
    lazyBoard
        model.map
        model.pathCache
        model.animations
        (case model.move of
            Idle ->
                []

            From land ->
                [ land ]

            FromTo from to ->
                [ from, to ]
        )
        hovered


lazyBoard : Land.Map -> PathCache -> Animations -> List Land -> Maybe Land -> Svg Msg
lazyBoard map pathCache animations selected hovered =
    Html.Lazy.lazy5 board map pathCache animations selected hovered


board : Land.Map -> PathCache -> Animations -> List Land -> Maybe Land -> Svg Msg
board map pathCache animations selected hovered =
    let
        ( layout, sWidth, sHeight ) =
            getLayout map

        landShapeF =
            Html.Lazy.lazy <| landElement layout pathCache selected hovered

        massShapeF =
            Html.Lazy.lazy <| massElement layout pathCache

        landDiesF =
            Html.Lazy.lazy <| landDies layout animations
    in
    Html.div [ class "edBoard" ]
        [ Svg.svg
            --[ width "100%"
            --, height "100%"
            [ viewBox ("0 0 " ++ sWidth ++ " " ++ sHeight)

            --[ viewBox ("0 0 100 100")
            , preserveAspectRatio "xMidYMin meet"
            , class "edBoard--svg"

            -- , Svg.Attributes.style "background: url(https://external-content.duckduckgo.com/iu/?u=http%3A%2F%2F2.bp.blogspot.com%2F-vtEHvcmS-Ac%2FTtHk0IvsxoI%2FAAAAAAAAAnw%2FV6e_eGfmCac%2Fs1600%2FRisk%2BII%2BGame%2BBoard.jpg&f=1&nofb=1); background-size: 110% 110%; background-position: top -20px left -30px"
            ]
          <|
            List.concat
                [ [ die ]
                , List.map landShapeF map.lands

                --, List.map massShapeF <| landMasses map.lands
                , List.map landDiesF map.lands
                ]
        ]


die : Svg Msg
die =
    defs []
        [ g
            [ id "die"
            , transform "scale(0.055)"
            ]
            [ Svg.path
                [ Svg.Attributes.style
                    "opacity:1;fill:none;fill-opacity:1;stroke:#000000;stroke-width:4;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , d "M 44.274701,38.931604 44.059081,18.315979 23.545011,3.0644163 3.0997027,18.315979 2.9528307,38.931604 23.613771,54.273792 Z"
                ]
                []
            , rect
                [ Svg.Attributes.style "opacity:1;fill:#ffffff;fill-opacity:1;stroke:#000000;stroke-width:0.70753205;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , id "rect4157"
                , width "25.320923"
                , height "25.320923"
                , x "-13.198412"
                , y "17.248964"
                , transform "matrix(0.8016383,-0.59780937,0.8016383,0.59780937,0,0)"
                ]
                []
            , Svg.path
                [ Svg.Attributes.style
                    "opacity:1;fill:#ebebeb;fill-opacity:1;stroke:#000000;stroke-width:0.57285416;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , d "m 2.9522657,18.430618 20.5011153,15.342466 0,20.501118 L 2.9522657,38.931736 Z"
                ]
                []
            , Svg.path
                [ Svg.Attributes.style
                    "opacity:1;fill:#ebebeb;fill-opacity:1;stroke:#000000;stroke-width:0.57285416;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , d "m 44.275301,18.430618 -20.50112,15.342466 0,20.501118 20.50112,-15.342466 z"
                ]
                []
            , ellipse
                [ Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , id "path4165"
                , cx "23.545307"
                , cy "18.201725"
                , rx "4.7748194"
                , ry "3.5811143"
                ]
                []
            , ellipse
                [ cy "42.152149"
                , cx "-8.0335274"
                , id "circle4167"
                , Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , rx "2.1917808"
                , ry "2.53085"
                , transform "matrix(1,0,0.5,0.8660254,0,0)"
                ]
                []
            , ellipse
                [ Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , id "circle4171"
                , cx "55.690258"
                , cy "42.094212"
                , rx "2.1917808"
                , ry "2.5308504"
                , transform "matrix(1,0,-0.5,0.8660254,0,0)"
                ]
                []
            , ellipse
                [ transform "matrix(1,0,0.5,0.8660254,0,0)"
                , ry "2.5308504"
                , rx "2.1917808"
                , Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , id "ellipse4173"
                , cx "-8.2909203"
                , cy "32.980541"
                ]
                []
            , ellipse
                [ cy "50.764507"
                , cx "-7.6902356"
                , id "ellipse4175"
                , Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , rx "2.1917808"
                , ry "2.5308504"
                , transform "matrix(1,0,0.5,0.8660254,0,0)"
                ]
                []
            , ellipse
                [ transform "matrix(1,0,-0.5,0.8660254,0,0)"
                , ry "2.5308504"
                , rx "2.1917808"
                , cy "31.414658"
                , cx "55.871754"
                , id "ellipse4177"
                , Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                ]
                []
            , ellipse
                [ Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , id "ellipse4179"
                , cx "61.509121"
                , cy "43.270634"
                , rx "2.1917808"
                , ry "2.5308504"
                , transform "matrix(1,0,-0.5,0.8660254,0,0)"
                ]
                []
            , ellipse
                [ Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , id "ellipse4181"
                , cx "49.791553"
                , cy "41.145508"
                , rx "2.1917808"
                , ry "2.5308504"
                , transform "matrix(1,0,-0.5,0.8660254,0,0)"
                ]
                []
            , ellipse
                [ transform "matrix(1,0,-0.5,0.8660254,0,0)"
                , ry "2.5308504"
                , rx "2.1917808"
                , cy "51.882996"
                , cx "55.063419"
                , id "ellipse4183"
                , Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                ]
                []
            ]
        ]


landElement : Layout -> PathCache -> List Land.Land -> Maybe Land -> Land.Land -> Svg Msg
landElement layout pathCache selected hovered land =
    let
        isSelected =
            List.member land selected

        isHovered =
            case hovered of
                Just l ->
                    l == land

                Nothing ->
                    False

        attrs =
            List.append
                (polygonAttrs layout pathCache isSelected isHovered land)
                [ onClick (ClickLand land)
                , onMouseOver (HoverLand land.emoji)
                , onMouseOut (UnHoverLand land.emoji)
                , dataTestId <| "land-" ++ land.emoji
                , dataTestValue "selected"
                    (if isSelected then
                        "true"

                     else
                        "false"
                    )
                ]
    in
    polygon attrs []


polygonAttrs : Layout -> PathCache -> Bool -> Bool -> Land.Land -> List (Svg.Attribute Msg)
polygonAttrs layout pathCache selected hovered land =
    [ fill <| landColor selected hovered land.color
    , stroke "black"
    , strokeLinejoin "round"
    , strokeWidth "1"
    , Html.Attributes.attribute "vector-effect" "non-scaling-stroke"
    , points <| pathCache layout land
    , class "edLand"
    ]


massElement : Layout -> PathCache -> Land -> Svg Msg
massElement layout pathCache land =
    polygon
        [ fill "transparent"
        , stroke "black"
        , strokeLinejoin "round"
        , strokeWidth "1.5"
        , Html.Attributes.attribute "vector-effect" "non-scaling-stroke"
        , points <| pathCache layout land
        , class "edLandOutline"
        ]
        []


landMasses : List Land -> List Land
landMasses lands =
    List.foldl
        (\land ->
            \masses ->
                List.map
                    (\mass ->
                        if mass.color == land.color then
                            { mass | cells = List.append mass.cells land.cells }

                        else
                            mass
                    )
                    masses
        )
        (List.map (\color -> { cells = [], color = color, emoji = "", points = 0 }) playerColors)
        lands


landDies : Layout -> Animations -> Land.Land -> Svg Msg
landDies layout animations land =
    let
        attrs =
            case Dict.get ("attack_" ++ land.emoji) animations of
                Just animation ->
                    Animation.render animation

                Nothing ->
                    []
    in
    g attrs <|
        List.map
            (landDie
                (\i -> Dict.get (getLandDieKey land i) animations)
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


landDie : (Int -> Maybe AnimationState) -> ( Float, Float ) -> Int -> Int -> Svg Msg
landDie getAnimation ( cx, cy ) points index =
    let
        xOffset =
            if index >= 4 then
                1.0

            else
                2.2

        yOffset =
            if index >= 4 then
                1.1

            else
                2

        animation =
            getAnimation index
    in
    Svg.use
        (List.concat
            [ case animation of
                Just a ->
                    Animation.render a

                Nothing ->
                    []
            , case animation of
                Just _ ->
                    []

                Nothing ->
                    [ y <| String.fromFloat <| cy - yOffset - (toFloat (modBy 4 index) * 1.2) ]
            , [ x <| String.fromFloat <| cx - xOffset
              , textAnchor "middle"
              , alignmentBaseline "central"
              , class "edBoard--dies"
              , xlinkHref "#die"
              , height "3"
              , width "3"
              ]
            ]
        )
        []


landText : Layout -> Land.Land -> Svg Msg
landText layout land =
    landCenter layout land.cells
        |> (\c ->
                let
                    ( cx, cy ) =
                        c
                in
                g
                    [ transform <|
                        "translate("
                            ++ (String.fromFloat <| cx - 1.75)
                            ++ ","
                            ++ (String.fromFloat <| cy + 0.5)
                            ++ ")"

                    --x <| String.fromFloat cx
                    --, y <| String.fromFloat cy
                    ]
                    [ Svg.text_
                        [ textAnchor "middle"
                        , alignmentBaseline "central"
                        , class "edBoard--emoji"
                        ]
                        [ Html.text land.emoji ]
                    ]
           )


landColor : Bool -> Bool -> Land.Color -> String
landColor selected hovered color =
    case color of
        Land.EditorSelected ->
            "url(#editorGradient)"

        _ ->
            Board.Colors.base color
                |> (if selected then
                        Board.Colors.highlight

                    else
                        identity
                   )
                |> (if hovered then
                        Board.Colors.hover

                    else
                        identity
                   )
                |> Board.Colors.cssRgb
