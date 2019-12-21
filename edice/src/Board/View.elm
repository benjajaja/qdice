module Board.View exposing (view)

import Animation
import Array
import Board.Colors
import Board.PathCache
import Board.Types exposing (..)
import Dict
import Helpers exposing (dataTestId, dataTestValue, find)
import Html
import Html.Attributes
import Html.Lazy
import Land exposing (Land, Layout, landCenter, playerColors)
import String
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Svg.Events exposing (..)
import Svg.Lazy


empty : List a
empty =
    []


view : Model -> Maybe Land.Emoji -> Html.Html Msg
view model hovered =
    Html.Lazy.lazy6 board
        model.map
        model.layout
        model.pathCache
        model.animations
        (case model.move of
            Idle ->
                empty

            From land ->
                [ land ]

            FromTo from to ->
                [ from, to ]
        )
        hovered


board : Land.Map -> ( Layout, String, String ) -> PathCache -> Animations -> List Land -> Maybe Land.Emoji -> Svg Msg
board map ( layout, sWidth, sHeight ) pathCache animations selected hovered =
    let
        -- massShapeF =
        -- Html.Lazy.lazy <| massElement layout pathCache
        landDiesF =
            Html.Lazy.lazy <| lazyLandDies layout animations
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
            [ die
            , Svg.Lazy.lazy4 waterConnections layout pathCache map.extraAdjacency map.lands
            , Svg.Lazy.lazy5 realLands
                layout
                pathCache
                selected
                hovered
                map.lands
            , g [] <| List.map landDiesF map.lands
            ]
        ]


realLands :
    Layout
    -> PathCache
    -> List Land
    -> Maybe Land.Emoji
    -> List Land
    -> Svg Msg
realLands layout pathCache selected hovered lands =
    g [] <|
        List.map
            (lazyLandElement layout
                pathCache
                selected
                hovered
            )
            lands


lazyLandElement :
    Layout
    -> PathCache
    -> List Land.Land
    -> Maybe Land.Emoji
    -> Land.Land
    -> Svg Msg
lazyLandElement layout pathCache selected hovered land =
    let
        isSelected =
            List.member land selected

        isHovered =
            case hovered of
                Just emoji ->
                    emoji == land.emoji

                Nothing ->
                    False
    in
    Svg.Lazy.lazy5 landElement layout pathCache isSelected isHovered land


landElement : Layout -> PathCache -> Bool -> Bool -> Land.Land -> Svg Msg
landElement layout pathCache isSelected isHovered land =
    polygon
        [ fill <| landColor isSelected isHovered land.color
        , stroke "black"
        , strokeLinejoin "round"
        , strokeWidth "1"
        , Html.Attributes.attribute "vector-effect" "non-scaling-stroke"
        , points <| Board.PathCache.points pathCache layout land
        , class "edLand"
        , onClick (ClickLand land)
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
        []



-- massElement : Layout -> PathCache -> Land -> Svg Msg
-- massElement layout pathCache land =
-- polygon
-- [ fill "transparent"
-- , stroke "black"
-- , strokeLinejoin "round"
-- , strokeWidth "1.5"
-- , Html.Attributes.attribute "vector-effect" "non-scaling-stroke"
-- , points <| Board.PathCache.points pathCache layout land
-- , class "edLandOutline"
-- ]
-- []


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


lazyLandDies : Layout -> Animations -> Land.Land -> Svg Msg
lazyLandDies layout animations land =
    let
        stackAnimation : Maybe AnimationState
        stackAnimation =
            Dict.get ("attack_" ++ land.emoji) animations

        diceAnimations : Array.Array (Maybe AnimationState)
        diceAnimations =
            getDiceAnimations animations land
    in
    Svg.Lazy.lazy4 landDies layout stackAnimation diceAnimations land


getDiceAnimations : Animations -> Land.Land -> Array.Array (Maybe AnimationState)
getDiceAnimations dict land =
    let
        animations =
            List.range 0 (land.points - 1)
                |> List.map (getLandDieKey land)
                |> List.map (\k -> Dict.get k dict)
    in
    if
        List.any
            (\i ->
                case i of
                    Just _ ->
                        True

                    Nothing ->
                        False
            )
            animations
    then
        Array.fromList animations

    else
        Array.empty


landDies : Layout -> Maybe AnimationState -> Array.Array (Maybe AnimationState) -> Land.Land -> Svg Msg
landDies layout stackAnimation diceAnimations land =
    g
        (class "edBoard--stack"
            :: (case stackAnimation of
                    Just animation ->
                        Animation.render animation

                    Nothing ->
                        []
               )
        )
    <|
        List.map
            (landDie
                diceAnimations
                -- (\i -> Dict.get (getLandDieKey land i) animations)
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


landDie : Array.Array (Maybe AnimationState) -> ( Float, Float ) -> Int -> Int -> Svg Msg
landDie animations ( cx, cy ) points index =
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

        animation : Maybe AnimationState
        animation =
            Array.get index animations |> Maybe.andThen identity
    in
    Svg.use
        (List.concat
            [ case animation of
                Just a ->
                    Animation.render a

                Nothing ->
                    []
            , [ y <| String.fromFloat <| cy - yOffset - (toFloat (modBy 4 index) * 1.2)
              , x <| String.fromFloat <| cx - xOffset
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


waterConnections : Layout -> PathCache -> List ( Land.Emoji, Land.Emoji ) -> List Land -> Svg Msg
waterConnections layout pathCache connections lands =
    g [] <| List.map (waterConnection layout pathCache lands) connections


waterConnection : Layout -> PathCache -> List Land.Land -> ( Land.Emoji, Land.Emoji ) -> Svg Msg
waterConnection layout pathCache lands ( from, to ) =
    Svg.path
        [ d <| Board.PathCache.line pathCache layout lands from to
        , fill "none"
        , stroke "black"
        , strokeDasharray "3 2"
        , strokeLinejoin "round"
        , strokeWidth "2"
        , Html.Attributes.attribute "vector-effect" "non-scaling-stroke"
        ]
        []


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
