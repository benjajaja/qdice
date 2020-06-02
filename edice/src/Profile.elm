module Profile exposing (init, view)

import Array
import Awards
import Comments
import DateFormat
import Game.PlayerCard exposing (playerPicture)
import Games.Types exposing (GameRef)
import Helpers exposing (pointsSymbol, pointsToNextLevel, toDie)
import Html exposing (..)
import Html.Attributes exposing (..)
import Icon
import Ordinal exposing (ordinal)
import Placeholder exposing (Placeheld(..))
import Routing.String exposing (routeToString)
import Svg
import Svg.Attributes
import Time exposing (Zone)
import Types exposing (..)
import Widgets.Charts exposing (chart, gauge)


init : Placeheld OtherProfile
init =
    let
        profile : Profile
        profile =
            { id = "0"
            , name = "..."
            , points = 0
            , rank = 0
            , level = 0
            , levelPoints = 0
            , awards = []
            , picture = "assets/empty_profile_picture.svg"
            , registered = True
            }

        stats : ProfileStats
        stats =
            { games = []
            , gamesWon = 0
            , gamesPlayed = 0
            , stats =
                { rolls = Array.fromList [ 0, 0, 0, 0, 0, 0 ]
                , attacks = ( 0, 0 )
                , kills = 0
                , eliminations = Array.fromList [ 0, 0, 0, 0, 0, 0, 0, 0, 0 ]
                , luck = ( 0, 0 )
                }
            }
    in
    Placeholder
        ( profile
        , stats
        )


view : Model -> UserId -> String -> Html Msg
view model id name =
    div [ class "" ] <|
        [ div [ class "edPlayerBox__inner" ] <|
            playerBox model.zone <|
                Placeholder.updateIfPlaceholder
                    (\( profile, stats ) ->
                        ( { profile | id = id, name = name }, stats )
                    )
                    model.otherProfile
        ]
            ++ (case model.otherProfile of
                    Fetched ( p, _ ) ->
                        [ Comments.view model.zone model.user model.comments <| Comments.profileComments p ]

                    _ ->
                        []
               )


playerBox : Zone -> Placeheld OtherProfile -> List (Html Msg)
playerBox zone placeholder =
    case Placeholder.toResult placeholder of
        Ok ( user, stats ) ->
            [ div [ class "edPlayerBox__Picture" ]
                [ playerPicture "large" user.picture user.name ]
            , div [ class "edPlayerBox__Name" ] <|
                case placeholder of
                    Fetching ( a, _ ) ->
                        [ Icon.spinner, text a.name ]

                    Placeholder ( a, _ ) ->
                        [ Icon.spinner, text <| a.name ]

                    Error err ( a, _ ) ->
                        [ text <| "Error loading profile of " ++ a.name ++ ": " ++ err ]

                    Fetched ( a, _ ) ->
                        [ text a.name ]
            , div [ class "edPlayerBox__stat" ] [ text "Level: ", text <| String.fromInt user.level ++ "▲" ]
            , if List.length user.awards > 0 then
                div [ class "edPlayerBox__awards" ] [ text "Awards: ", div [] <| Awards.awardsShortList 30 user.awards ]

              else
                text ""
            , div [ class "edPlayerBox__stat" ] [ text "Points: ", text <| String.fromInt user.points ++ pointsSymbol ]
            , div [ class "edPlayerBox__stat" ]
                [ text <| (String.fromInt <| pointsToNextLevel user.level user.levelPoints) ++ pointsSymbol
                , text " points to next level"
                ]
            , div [ class "edPlayerBox__stat" ]
                [ text "Monthly rank: "
                , text <|
                    ordinal user.rank
                ]
            , div [ class "edPlayerBox__stat" ]
                [ text <|
                    "Registered: "
                        ++ (case Placeholder.toMaybe placeholder of
                                Just ( p, _ ) ->
                                    if p.registered then
                                        "Yes"

                                    else
                                        "No"

                                Nothing ->
                                    "..."
                           )
                ]
            , div [ class "edPlayerBox__stat" ] [ text " " ]
            , div [ class "edPlayerBox__stat" ]
                [ h3 [] [ text "Statistics" ]
                , div [ class "edPlayerBox__stat" ] [ text <| "Games won: " ++ String.fromInt stats.gamesWon ]
                , div [ class "edPlayerBox__stat" ] [ text <| "Games played: " ++ String.fromInt stats.gamesPlayed ]
                , div [] <| statisticsView (Placeholder.isFetched placeholder) user stats
                ]
            , div [ class "edPlayerBox__stat" ]
                [ h3 [] [ text "Last 10 Games: " ]
                , div [ class "edPlayerBox__games" ]
                    [ ul [] <|
                        case placeholder of
                            Fetched _ ->
                                List.map (gameLink zone) stats.games

                            _ ->
                                List.map (always <| li [] [ p [] [ text "..." ] ]) <| List.range 0 9
                    ]
                ]
            ]

        Err err ->
            [ div [] [ text err ] ]


