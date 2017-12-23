module Game.Footer exposing (footer)

import Game.Types exposing (TableInfo)
import Html
import Html.Attributes exposing (class, style)
import Material
import Material.Options as Options
import Material.Button as Button
import Material.Icon as Icon
import Material.Footer as Footer
import Material.List as Lists
import Material.Table as Table
import Types exposing (Model, Msg(..))
import Tables exposing (Table, tableList)


footer : Model -> Html.Html Types.Msg
footer model =
    Footer.mega []
        { top =
            Footer.top []
                { left = Footer.left [] []
                , right = Footer.right [] []
                }
        , middle =
            Footer.middle [] [ Footer.html <| listOfTables model ]
        , bottom = Footer.bottom [] []
        }


tableOfTables : Model -> Html.Html Types.Msg
tableOfTables model =
    Table.table [ Options.cs "edGameList" ]
        [ Table.thead []
            [ Table.tr []
                [ Table.th [] [ Html.text "Table" ]
                , Table.th [] [ Html.text "Status" ]
                , Table.th [] [ Html.text "Playing" ]
                , Table.th [] [ Html.text "Stacks" ]
                , Table.th [] [ Html.text "Size" ]
                ]
            ]
        , Table.tbody [] <|
            List.indexedMap
                (\i ->
                    \table ->
                        Table.tr [ Options.cs "edGameList__item" ]
                            [ Table.td [ Options.cs "edGameList__item_title" ]
                                [ Html.text <| toString table.table ]
                            , Table.td []
                                [ Html.text <| toString table.status ]
                            , Table.td []
                                [ Html.text <|
                                    (toString table.playerCount)
                                        ++ " / "
                                        ++ (toString table.playerSlots)
                                ]
                            , Table.td []
                                [ Html.text <| toString table.stackSize ]
                            , Table.td []
                                [ Html.text <| toString table.landCount ]
                            ]
                )
                model.tableList
        ]


listOfTables : Model -> Html.Html Types.Msg
listOfTables model =
    Lists.ul [ Options.cs "edGameList" ] <|
        List.indexedMap
            (\i ->
                \table ->
                    Lists.li [ Lists.withSubtitle, Options.cs "edGameList__item" ]
                        [ Lists.content []
                            [ Html.text <| toString table.table
                            , Lists.subtitle [ Options.cs "edGameList__item__subtitle" ]
                                [ Html.text <|
                                    (toString table.playerCount)
                                        ++ " / "
                                        ++ (toString table.playerSlots)
                                        ++ " playing"
                                ]
                            ]
                        , goToTableButton model table i
                        ]
            )
            model.tableList


goToTableButton : Model -> TableInfo -> Int -> Html.Html Types.Msg
goToTableButton model table i =
    Button.render Types.Mdl
        [ i ]
        model.mdl
        [ Button.icon
        , Options.onClick (Types.NavigateTo <| Types.GameRoute table.table)
        ]
        [ Icon.i "chevron_right" ]
