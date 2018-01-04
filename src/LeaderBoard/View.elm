module LeaderBoard.View exposing (..)

import Html exposing (..)
import Material
import Material.Options as Options
import Material.Icon as Icon
import Material.Footer as Footer
import Material.Table as Table
import Types exposing (..)


view : Model -> Html Msg
view model =
    div []
        [ div [] [ Html.text <| "Leaderboard for " ++ model.staticPage.leaderBoard.month ]
        , Table.table []
            [ Table.thead []
                [ Table.tr []
                    [ Table.th [] [ text "Rank" ]
                    , Table.th [ Table.numeric ] [ text "Name" ]
                    , Table.th [ Table.numeric ] [ text "Points" ]
                    ]
                ]
            , Table.tbody [] <|
                List.map
                    (\profile ->
                        Table.tr []
                            [ Table.td [] [ text <| toString profile.rank ]
                            , Table.td [ Table.numeric ] [ text profile.name ]
                            , Table.td [ Table.numeric ] [ text <| toString profile.points ]
                            ]
                    )
                    model.staticPage.leaderBoard.top
            ]
        ]
