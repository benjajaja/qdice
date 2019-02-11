module Footer exposing (footer)

import Backend.Types exposing (ConnectionStatus(..))
import Html exposing (..)
import Html.Attributes exposing (class, style, href)
import Html.Events exposing (onClick)
import Icon
import Types exposing (Model, Msg(..), Route(..), StaticPage(..), User(..), LoginDialogStatus(..))


footer : Model -> Html.Html Msg
footer model =
    div [ class "edFooter" ]
        [ div [ class "edFooter--box" ] [ statusMessage model.backend.status ]
        , div [ class "edFooter--box edFooter--box__links" ] <|
            links model.user
        ]


links : User -> List (Html Msg)
links user =
    let
        group1 =
            [ link "/" "Home" "home" ]

        userLink =
            case user of
                Anonymous ->
                    span [ onClick <| ShowLogin LoginShow, class "edFooter--box__link" ] [ i [ class "material-icons" ] [ text "account_circle" ], text "Login" ]

                Logged _ ->
                    link "/me" "Settings" "account_circle"

        group2 =
            [ link "/leaderboard" "Leaderboard" "list"
            , a [ href "https://www.reddit.com/r/Qdice/", class "edFooter--box__link" ]
                [ i [ class "material-icons" ] [ text "group_work" ]
                , text "Community"
                ]
            , link "/static/help" "Halp" "help"
            , link "/static/about" "About" "info"
            ]
    in
        List.append group1 (userLink :: group2)


link : String -> String -> String -> Html Types.Msg
link path label iconName =
    a [ href path, class "edFooter--box__link" ]
        [ i [ class "material-icons" ] [ text iconName ]
        , text label
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
            [ Html.div [] [ Icon.icon icon ]
            , Html.div [] [ Html.text message ]
            ]
