module Widgets.Charts exposing (..)

import Array
import Helpers exposing (dataTestId, flip, pointsSymbol, pointsToNextLevel, toDie)
import Html exposing (Html)
import Html.Attributes
import Svg exposing (..)
import Svg.Attributes exposing (..)


arrayAsList : Array.Array Int -> Int -> List Int
arrayAsList rolls size =
    List.range 0 (size - 1)
        |> List.map
            (flip Array.get rolls
                >> Maybe.withDefault 0
            )


chart : Bool -> Int -> (Int -> Html msg) -> Int -> Array.Array Int -> Html msg
chart isFetched size legends offset values =
    let
        list =
            arrayAsList values size

        max =
            List.maximum list |> Maybe.withDefault 100
    in
    List.map
        legends
        (List.range 0 size)
        |> List.append
            (List.indexedMap
                (\i value ->
                    text_
                        [ x <| String.fromInt offset
                        , y <| String.fromFloat (toFloat i * 10 + 6.5)
                        , fontSize "8"
                        , fill "#ffffff"
                        ]
                        [ text <| String.fromInt value ]
                )
                list
            )
        |> List.append
            (List.indexedMap
                (\i dice ->
                    rect
                        [ x <| String.fromInt offset
                        , y <| String.fromFloat (toFloat i * 10 + 0.25)
                        , height <| String.fromFloat 7.5
                        , width <|
                            if isFetched then
                                String.fromInt <|
                                    round <|
                                        (\w ->
                                            if isNaN w then
                                                0

                                            else
                                                w
                                        )
                                        <|
                                            toFloat dice
                                                / toFloat max
                                                * 190

                            else
                                "190"
                        , fill <|
                            if isFetched then
                                "#519ab1"

                            else
                                "#888888"
                        , opacity <|
                            if isFetched then
                                "1"

                            else
                                "0.5"
                        ]
                        []
                )
                list
            )
        |> svg [ viewBox "0 0 200 60", class "edStatistics__rolls" ]


gauge : Float -> Html msg
gauge fraction =
    svg
        [ viewBox "-10 -10 120 100", class "edStatistics__gauge" ]
        [ defs []
            [ linearGradient
                [ id "linear"
                , x1 "0%"
                , y1 "0%"
                , x2 "100%"
                , y2 "0%"
                ]
                [ stop [ offset "0%", stopColor "red" ] []
                , stop [ offset "50%", stopColor "lightgreen" ] []
                , stop [ offset "100%", stopColor "lightgreen" ] []
                ]
            ]
        , Svg.path
            [ id "gauge-curve"
            , strokeWidth "20px"
            , stroke "url(#linear)"
            , fill "none"
            , d "M 0 50 C 15 10, 85 10, 100 50"
            ]
            []
        , text_ [ width "100", fill gaugePointerColor, dy "2" ]
            [ textPath
                [ xlinkHref "#gauge-curve"
                , startOffset "20"
                ]
                [ text "Bad - Good" ]
            ]
        , circle
            [ cx "50", cy "75", r "10", fill gaugePointerColor ]
            []
        , polygon
            [ points "40,75 60,75 55,25 45,25"
            , fill gaugePointerColor
            , Svg.Attributes.style <| "transform: rotate(" ++ String.fromFloat ((-0.5 + fraction) * 120) ++ "deg)"

            -- , transform <| "rotate(" ++ String.fromFloat ((1 - fraction * 2) * 60) ++ ",50,75)"
            ]
            []
        , circle
            [ cx "50"
            , cy "25"
            , r "5"
            , fill gaugePointerColor
            , Svg.Attributes.style <| "transform: rotate(" ++ String.fromFloat ((-0.5 + fraction) * 120) ++ "deg)"

            -- transform <| "rotate(" ++ String.fromFloat ((1 - fraction * 2) * 60) ++ ",50,75)" ]
            ]
            []
        ]


gaugePointerColor =
    "#444"
