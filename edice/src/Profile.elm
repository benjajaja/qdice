module Profile exposing (init, view)

import Array
import Awards
import Backend exposing (toDie)
import Comments
import DateFormat
import Game.PlayerCard exposing (playerPicture)
import Games.Types exposing (GameRef)
import Helpers exposing (dataTestId, flip, pointsSymbol, pointsToNextLevel)
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
            }

        stats : ProfileStats
        stats =
            { games = []
            , gamesWon = 0
            , gamesPlayed = 0
            , stats =
                { rolls = Array.fromList [ 0, 0, 0, 0, 0, 0 ]
                , attacks = ( 0, 0 )
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
                div [ class "edPlayerBox__awards" ] <| Awards.awardsShortList 20 user.awards

              else
                text ""
            , div [ class "edPlayerBox__stat" ] [ text "Points: ", text <| String.fromInt user.points ++ pointsSymbol ]
            , div [ class "edPlayerBox__stat" ]
                [ text <| (String.fromInt <| pointsToNextLevel user.level user.levelPoints) ++ pointsSymbol
                , text " points to next level"
                ]
            , div [ class "edPlayerBox__stat" ] [ text "Monthly rank: ", text <| ordinal user.rank ]
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
        { rolls, attacks } =
            stats

        ( attacksSucceeded, attacksFailed ) =
            attacks

        attacksTotal =
            attacksSucceeded + attacksFailed
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
    , p [] []
    , rollsGraph isFetched rolls
    ]


rollsGraph : Bool -> Array.Array Int -> Html Msg
rollsGraph isFetched rolls =
    let
        list =
            rolls |> rollsAsList

        max =
            List.maximum list |> Maybe.withDefault 100
    in
    div []
        [ div [] [ text "Dice rolls:" ]
        , List.indexedMap
            (\i _ ->
                Svg.text_
                    [ Svg.Attributes.x "0"
                    , Svg.Attributes.y <| String.fromFloat (toFloat i * 10 + 7.5)
                    , Svg.Attributes.fontSize "10"
                    ]
                    [ Svg.text <| toDie <| i + 1 ]
            )
            list
            |> List.append
                (List.indexedMap
                    (\i dice ->
                        Svg.text_
                            [ Svg.Attributes.x "11"
                            , Svg.Attributes.y <| String.fromFloat (toFloat i * 10 + 6.5)
                            , Svg.Attributes.fontSize "8"
                            , Svg.Attributes.fill "#ffffff"
                            ]
                            [ Svg.text <| String.fromInt dice ]
                    )
                    list
                )
            |> List.append
                (List.indexedMap
                    (\i dice ->
                        Svg.rect
                            [ Svg.Attributes.x "10"
                            , Svg.Attributes.y <| String.fromFloat (toFloat i * 10 + 0.25)
                            , Svg.Attributes.height <| String.fromFloat 7.5
                            , Svg.Attributes.width <|
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
                            , Svg.Attributes.fill <|
                                if isFetched then
                                    "#519ab1"

                                else
                                    "#888888"
                            , Svg.Attributes.opacity <|
                                if isFetched then
                                    "1"

                                else
                                    "0.5"
                            ]
                            []
                    )
                    list
                )
            |> Svg.svg [ Svg.Attributes.viewBox "0 0 200 60", Svg.Attributes.class "edStatistics__rolls" ]
        ]


rollsAsList : Array.Array Int -> List Int
rollsAsList rolls =
    List.range 0 5
        |> List.map
            (flip Array.get rolls
                >> Maybe.withDefault 0
            )
