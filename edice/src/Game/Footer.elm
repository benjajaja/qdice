module Game.Footer exposing (footer)

import Game.Types exposing (TableInfo, statusToIcon)
import Helpers exposing (dataTestId, pointsSymbol)
import Html exposing (..)
import Html.Attributes exposing (align, class, style)
import Html.Events exposing (onClick)
import Icon
import Types exposing (Model, Msg(..))



--import Tables exposing (Table, tableList)


footer : Model -> Html.Html Types.Msg
footer model =
    div [ class "edTables cartonCard" ] [ tableOfTables model ]


tableOfTables : Model -> Html.Html Types.Msg
tableOfTables model =
    table [ class "edGameTable", style "-webkit-user-select" "none" ]
        [ thead []
            [ tr []
                [ th [ align "left" ] [ text "Table" ]
                , th [ align "right" ] [ text "Points" ]
                , th [ align "right" ] [ text "Players" ]
                , th [ align "right" ] [ text "Bots" ]
                , th [ align "right" ] [ text "Watching" ]
                , th [ align "right" ] [ text "Status" ]
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
                        , td [ align "right" ] [ text <| String.fromInt table.points ]
                        , td [ align "right" ]
                            [ text <|
                                String.concat
                                    [ String.fromInt table.playerCount
                                    , " / "
                                    , String.fromInt table.startSlots
                                    , "-"
                                    , String.fromInt table.playerSlots
                                    ]
                            ]
                        , td [ align "right" ]
                            [ text <|
                                if table.params.botLess then
                                    "No"

                                else
                                    "Yes"
                            ]
                        , td [ align "right" ] [ text <| String.fromInt table.watchCount ]
                        , td [ align "right" ]
                            [ Icon.icon <| statusToIcon table.status ]
                        , td [ align "right" ] [ text <| String.fromInt table.landCount ]

                        -- , td [ align "right" ] [ text <| String.fromInt table.stackSize ]
                        ]
                )
                model.tableList
        ]
