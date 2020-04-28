module Game.Footer exposing (footer)

import Game.Types exposing (TableInfo, statusToIcon)
import Helpers exposing (dataTestId, formatPoints)
import Html exposing (..)
import Html.Attributes exposing (align, class, style)
import Html.Events exposing (onClick)
import Icon
import Types exposing (Model, Msg(..))



--import Tables exposing (Table, tableList)


footer : Model -> List (Html.Html Types.Msg)
footer model =
    [ div [ class "edTables cartonCard" ] [ tableOfTables model ]
    ]
        ++ (case List.filter (.params >> .tournament >> (/=) Nothing) model.tableList of
                [] ->
                    []

                tournamentTables ->
                    [ div [ class "edTables cartonCard" ] <|
                        [ tableOfTournaments model tournamentTables
                        ]
                    ]
           )


tableOfTables : Model -> Html.Html Types.Msg
tableOfTables model =
    table [ class "edGameTable", style "-webkit-user-select" "none" ]
        [ thead []
            [ tr []
                [ th [ align "left" ] [ text "Tables" ]
                , th [ align "right" ] [ text "Points" ]
                , th [ align "right" ] [ text "Players" ]
                , th [ align "right" ] [ text "Minimum" ]
                , th [ align "right" ] [ text "Watching" ]
                , th [ align "right" ] [ text "Bots" ]
                , th [ align "right" ] [ text "Capitals" ]
                , th [ align "right" ] [ text "Size" ]

                -- , th [ align "right" ] [ text "Stacks" ]
                ]
            ]
        , tbody [] <|
            List.map
                (\table ->
                    tr
                        [ onClick (Types.NavigateTo <| Types.GameRoute table.table)
                        , dataTestId <| "go-to-table-" ++ table.table
                        ]
                        [ td [ align "left" ] [ text <| table.table ]
                        , td [ align "right" ]
                            [ text <|
                                case table.points of
                                    0 ->
                                        "Free"

                                    n ->
                                        formatPoints n
                            ]
                        , td [ align "right" ]
                            [ text <|
                                String.concat
                                    [ String.fromInt table.playerCount
                                    , " / "
                                    , String.fromInt table.playerSlots
                                    ]
                            ]
                        , td [ align "right" ]
                            [ text <|
                                String.fromInt table.startSlots
                            ]
                        , td [ align "right" ] [ text <| String.fromInt table.watchCount ]
                        , td [ align "right" ]
                            [ text <|
                                if table.params.botLess then
                                    "No"

                                else
                                    "Yes"
                            ]
                        , td [ align "right" ]
                            [ text <|
                                if table.params.startingCapitals then
                                    "Yes"

                                else
                                    "No"
                            ]
                        , td [ align "right" ] [ text <| String.fromInt table.landCount ]

                        -- , td [ align "right" ] [ text <| String.fromInt table.stackSize ]
                        ]
                )
            <|
                List.filter
                    (\tableInfo ->
                        not tableInfo.params.twitter
                            && tableInfo.params.tournament
                            == Nothing
                    )
                    model.tableList
        ]


tableOfTournaments : Model -> List TableInfo -> Html.Html Types.Msg
tableOfTournaments model tableList =
    table [ class "edGameTable", style "-webkit-user-select" "none" ]
        [ thead []
            [ tr []
                [ th [ align "left" ] [ text "Prize games" ]
                , th [ align "right" ] [ text "Prize" ]
                , th [ align "right" ] [ text "Fee" ]
                , th [ align "right" ] [ text "Points" ]
                , th [ align "right" ] [ text "Players" ]
                , th [ align "right" ] [ text "Minimum" ]
                , th [ align "right" ] [ text "Watching" ]
                , th [ align "right" ] [ text "Capitals" ]
                , th [ align "right" ] [ text "Size" ]

                -- , th [ align "right" ] [ text "Stacks" ]
                ]
            ]
        , tbody [] <|
            List.map
                (\table ->
                    tr
                        [ onClick (Types.NavigateTo <| Types.GameRoute table.table)
                        , dataTestId <| "go-to-table-" ++ table.table
                        ]
                    <|
                        [ td [ align "left" ] [ text <| table.table ]
                        ]
                            ++ (case table.params.tournament of
                                    Just tournament ->
                                        [ td [ align "right" ] [ text <| formatPoints tournament.prize ]
                                        , td [ align "right" ] [ text <| formatPoints tournament.fee ]
                                        ]

                                    Nothing ->
                                        [ td [ align "right" ] [ text "..." ]
                                        , td [ align "right" ] [ text "..." ]
                                        ]
                               )
                            ++ [ td [ align "right" ] [ text <| formatPoints table.points ]
                               , td [ align "right" ]
                                    [ text <|
                                        String.concat
                                            [ String.fromInt table.playerCount
                                            , " / "
                                            , String.fromInt table.playerSlots
                                            ]
                                    ]
                               , td [ align "right" ]
                                    [ text <|
                                        String.fromInt table.startSlots
                                    ]
                               , td [ align "right" ] [ text <| String.fromInt table.watchCount ]
                               , td [ align "right" ]
                                    [ text <|
                                        if table.params.startingCapitals then
                                            "Yes"

                                        else
                                            "No"
                                    ]
                               , td [ align "right" ] [ text <| String.fromInt table.landCount ]

                               -- , td [ align "right" ] [ text <| String.fromInt table.stackSize ]
                               ]
                )
            <|
                List.filter
                    (\tableInfo ->
                        not tableInfo.params.twitter
                    )
                    tableList
        ]
