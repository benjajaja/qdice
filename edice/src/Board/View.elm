module Board.View exposing (view)

import Animation
import Array exposing (Array)
import Board.Colors exposing (contrastColors)
import Board.Die exposing (diceDefs, skinId)
import Board.PathCache
import Board.Types exposing (..)
import Dict
import Helpers exposing (dataTestId, dataTestValue)
import Html
import Html.Attributes
import Html.Lazy
import Land exposing (Capital, DiceSkin, LandDict)
import String
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Svg.Events exposing (..)
import Svg.Keyed
import Svg.Lazy


view : Model -> Maybe Land.Emoji -> BoardOptions -> Html.Html Msg
view model hovered options =
    Html.Lazy.lazy3 board
        model
        hovered
        options


board : Model -> Maybe Land.Emoji -> BoardOptions -> Svg Msg
board { map, viewBox, pathCache, animations, move, avatarUrls } hovered options =
    Html.div [ class "edBoard" ]
        [ Svg.svg
            ([ Svg.Attributes.viewBox viewBox

             -- , preserveAspectRatio "xMidYMin meet"
             , class "edBoard--svg"
             ]
                ++ (case options.height of
                        -- Just height ->
                            -- [ Svg.Attributes.height <|
                                -- String.fromInt height
                            -- ]

                        _ ->
                            []
                   )
            )
            [ diceDefs
            , Svg.Lazy.lazy avatarDefs <| Maybe.withDefault [] avatarUrls
            , Svg.Lazy.lazy2 waterConnections pathCache map.waterConnections
            , Svg.Lazy.lazy4 realLands
                pathCache
                move
                hovered
                map.lands
            , Svg.Lazy.lazy4 allDies pathCache animations map.lands options
            ]
        ]


realLands : PathCache -> BoardMove -> Maybe Land.Emoji -> LandDict -> Svg Msg
realLands pathCache move hovered lands =
    Svg.Keyed.node "g" [] <|
        List.map
            (lazyLandElement
                pathCache
                move
                hovered
            )
        <|
            Dict.values lands


lazyLandElement : PathCache -> BoardMove -> Maybe Land.Emoji -> Land.Land -> ( Land.Emoji, Svg Msg )
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
    ( land.emoji, Svg.Lazy.lazy5 landElement pathCache isSelected isHovered land.emoji land.color )


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


allDies : PathCache -> BoardAnimations -> LandDict -> BoardOptions -> Svg Msg
allDies pathCache animations lands options =
    let
        zLands =
            List.map (allDieswithAnimations pathCache animations options) <|
                Dict.values lands

        sortedLands =
            List.sortBy Tuple.first zLands |> List.map Tuple.second
    in
    Svg.Keyed.node "g" [ class "group_dies" ] sortedLands


allDieswithAnimations : PathCache -> BoardAnimations -> BoardOptions -> Land.Land -> ( Float, ( Land.Emoji, Svg Msg ) )
allDieswithAnimations pathCache animations options land =
    let
        center =
            Board.PathCache.center pathCache land.emoji
                |> Maybe.withDefault ( 0, 0 )

        animationAttrs =
          case options.diceVisible of
            Animated -> animations.stack
                |> Maybe.andThen
                    (\( emoji, animation ) ->
                        if emoji == land.emoji then
                            Just animation

                        else
                            Nothing
                    )
                |> Maybe.map Animation.render
                |> Maybe.withDefault []
            _ -> []

        diceAnimation =
          case options.diceVisible of
            Animated -> Dict.get land.emoji animations.dice
            _ -> Nothing
    in
    ( Tuple.second center
    , ( land.emoji
      , Svg.Lazy.lazy5 animatedStackDies center animationAttrs diceAnimation options land
      )
    )


animatedStackDies : ( Float, Float ) -> List (Attribute Msg) -> Maybe (Array Bool) -> BoardOptions -> Land.Land -> Svg Msg
animatedStackDies ( x_, y_ ) animationAttrs diceAnimation options land =
    Svg.Keyed.node "g"
        (class "edBoard--stack"
            :: animationAttrs
        )
        [ ( "dies", Svg.Lazy.lazy5 landDies diceAnimation options land x_ y_ )
        , ( "text", Svg.Lazy.lazy4 capitalText land.capital x_ y_ land.color )
        ]


