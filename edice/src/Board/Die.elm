module Board.Die exposing (diceDefs, rollDie, shadow, skinId)

import Html.Lazy
import Land exposing (DiceSkin(..))
import Svg exposing (..)
import Svg.Attributes exposing (..)


shadow : Int -> Float -> Float -> Svg msg
shadow points x_ y_ =
    if points == 0 then
        Svg.g [] []

    else
        let
            x__ =
                if points > 4 then
                    x_ + 0.9

                else
                    x_ - 0.3

            y__ =
                if points > 4 then
                    y_ + 0.6

                else
                    y_ - 0.3
        in
        Svg.use
            [ x <| String.fromFloat x__
            , y <| String.fromFloat y__
            , xlinkHref <|
                if points > 4 then
                    "#shadow-double"

                else
                    "#shadow"
            ]
            []


rollDie : Int -> Svg msg
rollDie =
    Html.Lazy.lazy rollDie_


rollDie_ : Int -> Svg msg
rollDie_ i =
    svg [ viewBox "0 0 10 10", class "edDie" ] <|
        [ rect
            [ x "0.5"
            , y "0.5"
            , width "9"
            , height "9"
            , rx "1.5"
            , fill "white"
            , strokeWidth "0.75"
            , stroke "#333"
            ]
            []
        , circle [ cx "5", cy "5", r "1", displayIf 1 i ] []
        , circle [ cx "3", cy "7", r "1", displayIf 2 i ] []
        , circle [ cx "7", cy "3", r "1", displayIf 2 i ] []
        , circle [ cx "3", cy "3", r "1", displayIf 3 i ] []
        , circle [ cx "5", cy "5", r "1", displayIf 3 i ] []
        , circle [ cx "7", cy "7", r "1", displayIf 3 i ] []
        , circle [ cx "3", cy "3", r "1", displayIf 4 i ] []
        , circle [ cx "3", cy "7", r "1", displayIf 4 i ] []
        , circle [ cx "7", cy "3", r "1", displayIf 4 i ] []
        , circle [ cx "7", cy "7", r "1", displayIf 4 i ] []
        , circle [ cx "3", cy "3", r "1", displayIf 5 i ] []
        , circle [ cx "3", cy "7", r "1", displayIf 5 i ] []
        , circle [ cx "5", cy "5", r "1", displayIf 5 i ] []
        , circle [ cx "7", cy "3", r "1", displayIf 5 i ] []
        , circle [ cx "7", cy "7", r "1", displayIf 5 i ] []
        , circle [ cx "3", cy "3", r "1", displayIf 6 i ] []
        , circle [ cx "3", cy "5", r "1", displayIf 6 i ] []
        , circle [ cx "3", cy "7", r "1", displayIf 6 i ] []
        , circle [ cx "7", cy "3", r "1", displayIf 6 i ] []
        , circle [ cx "7", cy "5", r "1", displayIf 6 i ] []
        , circle [ cx "7", cy "7", r "1", displayIf 6 i ] []
        ]


displayIf : Int -> Int -> Svg.Attribute msg
displayIf iif i =
    display <|
        if iif == i then
            "block"

        else
            "none"


diceDefs : Svg msg
diceDefs =
    defs []
        [ Svg.image
            [ xlinkHref "assets/die_shadow.svg"
            , id "die_shadow"
            , transform "scale(0.031)"
            ]
            []
        , Svg.path
            [ id "shadow"
            , transform "scale(0.5)"
            , stroke "black"
            , fill "black"
            , strokeWidth "2"
            , strokeLinejoin "round"
            , opacity "0.3"
            , d "M 0,0 1,0 2,1 1,2 -0.4,2 -1,1 Z"
            ]
            []
        , Svg.path
            [ id "shadow-double"
            , transform "scale(0.5)"
            , stroke "black"
            , fill "black"
            , strokeWidth "2"
            , strokeLinejoin "round"
            , opacity "0.3"
            , d "M -2,-2 1,0 2,1 1,2 -0.4,2 -3,0 -3,-1 Z"
            ]
            []
        , Svg.image
            [ xlinkHref "assets/die.svg"
            , id <| skinId Normal
            , transform "scale(0.031)"
            ]
            []
        , Svg.image
            [ xlinkHref "assets/die_fat_one.svg"
            , id <| skinId FatOne
            , transform "scale(0.031)"
            ]
            []
        , Svg.image
            [ xlinkHref "assets/die_q.svg"
            , id <| skinId Bot
            , transform "scale(0.031)"
            ]
            []
        , Svg.image
            [ xlinkHref "assets/die_king.svg"
            , id <| skinId King
            , transform "scale(0.031)"
            ]
            []
        ]


skinId : DiceSkin -> String
skinId skin =
    "die_skin_" ++ String.fromInt (Land.skinId skin)
