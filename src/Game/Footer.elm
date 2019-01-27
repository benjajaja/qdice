module Game.Footer exposing (footer)

import Game.Types exposing (TableInfo)
import Html exposing (..)
import Html.Attributes exposing (class, style)
import Html.Events exposing (onClick)
import Material
import Material.Button as Button
import Material.Elevation as Elevation
import Material.Icon as Icon
import Material.List as Lists
import Material.Options as Options
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
                , th [] [ text "Level" ]
                , th [] [ text "Players" ]
                , th [] [ text "Watching" ]
                , th [] [ text "Status" ]
                , th [] [ text "Size" ]
                , th [] [ text "Stacks" ]
                , th [] []
                ]
            ]
        , tbody [] <|
            List.indexedMap
                (\i ->
                    \table ->
                        tr
                            [ onClick (Types.NavigateTo <| Types.GameRoute table.table)
                            ]
                            [ td [] [ text <| table.table ]
                            , td [] [ text <| String.fromInt table.points ]
                            , td []
                                [ text <|
                                    String.fromInt table.playerCount
                                        ++ " / "
                                        ++ String.fromInt table.playerSlots
                                        ++ " playing"
                                ]
                            , td [] [ text <| String.fromInt table.watchCount ]
                            , td [] [ text <| Debug.toString table.status ]
                            , td [] [ text <| String.fromInt table.landCount ]
                            , td [] [ text <| String.fromInt table.stackSize ]
                              --, td [] [ Icon.i "chevron_right" ]
                            ]
                )
                model.tableList
        ]
