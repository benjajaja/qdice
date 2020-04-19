module Board.View exposing (view)

import Animation
import Array exposing (Array)
import Board.Colors exposing (contrastColors)
import Board.Die exposing (die)
import Board.PathCache
import Board.Types exposing (..)
import Dict
import Helpers exposing (dataTestId, dataTestValue)
import Html
import Html.Attributes
import Html.Lazy
import Land exposing (Capital, Land)
import String
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Svg.Events exposing (..)
import Svg.Lazy


view : Model -> Maybe Land.Emoji -> Bool -> List ( Land.Color, String ) -> Html.Html Msg
view model hovered diceVisible avatarUrls =
    Html.Lazy.lazy8 board
        model.map
        model.viewBox
        model.pathCache
        model.animations
        model.move
        hovered
        diceVisible
        avatarUrls


board : Land.Map -> String -> PathCache -> BoardAnimations -> BoardMove -> Maybe Land.Emoji -> Bool -> List ( Land.Color, String ) -> Svg Msg
board map mapViewBox pathCache animations move hovered diceVisible avatarUrls =
    Html.div [ class "edBoard" ]
        [ Svg.svg
            [ viewBox mapViewBox

            -- , preserveAspectRatio "xMidYMin meet"
            , class "edBoard--svg"
            ]
            [ die
            , avatarDefs avatarUrls
            , Svg.Lazy.lazy2 waterConnections pathCache map.waterConnections
            , Svg.Lazy.lazy4 realLands
                pathCache
                move
                hovered
                map.lands
            , Svg.Lazy.lazy4 allDies pathCache animations map.lands diceVisible
            ]
        ]


realLands : PathCache -> BoardMove -> Maybe Land.Emoji -> List Land -> Svg Msg
realLands pathCache move hovered lands =
    g [] <|
        List.map
            (lazyLandElement
                pathCache
                move
                hovered
            )
            lands


lazyLandElement : PathCache -> BoardMove -> Maybe Land.Emoji -> Land.Land -> Svg Msg
lazyLandElement pathCache move hovered land =
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
    Svg.Lazy.lazy5 landElement pathCache isSelected isHovered land.emoji land.color


landElement : PathCache -> Bool -> Bool -> Land.Emoji -> Land.Color -> Svg Msg
landElement pathCache isSelected isHovered emoji color =
    polygon
        [ fill <| landColor isSelected isHovered color
        , stroke "black"
        , strokeLinejoin "round"
        , strokeWidth "1"
        , Html.Attributes.attribute "vector-effect" "non-scaling-stroke"
        , points <| Maybe.withDefault "ERR" <| Board.PathCache.points pathCache emoji
        , class "edLand"
        , onClick (ClickLand emoji)
        , onMouseOver (HoverLand emoji)
        , onMouseOut (UnHoverLand emoji)
        , dataTestId <| "land-" ++ emoji
        , dataTestValue "selected"
            (if isSelected then
                "true"

             else
                "false"
            )
        ]
        []


allDies : PathCache -> BoardAnimations -> List Land.Land -> Bool -> Svg Msg
allDies pathCache animations lands diceVisible =
    g [] <| List.map (Svg.Lazy.lazy4 animatedStackDies pathCache animations diceVisible) lands


animatedStackDies : PathCache -> BoardAnimations -> Bool -> Land.Land -> Svg Msg
animatedStackDies pathCache { stack, dice } diceVisible land =
    let
        ( x_, y_ ) =
            Board.PathCache.center pathCache land.emoji
                |> Maybe.withDefault ( 0, 0 )

        animationAttrs =
            case stack of
                Just ( emoji, animation ) ->
                    if emoji == land.emoji then
                        Animation.render animation

                    else
                        []

                Nothing ->
                    []

        diceAnimation =
            Dict.get land.emoji dice
    in
    g [] <|
        [ g
            (class "edBoard--stack"
                :: animationAttrs
            )
            [ Svg.Lazy.lazy4 landDies diceAnimation diceVisible land ( x_, y_ )
            ]
        ]
            ++ (case land.capital of
                    Just capital ->
                        [ Svg.Lazy.lazy4 capitalText x_ y_ capital land.color ]

                    Nothing ->
                        []
               )


