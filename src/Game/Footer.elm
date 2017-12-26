module Game.Footer exposing (footer)

import Game.Types exposing (TableInfo)
import Html exposing (..)
import Html.Attributes exposing (class, style)
import Html.Events exposing (onClick)
import Material
import Material.Options as Options
import Material.Button as Button
import Material.Icon as Icon
import Material.Footer as Footer
import Material.List as Lists
import Material.Table as Table
import Material.Elevation as Elevation
import Types exposing (Model, Msg(..))
import Tables exposing (encodeTable)


--import Tables exposing (Table, tableList)


footer : Model -> Html.Html Types.Msg
footer model =
    div [ class "edTables" ] [ tableOfTables model ]



--Footer.mega []
--{ top =
--Footer.top []
--{ left = Footer.left [] []
--, right = Footer.right [] []
--}



--, middle =
--Footer.middle [] [ Footer.html <| tableOfTables model ]
--, bottom = Footer.bottom [] []
--}


tableOfTables : Model -> Html.Html Types.Msg
tableOfTables model =
    Options.div [ Elevation.e2 ]
        [ table [ class "edGameTable" ]
            [ thead []
                [ tr []
                    [ th [] [ text "Table" ]
                    , th [] [ text "Players" ]
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
                                [ td [] [ text <| encodeTable table.table ]
                                , td []
                                    [ text <|
                                        (toString table.playerCount)
                                            ++ " / "
                                            ++ (toString table.playerSlots)
                                            ++ " playing"
                                    ]
                                , td [] [ text <| toString table.status ]
                                , td [] [ text <| toString table.landCount ]
                                , td [] [ text <| toString table.stackSize ]
                                , td [] [ Icon.i "chevron_right" ]
                                ]
                    )
                    model.tableList
            ]
        ]



--Table.table [ Options.cs "edGameList" ]
--[ Table.thead []
--[ Table.tr []
--[ Table.th [] [ Html.text "Table" ]
--, Table.th [] [ Html.text "Status" ]
--, Table.th [] [ Html.text "Playing" ]
--, Table.th [] [ Html.text "Stacks" ]
--, Table.th [] [ Html.text "Size" ]
--]
--]
--, Table.tbody [] <|
--List.indexedMap
--(\i ->
--\table ->
--Table.tr [ Options.cs "edGameList__item" ]
--[ Table.td [ Options.cs "edGameList__item_title" ]
--[ Html.text <| toString table.table ]
--, Table.td []
--[ Html.text <| toString table.status ]
--, Table.td []
--[ Html.text <|
--(toString table.playerCount)
--++ " / "
--++ (toString table.playerSlots)
--]
--, Table.td []
--[ Html.text <| toString table.stackSize ]
--, Table.td []
--[ Html.text <| toString table.landCount ]
--]
--)
--model.tableList
--]


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