gameLink : Zone -> GameRef -> Html Msg
gameLink zone game =
    li []
        [ gameHeader zone game
        , text <| "on table "
        , a
            [ href <| routeToString False <| GameRoute game.tag
            ]
            [ text <| game.tag ]
        ]


gameHeader : Zone -> GameRef -> Html Msg
gameHeader zone game =
    div []
        [ a
            [ href <| routeToString False <| GamesRoute <| GameId game.tag game.id
            ]
            [ text <| "#" ++ String.fromInt game.id ]
        , text " "
        , span [] [ text <| DateFormat.format "dddd, dd MMMM yyyy HH:mm:ss" zone game.gameStart ]
        ]


statisticsView : Bool -> Profile -> ProfileStats -> List (Html Msg)
statisticsView isFetched profile { stats } =
    let
        { rolls, attacks, eliminations, kills, luck } =
            stats

        ( attacksSucceeded, attacksFailed ) =
            attacks

        attacksTotal =
            attacksSucceeded + attacksFailed

        ( luckGood, luckBad ) =
            luck

        luckFraction =
            if luckGood > luckBad then
                1.0
                    - (toFloat luckBad
                        / toFloat luckGood
                        / 2
                      )

            else if luckGood < luckBad then
                toFloat luckGood
                    / toFloat luckBad
                    / 2

            else
                0.5
    in
    [ div []
        [ text <|
            String.fromInt attacksTotal
                ++ " attacks ("
                ++ String.fromInt attacksSucceeded
                ++ " successful / "
                ++ String.fromInt attacksFailed
                ++ " failed, ratio "
                ++ (String.fromFloat <| toFloat attacksSucceeded / toFloat attacksFailed)
                ++ ")"
        ]
    , div []
        [ div [] [ text <| "Kills: " ++ String.fromInt kills ]
        ]
    , p [] []
    , div []
        [ div [] [ text "Positions:" ]
        , chart
            isFetched
            8
            (\i ->
                Svg.text_
                    [ Svg.Attributes.x "0"
                    , Svg.Attributes.y <| String.fromFloat (toFloat i * 10 + 7.5)
                    , Svg.Attributes.fontSize "8"
                    ]
                    [ Svg.text <| ordinal <| i + 1 ]
            )
            16
            eliminations
        ]
    , p [] []
    , div []
        [ div [] [ text <| "Lucky rolls: " ++ String.fromInt luckGood ++ " lucky / " ++ String.fromInt luckBad ++ " unlucky" ]
        , gauge <|
            if isNaN luckFraction then
                0.5

            else
                luckFraction
        ]
    , p [] []
    , div []
        [ div [] [ text "Dice rolls:" ]
        , chart
            isFetched
            6
            (\i ->
                Svg.text_
                    [ Svg.Attributes.x "0"
                    , Svg.Attributes.y <| String.fromFloat (toFloat i * 10 + 7.5)
                    , Svg.Attributes.fontSize "10"
                    ]
                    [ Svg.text <| toDie <| i + 1 ]
            )
            10
            rolls
        ]
    ]
