module Footer exposing (footer)

import Backend.Types exposing (ConnectionStatus(..))
import Html exposing (..)
import Html.Attributes exposing (class, style)
import Material.Icon as Icon
import Material.Menu as Menu
import Material.Options
import Types exposing (Model, Msg(..), Route(..), StaticPage(..), User(..))


footer : Model -> Html.Html Msg
footer model =
    div []
        [ div [] [ statusMessage model.backend.status ]
        , div [] []
        ]


statusMessage : ConnectionStatus -> Html Types.Msg
statusMessage status =
    let
        message =
            case status of
                Reconnecting attempts ->
                    case attempts of
                        1 ->
                            "Reconnecting..."

                        count ->
                            "Reconnecting... (" ++ String.fromInt attempts ++ " retries)"

                Connecting ->
                    "Connecting..."

                SubscribingGeneral ->
                    "Network..."

                SubscribingTable ->
                    "Table..."

                Offline ->
                    "Offline"

                Online ->
                    "Online"

        icon =
            case status of
                Offline ->
                    "signal_wifi_off"

                Connecting ->
                    "signal_wifi_off"

                Reconnecting _ ->
                    "signal_wifi_off"

                SubscribingGeneral ->
                    "wifi"

                SubscribingTable ->
                    "perm_scan_wifi"

                Online ->
                    "network_wifi"
    in
        Html.div [ Html.Attributes.class "edGameStatus" ]
            [ Html.div [] [ Icon.view [] icon ]
            , Html.div [] [ Html.text message ]
            ]
