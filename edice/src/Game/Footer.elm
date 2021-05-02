module Game.Footer exposing (footer)

import Game.Types exposing (TableInfo)
import Helpers exposing (dataTestId, formatPoints)
import Html exposing (..)
import Html.Attributes exposing (align, class, style)
import Html.Events exposing (onClick)
import Html.Keyed
import Html.Lazy
import Time exposing (Posix, Zone)
import Tournaments exposing (tournamentTime)
import Types exposing (Model, Msg(..))


footer : Model -> List (Html.Html Types.Msg)
footer model =
    [ div [ class "edTables cartonCard" ] [ Html.Lazy.lazy tableOfTables model.tableList ]
    , div [ class "edTables cartonCard" ] <|
        [ Html.Lazy.lazy3 tableOfTournaments model.zone model.time model.tableList
        ]
    ]


tableOfTables : List TableInfo -> Html.Html Types.Msg
tableOfTables tableList =
    table [ class "edGameTable", style "-webkit-user-select" "none" ]
        [ thead []
            [ tr []
                [ th [ align "left" ] [ text "Tables" ]
                , th [ align "right" ] [ text "Points" ]
                , th [ align "right" ] [ text "Players" ]
                , th [ align "right" ] [ text "Minimum" ]
                , th [ align "right" ] [ text "Bots" ]
                , th [ align "right" ] [ text "Capitals" ]
                , th [ align "right" ] [ text "Size" ]

                -- , th [ align "right" ] [ text "Stacks" ]
                ]
            ]
        , Html.Keyed.node "tbody" [] <|
            List.map
                (\table ->
                    ( table.table
                    , tr
                        [ onClick (Types.NavigateTo <| Types.GameRoute table.table)
                        , dataTestId <| "go-to-table-" ++ table.table
                        , class <|
                            if table.playerCount > 0 then
                                "edGameTable__row edGameTable__row--enabled"

                            else
                                "edGameTable__row edGameTable__row--disabled"
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
                )
            <|
                List.filter
                    (\tableInfo ->
                        not tableInfo.params.twitter
                            && tableInfo.params.tournament
                            == Nothing
                    )
                    tableList
        ]


tableOfTournaments : Zone -> Posix -> List TableInfo -> Html.Html Types.Msg
tableOfTournaments zone time tableList =
    let
        tournaments =
            List.filter (.params >> .tournament >> (/=) Nothing) tableList
    in
    table [ class "edGameTable", style "-webkit-user-select" "none" ]
        [ thead []
            [ tr []
                [ th [ align "left" ] [ text "Bonus games" ]
                , th [ align "left" ] [ text "Sched." ]
                , th [ align "right" ] [ text "Prize" ]
                , th [ align "right" ] [ text "Fee" ]
                , th [ align "right" ] [ text "Points" ]
                , th [ align "right" ] [ text "Players" ]

                -- , th [ align "right" ] [ text "Min" ]
                -- , th [ align "right" ] [ text "Watch" ]
                , th [ align "right" ] [ text "Bots" ]
                ]
            ]
        , Html.Keyed.node "tbody" [] <|
            List.map
                (\table ->
                    ( table.table
                    , tr
                        [ onClick (Types.NavigateTo <| Types.GameRoute table.table)
                        , dataTestId <| "go-to-table-" ++ table.table
                        , class <|
                            if table.table == "5MinuteFix" || table.table == "MinuteMade" || table.playerCount > 0 then
                                "edGameTable__row edGameTable__row--enabled"

                            else
                                "edGameTable__row edGameTable__row--disabled"
                        ]
                      <|
                        [ td [ align "left" ] [ text <| table.table ]
                        ]
                            ++ (case table.params.tournament of
                                    Just tournament ->
                                        [ td [ align "left" ]
                                            [ text <|
                                                case table.status of
                                                    Game.Types.Playing ->
                                                        "Playing"

                                                    _ ->
                                                        case table.gameStart of
                                                            Nothing ->
                                                                tournament.frequency

                                                            Just timestamp ->
                                                                tournamentTime zone time timestamp
                                            ]
                                        , td [ align "right" ] [ text <| formatPoints tournament.prize ]
                                        ]

                                    Nothing ->
                                        [ td [ align "right" ] [ text "..." ]
                                        , td [ align "right" ] [ text "..." ]
                                        ]
                               )
                            ++ [ td [ align "right" ]
                                    [ text <|
                                        case table.params.tournament |> Maybe.map .fee |> Maybe.withDefault 0 of
                                            0 ->
                                                "Free"

                                            n ->
                                                formatPoints n
                                    ]
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

                               -- , td [ align "right" ]
                               -- [ text <|
                               -- String.fromInt table.startSlots
                               -- ]
                               -- , td [ align "right" ] [ text <| String.fromInt table.watchCount ]
                               , td [ align "right" ]
                                    [ text <|
                                        if table.params.botLess then
                                            "No"

                                        else
                                            "Yes"
                                    ]
                               ]
                    )
                )
            <|
                List.filter
                    (\tableInfo ->
                        not tableInfo.params.twitter
                    )
                    tournaments
        ]
