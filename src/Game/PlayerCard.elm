module Game.PlayerCard exposing (view)

import Game.Types exposing (Player)
import Html
import Html.Attributes exposing (class, style)
import Svg
import Svg.Attributes
import Time exposing (inMilliseconds)
import Material
import Material.Options as Options
import Material.Elevation as Elevation
import Material.Chip as Chip
import Types exposing (Model, Msg(..))


view : Model -> Int -> Player -> Html.Html Types.Msg
view model index player =
    Options.div
        [ Options.cs ("edPlayerChip edPlayerChip--" ++ (toString player.color))
        , if index == model.game.turnIndex then
            Elevation.e6
          else
            Elevation.e2
        ]
        [ playerImageProgress model index player
        , Html.div [ class "edPlayerChip__name" ] [ Html.text player.name ]
          --, Html.div []
          --[ playerChipProgress model index
          --]
        , Html.div [ class "edPlayerChip__gameStats" ]
            [ Html.span [ class "edPlayerChip__gameStats__item" ]
                [ Html.text <| "⬢ " ++ toString player.gameStats.totalLands ]
            , Html.span [ class "edPlayerChip__gameStats__item" ]
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
            ]
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
            , Svg.Attributes.class <| "edPlayerChip_clock edPlayerChip_clock--" ++ progressStep
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


playerChipProgress model index =
    let
        hasTurn =
            index == model.game.turnIndex

        progress =
            (turnProgress model) * 100

        progressStep =
            floor (progress / 10) * 10
    in
        Html.div
            [ class ("edPlayerChip__progress edPlayerChip__progress--" ++ (toString progressStep))
            , style
                [ ( "width"
                  , (if hasTurn then
                        (toString progress) ++ "%"
                     else
                        "0%"
                    )
                  )
                ]
            ]
            []


turnProgress : Model -> Float
turnProgress model =
    let
        turnTime =
            toFloat model.game.turnDuration

        timestamp =
            inMilliseconds model.time / 1000

        turnStarted =
            toFloat model.game.turnStarted
    in
        max 0.0 <|
            min 1 <|
                (turnTime - (timestamp - turnStarted))
                    / turnTime
