module Profile exposing (view)

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
import Ordinal exposing (ordinal)
import Routing.String exposing (routeToString)
import Svg
import Svg.Attributes
import Time exposing (Zone)
import Types exposing (..)


emptyProfile : String -> Profile
emptyProfile name =
    { id = "0"
    , name = name
    , points = 0
    , rank = 0
    , level = 0
    , levelPoints = 0
    , awards = []
    , picture = "assets/empty_profile_picture.svg"
    }


view : Model -> UserId -> String -> Html Msg
view model id name =
    div [ class "" ] <|
        [ div [ class "edPlayerBox__inner" ] <|
            playerBox model.zone <|
                Maybe.withDefault
                    ( emptyProfile name
                    , { games = []
                      , gamesWon = 0
                      , gamesPlayed = 0
                      , stats =
                            { rolls = Nothing
                            }
                      }
                    )
                    model.otherProfile
        ]
            ++ (case model.otherProfile of
                    Just ( p, _ ) ->
                        [ Comments.view model.zone model.user model.comments <| Comments.profileComments p ]

                    Nothing ->
                        []
               )


playerBox : Zone -> OtherProfile -> List (Html Msg)
playerBox zone ( user, stats ) =
    [ div [ class "edPlayerBox__Picture" ]
        [ playerPicture "large" user.picture user.name
        ]
    , div [ class "edPlayerBox__Name" ]
        [ text user.name
        ]
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
    , div [ class "edPlayerBox__stat" ] [ text <| "Games won: " ++ String.fromInt stats.gamesWon ]
    , div [ class "edPlayerBox__stat" ] [ text <| "Games played: " ++ String.fromInt stats.gamesPlayed ]
    , div [ class "edPlayerBox__stat" ]
        [ h3 [] [ text "Statistics" ]
        , div [] <| statisticsView user stats
        ]
    , div [ class "edPlayerBox__stat" ]
        [ h3 [] [ text "Last 10 Games: " ]
        , div [ class "edPlayerBox__games" ] [ ul [] <| List.map (gameLink zone) stats.games ]
        ]
    ]


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


statisticsView : Profile -> ProfileStats -> List (Html Msg)
statisticsView profile stats =
    [ rollsGraph stats
    ]


rollsGraph : ProfileStats -> Html Msg
rollsGraph stats =
    let
        list =
            stats.stats.rolls |> rollsAsList

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
                            , Svg.Attributes.fill "#519ab1"
                            ]
                            []
                    )
                    list
                )
            |> Svg.svg [ Svg.Attributes.viewBox "0 0 200 60", Svg.Attributes.class "edStatistics__rolls" ]
        ]


rollsAsList : Maybe (Array.Array Int) -> List Int
rollsAsList rolls =
    List.range 0 5
        |> List.map
            (flip Array.get (Maybe.withDefault Array.empty rolls)
                >> Maybe.withDefault 0
            )
