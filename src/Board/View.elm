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
            ]
            (List.concat
                [ List.map landShapeF map.lands

                --, List.map massShapeF <| landMasses map.lands
                , List.map landDiesF map.lands
                ]
            )
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


landDie : (Int -> Maybe Animation.State) -> ( Float, Float ) -> Int -> Int -> Svg Msg
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
    Svg.image
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
              , xlinkHref "die.svg"
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
