module Footer exposing (footer)

import Backend.Types exposing (ConnectionStatus(..))
import Helpers exposing (dataTestId)
import Html exposing (..)
import Html.Attributes exposing (class, href)
import Html.Events exposing (onClick)
import Routing exposing (routeToString)
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
    [ link HomeRoute "Play!" "casino"
    ]


links2 : User -> List (Html Msg)
links2 user =
    [ link (StaticPageRoute Help) "Gameplay & Rules" "help"
    ]


links3 : User -> List (Html Msg)
links3 user =
    [ link (StaticPageRoute About) "About qdice" "info"
    ]


link : Route -> String -> String -> Html Types.Msg
link route label iconName =
    a [ href <| routeToString False route, class "edFooter--box__link" ]
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
