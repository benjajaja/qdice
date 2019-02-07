module Game.PlayerCard exposing (view)

import Board.Colors
import Color
import Color.Accessibility
import Color.Convert
import Color.Interpolate
import Color.Manipulate
import Game.Types exposing (Player)
import Html exposing (..)
import Html.Attributes exposing (class, style)
import Ordinal exposing (ordinal)
import Svg
import Svg.Attributes
import Time exposing (posixToMillis)
import Types exposing (Model, Msg(..))


view : Model -> Int -> Player -> Html.Html Types.Msg
view model index player =
    playerContainer player
        (index == model.game.turnIndex)
        [ playerImageProgress model index player
        , div [ class "edPlayerChip__info" ]
            [ div
                [ class "edPlayerChip__name"
                , style "background-color" <| Board.Colors.baseCssRgb player.color
                , style "color" <|
                    (Color.Accessibility.maximumContrast (Board.Colors.base player.color)
                        [ Color.rgb255 0 0 0, Color.rgb255 30 30 30, Color.rgb255 255 255 255 ]
                        |> Maybe.withDefault (Color.rgb255 0 0 0)
                        |> Color.Convert.colorToCssRgb
                    )
                ]
                [ text player.name ]
            , div [ class "edPlayerChip__gameStats" ]
                [ Html.div [ class "edPlayerChip__gameStats__item--strong" ]
                    [ Html.text <|
                        if player.gameStats.position == 2 then
                            "Pole"
                        else
                            ordinal player.gameStats.position
                    ]
                , Html.div [ class "edPlayerChip__gameStats__item" ]
                    [ Html.text <| "⬢ " ++ String.fromInt player.gameStats.totalLands ]
                , Html.div [ class "edPlayerChip__gameStats__item" ]
                    [ Html.text <|
                        ("⚂ "
                            ++ String.fromInt player.gameStats.currentDice
                            ++ (if player.reserveDice > 0 then
                                    " + " ++ String.fromInt player.reserveDice
                                else
                                    ""
                               )
                        )
                    ]
                ]
            ]
        ]



--[ Html.div [ class "edPlayerChip__gameStats__item" ]
--[ Html.text <| "✪ " ++ String.fromInt player.points ]
--, Html.div [ class "edPlayerChip__gameStats__item" ]
--[ Html.text <|
--(if player.gameStats.score >= 0 then
--"✪+"
--else
--"✪"
--)
--++ String.fromInt player.gameStats.score
--]
--]


playerContainer player hasTurn =
    div
        [ class <|
            String.join " " <|
                List.concat
                    [ [ "edPlayerChip" ]
                    , if player.out then
                        [ "edPlayerChip--out" ]
                      else
                        []
                    , if hasTurn then
                        [ "edPlayerChip--turn" ]
                      else
                        []
                    ]
          --, if hasTurn then
          --Elevation.z6
          --else
          --Elevation.z2
        ]


playerImageProgress model index player =
    Html.div [ class "edPlayerChip__picture" ]
        [ playerCircleProgress <|
            if index == model.game.turnIndex then
                1.0 - turnProgress model
            else
                0.0
        , Html.div
            [ class "edPlayerChip__picture__image"
            , style "background-image" ("url(" ++ player.picture ++ ")")
            , style "background-size" "cover"
            ]
            []
        ]


playerCircleProgress progress =
    let
        x =
            String.fromFloat <| cos (2 * pi * progress)

        y =
            String.fromFloat <| sin (2 * pi * progress)

        progressStep =
            String.fromInt <|
                floor (progress * 100 / 20)
                    * 20
    in
        Svg.svg
            [ Svg.Attributes.viewBox "-1 -1 2 2"
            , Svg.Attributes.style "transform: rotate(-0.25turn)"
            , Svg.Attributes.class "edPlayerChip_clock"
            , Svg.Attributes.fill <| progressColor progress
            ]
            [ Svg.path
                [ Svg.Attributes.d
                    ("M 1 0"
                        ++ " A 1 1 0 "
                        ++ (if progress > 0.5 then
                                "1"
                            else
                                "0"
                           )
                        ++ " 1 "
                        ++ x
                        ++ " "
                        ++ y
                        ++ " L 0 0"
                    )
                ]
                []
            ]


baseProgressColor =
    Color.rgb255 0 135 189


midProgressColor =
    Color.rgb255 255 211 0


endProgressColor =
    Color.rgb255 196 2 51


progressColor : Float -> String
progressColor progress =
    (if progress < 0.5 then
        baseProgressColor
     else if progress < 0.75 then
        Color.Interpolate.interpolate Color.Interpolate.RGB
            baseProgressColor
            midProgressColor
        <|
            (progress - 0.5)
                / 0.25
     else
        Color.Interpolate.interpolate Color.Interpolate.LAB
            midProgressColor
            endProgressColor
        <|
            (progress - 0.75)
                / 0.25
    )
        |> Color.Convert.colorToCssRgb


turnProgress : Model -> Float
turnProgress model =
    let
        turnTime =
            toFloat model.settings.turnSeconds

        timestamp =
            (posixToMillis model.time |> toFloat) / 1000

        turnStart =
            toFloat model.game.turnStart
    in
        max 0.0 <|
            min 1 <|
                (turnTime - (timestamp - turnStart))
                    / turnTime
