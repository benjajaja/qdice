module LeaderBoard.View exposing (view)

import Html exposing (..)
import Html.Attributes exposing (align)
import Types exposing (..)


view : Model -> Html Msg
view model =
    div []
        [ div [] [ Html.text <| "Leaderboard for " ++ model.staticPage.leaderBoard.month ]
        , table []
            [ thead []
                [ tr []
                    [ th [] [ text "Rank" ]
                    , th [ align "right" ] [ text "Name" ]
                    , th [ align "right" ] [ text "Points" ]
                    ]
                ]
            , tbody [] <|
                List.map
                    (\profile ->
                        tr []
                            [ td [] [ text <| String.fromInt profile.rank ]
                            , td [ align "right" ] [ text profile.name ]
                            , td [ align "right" ] [ text <| String.fromInt profile.points ]
                            ]
                    )
                    model.staticPage.leaderBoard.top
            ]
        ]
