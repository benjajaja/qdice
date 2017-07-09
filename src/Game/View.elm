module Game.View exposing (view)

import Game.Types exposing (Msg(..))
import Game.Types
import Game.Chat
import Html
import Material
import Material.Chip as Chip
import Material.Button as Button
import Material.Icon as Icon
import Material.Footer as Footer
import Types exposing (Model, Msg)
import Board
import Backend.Types exposing (ConnectionStatus(..))


-- import Board.Types exposing (Msg(..))
-- import Land


view : Model -> Html.Html Types.Msg
view model =
    let
        board =
            Board.view model.game.board
                |> Html.map BoardMsg
    in
        Html.div []
            [ Html.div []
                [ Chip.span []
                    [ Chip.content []
                        [ Html.text <| "Game: " ++ (toString model.game.status) ]
                    ]
                , Chip.span []
                    [ Chip.content []
                        [ Html.text <| "Table: " ++ (toString model.game.table) ]
                    ]
                ]
              -- (--List.append
              --  (Chip.chip Html.div [] [ Chip.text [] ("Game: " ++ (toString model.game.status)) ])
              --     (Chip.chip Html.div [] [ Chip.text [] ("Table: " ++ (toString model.game.table)) ])
              -- )
            , board |> Html.map Types.GameMsg
            , boardHistory model
            , footer model
            ]


playButtons : Material.Model -> List (Html.Html Types.Msg)
playButtons mdl =
    [ Button.render
        Types.Mdl
        [ 0 ]
        mdl
        [ Button.primary
        , Button.colored
        , Button.ripple
        ]
        [ Icon.i "add" ]
    , Button.render
        Types.Mdl
        [ 0 ]
        mdl
        [ Button.primary
        , Button.colored
        , Button.ripple
        ]
        [ Icon.i "remove" ]
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
        , right = Footer.right [] []
        }


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
