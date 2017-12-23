module Footer exposing (footer)

import Html
import Html.Attributes exposing (class, style)
import Material.Footer as Footer
import Material.Icon as Icon
import Material.Options
import Types exposing (Model, Msg(..), User(..))
import Backend.Types exposing (ConnectionStatus(..))


footer : Model -> Html.Html Msg
footer model =
    Footer.mini []
        { left =
            Footer.left [] (statusMessage model.backend.status)
        , right =
            Footer.right []
                [ Footer.link
                    [ Material.Options.cs "footer--profile-link"
                    , Material.Options.onClick <|
                        case model.user of
                            Anonymous ->
                                Authorize

                            Logged _ ->
                                Logout
                    ]
                    (case model.user of
                        Logged user ->
                            [ Html.div [] [ Html.text <| user.name ]
                            , Html.img [ Html.Attributes.src user.picture ] []
                            ]

                        Anonymous ->
                            [ Icon.i "account_circle" ]
                    )
                ]
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
                    "wifi_lock"

                Reconnecting _ ->
                    "wifi_lock"

                SubscribingGeneral ->
                    "wifi"

                SubscribingTable ->
                    "perm_scan_wifi"

                Online ->
                    "network_wifi"
    in
        [ Footer.html <|
            Html.div [ Html.Attributes.class "edGameStatus" ]
                [ Html.div [] [ Icon.i icon ]
                , Html.div [] [ Html.text message ]
                ]
        ]
