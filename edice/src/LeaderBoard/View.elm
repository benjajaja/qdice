module LeaderBoard.View exposing (view)

import Html exposing (..)
import Html.Attributes exposing (align, href)
import Types exposing (..)


view : Int -> Model -> Html Msg
view limit model =
    div []
        [ div []
            [ a
                [ href "/leaderboard"
                ]
                [ text "Leaderboard" ]
            , text <| " for " ++ model.leaderBoard.month
            ]
        , table []
            [ thead []
                [ tr []
                    [ th [] [ text "Rank" ]
                    , th [ align "right" ] [ text "Name" ]
                    , th [ align "right" ] [ text "Points" ]
                    ]
                ]
            , model.leaderBoard.top
                |> List.take limit
                |> List.map
                    (\profile ->
                        tr []
                            [ td [] [ text <| String.fromInt profile.rank ]
                            , td [ align "right" ] [ text profile.name ]
                            , td [ align "right" ] [ text <| String.fromInt profile.points ]
                            ]
                    )
                |> tbody []
            ]
        ]
