module Profile exposing (view)

import Awards
import DateFormat
import Game.PlayerCard exposing (playerPicture)
import Games.Types exposing (GameRef)
import Helpers exposing (dataTestId, pointsSymbol, pointsToNextLevel)
import Html exposing (..)
import Html.Attributes exposing (..)
import Ordinal exposing (ordinal)
import Routing exposing (routeToString)
import Time exposing (Zone)
import Types exposing (..)


view : Model -> UserId -> String -> Html Msg
view model id name =
    div [ class "" ]
        [ div [ class "edPlayerBox__inner" ] <|
            playerBox model.zone <|
                Maybe.withDefault
                    ( { id = "0"
                      , name = name
                      , points = 0
                      , rank = 0
                      , level = 0
                      , levelPoints = 0
                      , awards = []
                      , picture = "assets/empty_profile_picture.svg"
                      }
                    , { games = [], gamesWon = 0, gamesPlayed = 0 }
                    )
                    model.otherProfile
        ]


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
    , div [ class "edPlayerBox__stat" ] [ text <| "Games won: " ++ String.fromInt stats.gamesWon ]
    , div [ class "edPlayerBox__stat" ] [ text <| "Games played: " ++ String.fromInt stats.gamesPlayed ]
    , div [ class "edPlayerBox__stat" ] [ text "Games: " ]
    , div [ class "edPlayerBox__stat" ] [ ul [] <| List.map (gameLink zone) stats.games ]
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



--text <| "#" ++ String.fromInt game.id ++ " in table " ++ game.tag ]
