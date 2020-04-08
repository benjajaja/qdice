module Board.View exposing (view)

import Animation
import Animation.Messenger
import Array
import Board.Colors
import Board.Die exposing (die)
import Board.PathCache
import Board.Types exposing (..)
import Color
import Color.Accessibility
import Dict
import Helpers exposing (dataTestId, dataTestValue)
import Html
import Html.Attributes
import Html.Lazy
import Land exposing (Land, MapSize, landCenter)
import String
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Svg.Events exposing (..)
import Svg.Lazy


empty : List a
empty =
    []


view : Model -> Maybe Land.Emoji -> Bool -> Html.Html Msg
view model hovered diceVisible =
    Html.Lazy.lazy7 board
        model.map
        model.layout
        model.pathCache
        model.animations
        model.move
        hovered
        diceVisible


board : Land.Map -> ( MapSize, String ) -> PathCache -> Animations -> BoardMove -> Maybe Land.Emoji -> Bool -> Svg Msg
board map ( layout, mapViewBox ) pathCache animations move hovered diceVisible =
    Html.div [ class "edBoard" ]
        [ Svg.svg
            [ viewBox mapViewBox

            -- , preserveAspectRatio "xMidYMin meet"
            , class "edBoard--svg"
            ]
            [ die
            , Svg.Lazy.lazy4 waterConnections layout pathCache map.waterConnections map.lands
            , Svg.Lazy.lazy5 realLands
                layout
                pathCache
                move
                hovered
                map.lands
            , Svg.Lazy.lazy4 allDies layout animations map.lands diceVisible
            ]
        ]


realLands :
    MapSize
    -> PathCache
    -> BoardMove
    -> Maybe Land.Emoji
    -> List Land
    -> Svg Msg
realLands layout pathCache move hovered lands =
    g [] <|
        List.map
            (lazyLandElement layout
                pathCache
                move
                hovered
            )
            lands


lazyLandElement :
    MapSize
    -> PathCache
    -> BoardMove
    -> Maybe Land.Emoji
    -> Land.Land
    -> Svg Msg
lazyLandElement layout pathCache move hovered land =
    let
        isSelected =
            case move of
                Idle ->
                    False

                From from ->
                    land == from

                FromTo from to ->
                    land == from || land == to

        isHovered =
            case hovered of
                Just emoji ->
                    emoji == land.emoji

                Nothing ->
                    False
    in
    Svg.Lazy.lazy5 landElement layout pathCache isSelected isHovered land


landElement : MapSize -> PathCache -> Bool -> Bool -> Land.Land -> Svg Msg
landElement layout pathCache isSelected isHovered land =
    polygon
        [ fill <| landColor isSelected isHovered land.color
        , stroke "black"
        , strokeLinejoin "round"
        , strokeWidth "1"
        , Html.Attributes.attribute "vector-effect" "non-scaling-stroke"
        , points <| Board.PathCache.points pathCache layout land
        , class "edLand"
        , onClick (ClickLand land.emoji)
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


allDies : MapSize -> Animations -> List Land.Land -> Bool -> Svg Msg
allDies layout animations lands diceVisible =
    g [] <| List.map (lazyLandDies layout animations diceVisible) lands


lazyLandDies : MapSize -> Animations -> Bool -> Land.Land -> Svg Msg
lazyLandDies layout animations diceVisible land =
    let
        stackAnimation : Maybe (Animation.Messenger.State Msg)
        stackAnimation =
            Dict.get ("attack_" ++ land.emoji) animations
                |> Maybe.andThen
                    (\a ->
                        case a of
                            Animation b ->
                                Just b

                            _ ->
                                Nothing
                    )

        diceAnimations : Array.Array Bool
        diceAnimations =
            getDiceAnimations animations land
    in
    Svg.Lazy.lazy5 landDies layout stackAnimation diceAnimations diceVisible land


getDiceAnimations : Animations -> Land.Land -> Array.Array Bool
getDiceAnimations dict land =
    let
        animations =
            List.range 0 (land.points - 1)
                |> List.map (getLandDieKey land)
                |> List.map (\k -> Dict.get k dict)
                |> List.map
                    (\v ->
                        case v of
                            Just a ->
                                case a of
                                    CssAnimation _ ->
                                        True

                                    _ ->
                                        False

                            Nothing ->
                                False
                    )
    in
    if
        List.any
            identity
            animations
    then
        Array.fromList animations

    else
        Array.empty


landDies : MapSize -> Maybe (Animation.Messenger.State Msg) -> Array.Array Bool -> Bool -> Land.Land -> Svg Msg
landDies layout stackAnimation diceAnimations diceVisible land =
    let
        ( x_, y_ ) =
            landCenter
                layout
                land.cells

        animationAttrs =
            case stackAnimation of
                Just animation ->
                    Animation.render animation

                Nothing ->
                    []
    in
    if diceVisible == True then
        g
            (class "edBoard--stack"
                :: animationAttrs
            )
        <|
            List.map
                (Svg.Lazy.lazy4 landDie diceAnimations x_ y_)
            <|
                List.range
                    0
                    (land.points - 1)

    else
        let
            color =
                Color.Accessibility.maximumContrast (Board.Colors.base land.color)
                    [ Color.rgb255 30 30 30, Color.rgb255 225 225 225 ]
                    |> Maybe.withDefault (Color.rgb255 30 30 30)

            oppositeColor =
                Color.Accessibility.maximumContrast color
                    [ Color.rgb255 30 30 30, Color.rgb255 225 225 225 ]
                    |> Maybe.withDefault (Color.rgb255 255 255 255)
        in
        text_
            ([ class "edBoard--stack edBoard--stack__text"
             , x <| String.fromFloat x_
             , y <| String.fromFloat y_
             , oppositeColor
                |> Board.Colors.cssRgb
                |> stroke
             , color
                |> Board.Colors.cssRgb
                |> fill
             , textAnchor "middle"
             ]
                ++ animationAttrs
            )
            [ Svg.text <| String.fromInt land.points ]


landDie : Array.Array Bool -> Float -> Float -> Int -> Svg Msg
landDie animations cx cy index =
    let
        ( xOffset, yOffset ) =
            if index >= 4 then
                ( 1.0, 1.1 )

            else
                ( 2.2, 2 )

        animation : Bool
        animation =
            case Array.get index animations of
                Just b ->
                    b

                Nothing ->
                    False
    in
    Svg.use
        ((if animation == False then
            [ class "edBoard--dies" ]

          else
            [ class "edBoard--dies edBoard--dies__animated"
            , Svg.Attributes.style <| "animation-delay: " ++ (String.fromFloat <| (*) 0.1 <| toFloat index) ++ "s"
            ]
         )
            ++ [ y <| String.fromFloat <| cy - yOffset - (toFloat (modBy 4 index) * 1.2)
               , x <| String.fromFloat <| cx - xOffset
               , textAnchor "middle"
               , alignmentBaseline "central"
               , xlinkHref "#die"
               , height "3"
               , width "3"
               ]
        )
        []


waterConnections : MapSize -> PathCache -> List ( Land.Emoji, Land.Emoji ) -> List Land -> Svg Msg
waterConnections layout pathCache connections lands =
    g [] <| List.map (waterConnection layout pathCache lands) connections


waterConnection : MapSize -> PathCache -> List Land.Land -> ( Land.Emoji, Land.Emoji ) -> Svg Msg
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
