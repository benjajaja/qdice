module Footer exposing (footer)

import Html exposing (..)
import Html.Attributes exposing (class, style)
import Material.Footer as Footer
import Material.Icon as Icon
import Material.Options
import Material.Menu as Menu
import Types exposing (Model, Msg(..), User(..), Route(..), StaticPage(..))
import Tables exposing (Table(..))
import Backend.Types exposing (ConnectionStatus(..))


footer : Model -> Html.Html Msg
footer model =
    Footer.mini []
        { left = Footer.left [] [ statusMessage model.backend.status ]
        , right = Footer.right [] []
        }


statusMessage : ConnectionStatus -> Footer.Content Types.Msg
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

                Connecting ->
                    "Connecting..."

                SubscribingGeneral ->
                    "Network..."

                SubscribingTable ->
                    "Table..."

                _ ->
                    toString status

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
        Footer.html <|
            Html.div [ Html.Attributes.class "edGameStatus" ]
                [ Html.div [] [ Icon.i icon ]
                , Html.div [] [ Html.text message ]
                ]