landDies : Maybe (Array Bool) -> BoardOptions -> Land.Land -> Float -> Float -> Svg Msg
landDies diceAnimations options land x_ y_ =
    case options.diceVisible of
      Numbers ->
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
      _ ->
        let
            diceList =
                List.range
                    0
                    (land.points - 1)
        in
        Svg.Keyed.node "g"
            [ class "edBoard--stack--inner" ]
        <|
            ( "shadow", Html.Lazy.lazy3 Board.Die.shadow land.points x_ y_ )
                :: List.map
                    (landDieShadow diceAnimations x_ y_)
                    diceList
                ++ List.map
                    (landDie diceAnimations x_ y_ land.diceSkin)
                    diceList
                ++ (if options.showEmojis then
                        [ ( "emoji", Svg.Lazy.lazy3 landEmoji x_ y_ land.emoji ) ]

                    else
                        []
                   )



landDie : Maybe (Array Bool) -> Float -> Float -> DiceSkin -> Int -> ( String, Svg Msg )
landDie animations cx cy skin index =
    let
        animation : Bool
        animation =
            animations |> Maybe.andThen (Array.get index) |> Maybe.withDefault False
    in
    ( "die_" ++ String.fromInt index
    , Svg.Lazy.lazy5 lazyDie cx cy index animation skin
    )


lazyDie : Float -> Float -> Int -> Bool -> DiceSkin -> Svg.Svg a
lazyDie x_ y_ index animated skin =
    let
        ( xOffset, yOffset ) =
            if index >= 4 then
                ( 1.0, 1.1 )

            else
                ( 2.2, 2.02 )
    in
    Svg.use
        ((if not animated then
            [ class "edBoard--dies" ]

          else
            [ class "edBoard--dies edBoard--dies__animated"
            , Svg.Attributes.style <| "animation-delay: " ++ (String.fromFloat <| (*) 0.1 <| toFloat index) ++ "s"
            ]
         )
            ++ [ x <| String.fromFloat <| x_ - xOffset
               , y <| String.fromFloat <| y_ - yOffset - (toFloat (modBy 4 index) * 1.2)
               , textAnchor "middle"
               , alignmentBaseline "central"
               , xlinkHref <| "#" ++ skinId skin
               , height "3"
               , width "3"
               ]
        )
        []


landDieShadow : Maybe (Array Bool) -> Float -> Float -> Int -> ( String, Svg Msg )
landDieShadow animations cx cy index =
    let
        animation : Bool
        animation =
            animations |> Maybe.andThen (Array.get index) |> Maybe.withDefault False
    in
    ( "die_" ++ String.fromInt index
    , Svg.Lazy.lazy4 lazyDieShadow cx cy index animation
    )


lazyDieShadow : Float -> Float -> Int -> Bool -> Svg.Svg a
lazyDieShadow x_ y_ index animated =
    let
        ( xOffset, yOffset ) =
            if index >= 4 then
                ( 1.0, 1.1 )

            else
                ( 2.2, 2.02 )
    in
    Svg.use
        ((if not animated then
            [ class "edBoard--dies" ]

          else
            [ class "edBoard--dies edBoard--dies__animated"
            , Svg.Attributes.style <| "animation-delay: " ++ (String.fromFloat <| (*) 0.1 <| toFloat index) ++ "s"
            ]
         )
            ++ [ x <| String.fromFloat <| x_ - xOffset
               , y <| String.fromFloat <| y_ - yOffset - (toFloat (modBy 4 index) * 1.2)
               , textAnchor "middle"
               , alignmentBaseline "central"
               , xlinkHref <| "#die_shadow"
               , height "3"
               , width "3"
               ]
        )
        []


landEmoji : Float -> Float -> String -> Svg.Svg a
landEmoji x_ y_ emoji =
    Svg.text_
        [ x <| String.fromFloat (x_ - 0.5)
        , y <| String.fromFloat y_
        , fontSize "3"
        ]
        [ Svg.Lazy.lazy Svg.text emoji ]


waterConnections : PathCache -> List ( Land.Emoji, Land.Emoji ) -> Svg Msg
waterConnections pathCache connections =
    g [] <| List.map (Svg.Lazy.lazy2 waterConnection pathCache) connections


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
              (if color == Land.Neutral then
                Board.Colors.downlight 0.2
              else
                Board.Colors.highlight 0.4
              )

            else
                identity
           )
        |> (if hovered then
                Board.Colors.hover

            else
                identity
           )
        |> Board.Colors.cssRgb


capitalText : Maybe Capital -> Float -> Float -> Land.Color -> Svg.Svg msg
capitalText capital x_ y_ color =
    case capital of
        Nothing ->
            text ""

        Just { count } ->
            let
                ( oppositeColor, mainColor ) =
                    contrastColors color ( 0, 255 )
            in
            g
                [ class "edBoard--stack__capital" ]
            <|
                Svg.circle
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
                    :: (if count > 0 then
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
