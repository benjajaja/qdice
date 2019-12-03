module Game.Footer exposing (footer)

import Game.Types exposing (TableInfo, statusToIcon)
import Helpers exposing (dataTestId)
import Html exposing (..)
import Html.Attributes exposing (class, style)
import Html.Events exposing (onClick)
import Icon
import Types exposing (Model, Msg(..))



--import Tables exposing (Table, tableList)


footer : Model -> Html.Html Types.Msg
footer model =
    div [ class "edTables" ] [ tableOfTables model ]


tableOfTables : Model -> Html.Html Types.Msg
tableOfTables model =
    table [ class "edGameTable" ]
        [ thead []
            [ tr []
                [ th [] [ text "Table" ]

                --, th [] [ text "Level" ]
                , th [] [ text "Players" ]
                , th [] [ text "Watching" ]
                , th [] [ text "Status" ]
                , th [] [ text "Size" ]
                , th [] [ text "Stacks" ]
                , th [] [ text "Points" ]
                , th [] []
                ]
            ]
        , tbody [] <|
            List.indexedMap
                (\i ->
                    \table ->
                        tr
                            [ onClick (Types.NavigateTo <| Types.GameRoute table.table)
                            , dataTestId <| "go-to-table-" ++ table.table
                            ]
                            [ td [] [ text <| table.table ]

                            --, td [] [ text <| String.fromInt table.points ]
                            , td []
                                [ text <|
                                    String.concat
                                        [ String.fromInt table.playerCount
                                        , " / "
                                        , String.fromInt table.startSlots
                                        , "-"
                                        , String.fromInt table.playerSlots
                                        ]
                                ]
                            , td [] [ text <| String.fromInt table.watchCount ]
                            , td []
                                [ Icon.icon <| statusToIcon table.status ]
                            , td [] [ text <| String.fromInt table.landCount ]
                            , td [] [ text <| String.fromInt table.stackSize ]
                            , td [] [ text <| String.fromInt table.points ]
                            ]
                )
                model.tableList
        ]
