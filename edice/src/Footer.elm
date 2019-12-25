module Footer exposing (footer)

import Backend.Types exposing (ConnectionStatus(..))
import Helpers exposing (dataTestId)
import Html exposing (..)
import Html.Attributes exposing (class, href)
import Html.Events exposing (onClick)
import Types exposing (LoginDialogStatus(..), Model, Msg(..), Route(..), StaticPage(..), User(..))


footer : Model -> Html.Html Msg
footer model =
    div [ class "edFooter" ]
        [ div [ class "edFooter--struts" ]
            [ div [ class "edFooter--boxes" ]
                [ div [ class "edFooter--box edFooter--box__links" ] <|
                    links1 model.user
                , div [ class "edFooter--box edFooter--box__links" ] <|
                    links2 model.user
                , div [ class "edFooter--box edFooter--box__links" ] <|
                    links3 model.user
                ]
            , div [ class "edFooter--row" ]
                [ statusMessage model.backend.version model.backend.status
                ]
            ]
        ]


links1 : User -> List (Html Msg)
links1 user =
    [ link "/" "Play!" "casino"
    , case user of
        Anonymous ->
            span [ onClick <| ShowLogin LoginShow, class "edFooter--box__link" ] [ i [ class "material-icons" ] [ text "account_circle" ], text "Login" ]

        Logged _ ->
            link "/me" "Account & Settings" "account_circle"
    , link "/leaderboard" "Leaderboard" "list"
    ]


links2 : User -> List (Html Msg)
links2 user =
    [ link "/static/help" "Gameplay & Rules" "help"
    , link "/static/about" "About qdice" "info"
    , link "/static/changelog" "Changelog" "call_merge"
    ]


links3 : User -> List (Html Msg)
links3 user =
    [ a [ href "https://www.reddit.com/r/Qdice/", class "edFooter--box__link" ]
        [ i [ class "material-icons" ] [ text "group_work" ]
        , text "Reddit"
        ]

    --, a [ href "https://t.me/joinchat/DGkiGhEYyjf8bauoWkAGNA", class "edFooter--box__link" ]
    --[ i [ class "material-icons" ] [ text "chat" ]
    --, text "Telegram group"
    --]
    , a [ href "https://twitter.com/qdicewtf", class "edFooter--box__link" ]
        [ i [ class "material-icons" ] [ text "receipt" ]
        , text "Twitter"
        ]
    , a [ href "https://discord.gg/E2m3Gra", class "edFooter--box__link" ]
        [ i [ class "material-icons" ] [ text "headset_mic" ]
        , text "Discord"
        ]
    ]


link : String -> String -> String -> Html Types.Msg
link path label iconName =
    a [ href path, class "edFooter--box__link" ]
        [ i [ class "material-icons" ] [ text iconName ]
        , text label
        ]


statusMessage : String -> ConnectionStatus -> Html Types.Msg
statusMessage version status =
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
                    "Linking..."

                SubscribingTable ->
                    "Linking table..."

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
    div []
        [ span [] [ text <| "Version: " ++ version ++ ", Status: " ]
        , span [ dataTestId "connection-status" ] [ text message ]
        ]
