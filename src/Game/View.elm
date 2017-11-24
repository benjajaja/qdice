module Game.View exposing (view)

import Game.Types exposing (Msg(..))
import Game.Types
import Game.Chat
import Html
import Html.Attributes exposing (class)
import Material
import Material.Options as Options
import Material.Chip as Chip
import Material.Button as Button
import Material.Icon as Icon
import Material.Footer as Footer
import Material.List as Lists
import Types exposing (Model, Msg)
import Tables exposing (Table, tableList)
import Board
import Backend.Types exposing (ConnectionStatus(..))


view : Model -> Html.Html Types.Msg
view model =
    let
        board =
            Board.view model.game.board
                |> Html.map BoardMsg
    in
        Html.div [ class "ed-game" ]
            [ header model
            , board |> Html.map Types.GameMsg
            , Html.div [] <| List.map (playerChip model) model.game.players
            , boardHistory model
            , footer model
            ]


header : Model -> Html.Html Types.Msg
header model =
    Html.div [ class "edGameHeader" ]
        [ Html.span [ class "edGameHeader__chip" ]
            [ Html.text "Table "
            , Html.span [ class "edGameHeader__chip--strong" ]
                [ Html.text <| toString model.game.table
                ]
            ]
        , Html.span [ class "edGameHeader__chip" ]
            [ Html.text ", "
            , Html.span [ class "edGameHeader__chip--strong" ]
                [ Html.text <| toString model.game.playerCount
                ]
            , Html.text " player game is "
            , Html.span [ class "edGameHeader__chip--strong" ]
                [ Html.text <| toString model.game.status
                ]
            ]
        , playButton model
        ]


playButton : Model -> Html.Html Types.Msg
playButton model =
    Button.render
        Types.Mdl
        [ 0 ]
        model.mdl
        [ Button.raised
        , Button.colored
        , Button.ripple
        , Options.cs "edGameHeader__button"
        , Options.onClick <| Types.GameMsg JoinGame
        ]
        [ Html.text "Join game" ]


playerChip : Model -> Game.Types.Player -> Html.Html Types.Msg
playerChip model player =
    Chip.span []
        [ Chip.content []
            [ Html.text <| player.name ]
        ]


boardHistory : Model -> Html.Html Types.Msg
boardHistory model =
    Html.div []
        [ Game.Chat.chatBox model ]


footer : Model -> Html.Html Types.Msg
footer model =
    Footer.mini []
        { left =
            Footer.left [] (statusMessage model.backend.status)
        , right = Footer.right [] (listOfTables model tableList)
        }


listOfTables : Model -> List Table -> List (Footer.Content Types.Msg)
listOfTables model tables =
    [ Footer.html <|
        Lists.ul [] <|
            List.indexedMap
                (\i ->
                    \table ->
                        Lists.li [ Lists.withSubtitle ]
                            [ Lists.content []
                                [ Html.text <| toString table
                                , Lists.subtitle [] [ Html.text "Unknown" ]
                                ]
                            , joinTableButton model table i
                            ]
                )
                tables
    ]


joinTableButton : Model -> Table -> Int -> Html.Html Types.Msg
joinTableButton model table i =
    Button.render Types.Mdl
        [ i ]
        model.mdl
        [ Button.icon
        , Options.onClick (Types.NavigateTo <| Types.GameRoute table)
        ]
        [ Icon.i "chevron_right" ]


statusMessage : ConnectionStatus -> List (Footer.Content Types.Msg)
statusMessage status =
    let
        message =
            case status of
                Reconnecting attempts ->
                    case attempts of
                        1 ->
                            "Reconnecting..."

                        count ->
                            "Reconnecting... (" ++ (toString attempts) ++ " retries)"

                _ ->
                    toString status

        icon =
            case status of
                Offline ->
                    "signal_wifi_off"

                Connecting ->
                    "signal_wifi_off"

                Reconnecting _ ->
                    "wifi"

                Online ->
                    "network_wifi"
    in
        [ Footer.html <| Icon.i icon
          -- , Footer.html <| Html.text message
        ]