landDies : Maybe (Array Bool) -> Bool -> Land.Land -> ( Float, Float ) -> Svg Msg
landDies diceAnimations diceVisible land ( x_, y_ ) =
    if diceVisible == True then
        g
            [ class "edBoard--stack--inner" ]
        <|
            [ Html.Lazy.lazy3 Board.Die.shadow land.points x_ y_ ]
                ++ (List.map
                        (Svg.Lazy.lazy4 landDie diceAnimations x_ y_)
                    <|
                        List.range
                            0
                            (land.points - 1)
                   )

    else
        let
            ( color, oppositeColor ) =
                contrastColors land.color ( 30, 225 )
        in
        text_
            [ class "edBoard--stack edBoard--stack__text"
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
            [ Svg.text <| String.fromInt land.points ]


landDie : Maybe (Array Bool) -> Float -> Float -> Int -> Svg Msg
landDie animations cx cy index =
    let
        ( xOffset, yOffset ) =
            if index >= 4 then
                ( 1.0, 1.1 )

            else
                ( 2.2, 2 )

        animation : Bool
        animation =
            case animations |> Maybe.andThen (Array.get index) of
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


waterConnections : PathCache -> List ( Land.Emoji, Land.Emoji ) -> Svg Msg
waterConnections pathCache connections =
    g [] <| List.map (waterConnection pathCache) connections


waterConnection : PathCache -> ( Land.Emoji, Land.Emoji ) -> Svg Msg
waterConnection pathCache ( from, to ) =
    Svg.path
        [ d <| Maybe.withDefault "ERR" <| Board.PathCache.line pathCache from to
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
                Board.Colors.highlight 0.4

            else
                identity
           )
        |> (if hovered then
                Board.Colors.hover

            else
                identity
           )
        |> Board.Colors.cssRgb


capitalText : Float -> Float -> Capital -> Land.Color -> Svg.Svg msg
capitalText x_ y_ { count } color =
    let
        ( oppositeColor, mainColor ) =
            contrastColors color ( 0, 255 )
    in
    g
        [ class "edBoard--stack__capital" ]
    <|
        [ Svg.circle
            [ cx <| String.fromFloat (x_ - 1.5)
            , cy <| String.fromFloat (y_ + 1.0)
            , r <| String.fromInt <| round (toFloat capitalAvatarSize / 2)
            , color
                |> Board.Colors.base
                |> Board.Colors.downlight 0.1
                |> Board.Colors.cssRgb
                |> stroke

            -- , color
            -- |> Board.Colors.base
            -- |> Board.Colors.cssRgb
            -- |> fill
            , fill <| "url(#player_" ++ (color |> Board.Colors.colorIndex |> String.fromInt) ++ ")"
            ]
            []
        ]
            ++ (if count > 0 then
                    [ Svg.text_
                        [ class "edBoard--stack__reserveDice"
                        , x <| String.fromFloat (x_ - 0.1)
                        , y <| String.fromFloat (y_ + 2.7)
                        , oppositeColor
                            |> Board.Colors.cssRgb
                            |> stroke
                        , mainColor
                            |> Board.Colors.cssRgb
                            |> fill
                        , textAnchor "middle"
                        ]
                        [ Svg.text <| "+" ++ String.fromInt count ]
                    ]

                else
                    []
               )


avatarDefs : List ( Land.Color, String ) -> Html.Html Msg
avatarDefs list =
    defs [] <|
        List.map
            (\( color, url ) ->
                pattern
                    [ id <| "player_" ++ String.fromInt (Board.Colors.colorIndex color)

                    -- , patternUnits "userSpaceOnUse"
                    , x "0"
                    , y "0"
                    , width <| String.fromInt capitalAvatarSize
                    , height <| String.fromInt capitalAvatarSize
                    ]
                    [ rect
                        [ x "0"
                        , y "0"
                        , width <| String.fromInt capitalAvatarSize
                        , height <| String.fromInt capitalAvatarSize
                        , fill "black"
                        ]
                        []
                    , image
                        [ xlinkHref url
                        , x "0"
                        , y "0"
                        , width <| String.fromInt capitalAvatarSize
                        , height <| String.fromInt capitalAvatarSize
                        ]
                        []
                    ]
            )
        <|
            list


capitalAvatarSize : Int
capitalAvatarSize =
    4
