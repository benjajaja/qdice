module Game.PlayerCard exposing (view)

import Html
import Html.Attributes exposing (class, style)
import Svg
import Svg.Attributes
import Time exposing (inMilliseconds)
import Ordinal exposing (ordinal)
import Material
import Material.Options as Options
import Material.Elevation as Elevation
import Material.Chip as Chip
import Color
import Color.Convert
import Color.Manipulate
import Color.Interpolate
import Color.Accessibility
import Game.Types exposing (Player)
import Types exposing (Model, Msg(..))
import Board.Colors


view : Model -> Int -> Player -> Html.Html Types.Msg
view model index player =
    playerContainer player
        (index == model.game.turnIndex)
        [ playerImageProgress model index player
        , Html.div
            [ class "edPlayerChip__name"
            , style <|
                [ ( "background-color", Board.Colors.baseCssRgb player.color )
                , ( "color"
                  , Color.Accessibility.maximumContrast (Board.Colors.base player.color)
                        [ Color.rgb 0 0 0, Color.rgb 30 30 30, Color.rgb 255 255 255 ]
                        |> Maybe.withDefault (Color.rgb 0 0 0)
                        |> Color.Convert.colorToCssRgb
                  )
                ]
            ]
            [ Html.text player.name ]
        , Html.div [ class "edPlayerChip__gameStats" ]
            [ Html.div [ class "edPlayerChip__gameStats__item" ]
                [ Html.text <| "✪ " ++ toString player.points ]
            , Html.div [ class "edPlayerChip__gameStats__item--strong" ]
                [ Html.text <|
                    (if player.gameStats.position == 2 then
                        "Pole"
                     else
                        ordinal player.gameStats.position
                    )
                ]
            , Html.div [ class "edPlayerChip__gameStats__item" ]
                [ case player.flag of
                    Nothing ->
                        Html.text ""

                    Just pos ->
                        Html.text <| "⚑ " ++ ordinal pos
                ]
            , Html.div [ class "edPlayerChip__gameStats__item" ]
                [ Html.text <| "⬢ " ++ toString player.gameStats.totalLands ]
            , Html.div [ class "edPlayerChip__gameStats__item" ]
                [ Html.text <|
                    ("⚂ "
                        ++ toString player.gameStats.currentDice
                        ++ (if player.reserveDice > 0 then
                                " + " ++ toString player.reserveDice
                            else
                                ""
                           )
                    )
                ]
            , Html.div [ class "edPlayerChip__gameStats__item" ]
                [ Html.text <|
                    (if player.gameStats.score >= 0 then
                        "✪+"
                     else
                        "✪"
                    )
                        ++ toString player.gameStats.score
                ]
            ]
        ]


playerContainer player hasTurn =
    Options.div
        [ Options.cs <|
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
        , if hasTurn then
            Elevation.e6
          else
            Elevation.e2
        ]


playerImageProgress model index player =
    Html.div [ class "edPlayerChip__picture" ]
        [ playerCircleProgress <|
            (if index == model.game.turnIndex then
                1.0 - turnProgress model
             else
                0.0
            )
        , Html.div
            [ class "edPlayerChip__picture__image"
            , style
                [ ( "background-image", ("url(" ++ player.picture ++ ")") )
                , ( "background-size", "cover" )
                ]
            ]
            []
        ]


playerCircleProgress progress =
    let
        x =
            toString <| cos (2 * pi * progress)

        y =
            toString <| sin (2 * pi * progress)

        progressStep =
            toString <|
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
    Color.rgb 0 135 189


midProgressColor =
    Color.rgb 255 211 0


endProgressColor =
    Color.rgb 196 2 51


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
            inMilliseconds model.time / 1000

        turnStarted =
            toFloat model.game.turnStarted
    in
        max 0.0 <|
            min 1 <|
                (turnTime - (timestamp - turnStarted))
                    / turnTime
