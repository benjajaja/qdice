module Game.PlayerCard exposing (TurnPlayer, playerPicture, turnProgress, view)

import Awards
import Board.Colors
import Color
import Color.Accessibility
import Color.Interpolate
import Game.Types exposing (GameStatus(..), Player)
import Helpers exposing (dataTestId, pointsSymbol)
import Html exposing (..)
import Html.Attributes exposing (alt, class, href, src, style)
import Html.Lazy
import Ordinal exposing (ordinal)
import Routing.String exposing (routeToString)
import Svg
import Svg.Attributes
import Time exposing (Posix, posixToMillis)
import Types exposing (Msg(..), Route(..))


type alias TurnPlayer =
    { player : Maybe Player
    , index : Int
    , turn : Maybe Float
    , isUser : Bool
    }


view : GameStatus -> TurnPlayer -> Html.Html Types.Msg
view status { player, index, turn, isUser } =
    let
        hasTurn =
            turn /= Nothing
    in
    case player of
        Just p ->
            playerContainer p
                hasTurn
                isUser
                [ playerImageProgress turn p
                , Html.Lazy.lazy3 playerInfo p status index
                , Html.div
                    [ class "edPlayerChip__picture__bar"
                    , style "width" <|
                        (case turn of
                            Just progress ->
                                (1.0 - progress)
                                    * 100
                                    |> round
                                    |> String.fromInt

                            Nothing ->
                                "0"
                        )
                            ++ "%"
                    , style "background-color" <|
                        progressColor <|
                            case turn of
                                Just progress ->
                                    1.0 - progress

                                Nothing ->
                                    0.0
                    ]
                    []
                ]

        Nothing ->
            div [ class "edPlayerChip edPlayerChip--empty" ] []


playerInfo : Player -> GameStatus -> Int -> Html Msg
playerInfo player status index =
    div [ class "edPlayerChip__info" ]
        [ a
            [ class "edPlayerChip__name"
            , href <| routeToString False <| ProfileRoute player.id player.name
            , dataTestId <| "player-name-" ++ String.fromInt index
            , style "background-color" <| Board.Colors.baseCssRgb player.color
            , style "color" <|
                (Color.Accessibility.maximumContrast (Board.Colors.base player.color)
                    [ Color.rgb255 0 0 0, Color.rgb255 30 30 30, Color.rgb255 255 255 255 ]
                    |> Maybe.withDefault (Color.rgb255 0 0 0)
                    |> Board.Colors.cssRgb
                )
            ]
            [ text player.name ]
        , div
            [ class "edPlayerChip__playerStats"
            , style "background-color" <| Board.Colors.baseCssRgb player.color
            , style "color" <|
                (Color.Accessibility.maximumContrast (Board.Colors.base player.color)
                    [ Color.rgb255 0 0 0, Color.rgb255 30 30 30, Color.rgb255 255 255 255 ]
                    |> Maybe.withDefault (Color.rgb255 0 0 0)
                    |> Board.Colors.cssRgb
                )
            ]
          <|
            playerStats player
        , div [ class "edPlayerChip__gameStats" ] <|
            gameStats
                status
                player
        ]


gameStats : GameStatus -> Player -> List (Html Msg)
gameStats status player =
    if status == Paused then
        [ Html.div [ class "edPlayerChip__gameStats__item--strong" ] <|
            if player.ready then
                [ Html.text "✔ Ready" ]

            else
                [ Html.text "⌛ Waiting for others" ]
        ]

    else
        List.concat
            [ [ Html.div [ class "edPlayerChip__gameStats__item--strong" ]
                    [ Html.text <|
                        if player.gameStats.position == 2 then
                            "Pole"

                        else
                            ordinal player.gameStats.position
                    ]
              ]
            , case player.flag of
                Just flag ->
                    [ Html.div [ class "edPlayerChip__gameStats__item--strong" ]
                        [ Html.text <| "🏳 " ++ ordinal flag ]
                    ]

                Nothing ->
                    []
            , [ Html.div [ class "edPlayerChip__gameStats__item edPlayerChip__gameStats__item--lands" ]
                    [ Html.text <| "⬢ " ++ String.fromInt player.gameStats.totalLands ]
              , Html.div [ class "edPlayerChip__gameStats__item edPlayerChip__gameStats__item--dice" ]
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
              , Html.div [ class "edPlayerChip__gameStats__item" ]
                    [ Html.text <| String.fromInt player.gameStats.score ++ pointsSymbol
                    ]
              ]
            ]


playerStats : Player -> List (Html Msg)
playerStats player =
    [ Html.div [ class "edPlayerChip__gameStats__item" ]
        [ Html.text <| String.fromInt player.level ++ "▲"
        ]
    , Html.div [ class "edPlayerChip__gameStats__item" ]
        [ Html.text <| String.fromInt player.points ++ pointsSymbol
        ]
    ]
        ++ Awards.awardsShortList 10 player.awards


playerContainer : Player -> Bool -> Bool -> List (Html Msg) -> Html Msg
playerContainer player hasTurn isUser =
    div
        [ class <|
            String.join " " <|
                List.concat
                    [ [ "edPlayerChip" ]
                    , if player.out then
                        [ "edPlayerChip--out" ]

                      else if player.flag /= Nothing then
                        [ "edPlayerChip--flag" ]

                      else
                        []
                    , if hasTurn then
                        [ "edPlayerChip--turn" ]

                      else
                        []
                    , if isUser then
                        [ "edPlayerChip--me" ]

                      else
                        []
                    ]
        ]


playerImageProgress progress player =
    Html.div [ class "edPlayerChip__picture" ]
        [ Maybe.map ((-) 1.0) progress
            |> Maybe.withDefault 0.0
            |> playerCircleProgress
        , Html.Lazy.lazy playerPictureHtml player.picture
        ]


playerPictureHtml : String -> Html msg
playerPictureHtml url =
    Html.div
        [ class "edPlayerChip__picture__image"
        , style "background-image" ("url('" ++ url ++ "')")
        , style "background-size" "cover"
        ]
        []


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
        |> Board.Colors.cssRgb


turnProgress : Float -> Posix -> Int -> Float
turnProgress turnTime time turnStart =
    let
        timestamp =
            (posixToMillis time |> toFloat) / 1000
    in
    max 0.0 <|
        min 1 <|
            (turnTime - (timestamp - toFloat turnStart))
                / turnTime


playerPicture : String -> String -> String -> Html Msg
playerPicture size picture name =
    Html.img
        [ class <| "edPlayerPicture edPlayerPicture--" ++ size
        , alt <| "Avatar: " ++ name
        , src picture
        ]
        []
