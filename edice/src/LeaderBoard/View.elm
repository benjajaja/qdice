module LeaderBoard.View exposing (table, view)

import Game.PlayerCard exposing (playerPicture)
import Helpers exposing (pointsSymbol)
import Html exposing (..)
import Html.Attributes exposing (align, class, disabled, href)
import Html.Events exposing (onClick)
import Routing exposing (routeToString)
import Types exposing (..)


view : Model -> Html Msg
view model =
    div []
        [ div
            [ class <|
                if model.leaderBoard.loading then
                    "overlay-loading"

                else
                    "overlay-loaded"
            ]
            [ table 100 model.leaderBoard.board ]
        , div [] <| pageButtons model
        ]


pageButtons : Model -> List (Html Msg)
pageButtons model =
    [ button
        [ onClick <| Types.LeaderboardMsg <| GotoPage <| model.leaderBoard.page - 1
        , disabled <| model.leaderBoard.page <= 1
        ]
        [ text "<" ]
    , span [ class "edButton" ] [ text <| "Page " ++ String.fromInt model.leaderBoard.page ]
    , button
        [ onClick <| Types.LeaderboardMsg <| GotoPage <| model.leaderBoard.page + 1
        , disabled <| List.length model.leaderBoard.board < 100
        ]
        [ text ">" ]
    ]


table : Int -> List Profile -> Html Msg
table limit list =
    div [ class "edLeaderboard" ]
        [ Html.table []
            [ thead []
                [ tr []
                    [ th [ align "right" ] [ text "Rank" ]
                    , th [ align "right" ] []
                    , th [ align "left" ] [ text "Name" ]
                    , th [ align "right" ] [ text "Points" ]
                    , th [ align "right" ] [ text "Level" ]
                    ]
                ]
            , list
                |> List.take limit
                |> List.map
                    (\profile ->
                        tr []
                            [ td [ align "right" ] [ text <| String.fromInt profile.rank ]
                            , td [ align "right" ]
                                [ playerPicture "small" profile.picture profile.name
                                ]
                            , td [ align "left" ]
                                [ a [ href <| routeToString False <| ProfileRoute profile.id profile.name ]
                                    [ text profile.name
                                    ]
                                ]
                            , td [ align "right" ] [ text <| String.fromInt profile.points ++ pointsSymbol ]
                            , td [ align "right" ] [ text <| String.fromInt profile.level ]
                            ]
                    )
                |> tbody []
            ]
        ]
