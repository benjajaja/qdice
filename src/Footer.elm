module Footer exposing (footer)

import Html exposing (..)
import Html.Attributes exposing (class, style)
import Material.Footer as Footer
import Material.Icon as Icon
import Material.Options
import Types exposing (Model, Msg(..), User(..), Route(..), StaticPage(..))
import Tables exposing (Table(..))
import Backend.Types exposing (ConnectionStatus(..))


footer : Model -> Html.Html Msg
footer model =
    Footer.mini []
        { left =
            Footer.left []
                [ Footer.links [] <|
                    (List.map
                        (\( label, path ) ->
                            Footer.linkItem
                                [ Material.Options.onClick <| DrawerNavigateTo path ]
                                [ Footer.html <| text label ]
                        )
                        [ ( "Play", GameRoute Melchor )
                        , ( "My profile", MyProfileRoute )
                        , ( "Help", StaticPageRoute Help )
                        , ( "About", StaticPageRoute About )
                          --, ( "Editor", EditorRoute )
                        ]
                    )
                ]
        , right =
            Footer.right []
                [ statusMessage model.backend.status
                , Footer.link
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
        Footer.html <|
            Html.div [ Html.Attributes.class "edGameStatus" ]
                [ Html.div [] [ Icon.i icon ]
                , Html.div [] [ Html.text message ]
                ]
