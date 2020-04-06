module Profile exposing (view)

import Awards
import Game.PlayerCard exposing (playerPicture)
import Games
import Games.Types exposing (Game)
import Helpers exposing (dataTestId, pointsSymbol, pointsToNextLevel)
import Html exposing (..)
import Html.Attributes exposing (..)
import Ordinal exposing (ordinal)
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
                    , []
                    )
                    model.otherProfile
        ]


playerBox : Zone -> ( Profile, List Game ) -> List (Html Msg)
playerBox zone ( user, games ) =
    [ div [ class "edPlayerBox__Picture" ]
        [ playerPicture "large" user.picture
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
    , div [ class "edPlayerBox__stat" ] [ text "Games: " ]
    , div [ class "edPlayerBox__stat" ] [ ul [] <| List.map (gameLink zone) games ]
    ]


gameLink : Zone -> Game -> Html Msg
gameLink zone game =
    li []
        [ text <| "on table " ++ game.tag ++ ":"
        , Games.gameHeader zone game
        ]



--text <| "#" ++ String.fromInt game.id ++ " in table " ++ game.tag ]
