module Footer exposing (footer)

import Backend.Types exposing (ConnectionStatus(..))
import Helpers exposing (dataTestId)
import Html exposing (..)
import Html.Attributes exposing (class, height, href, src, style, width)
import Icon
import Routing.String exposing (routeToString)
import Types exposing (LoginDialogStatus(..), Model, Msg(..), Route(..), StaticPage(..), User(..))


footer : Route -> String -> ConnectionStatus -> Html.Html Msg
footer route version status =
    div [ class "edFooter" ]
        [ div [ class "edFooter--struts" ]
            [ div [ class "edFooter--boxes" ]
                [ div [ class "edFooter--box edFooter--box__links" ] <|
                    [ a [ href <| routeToString False HomeRoute, class "edFooter--box__link" ]
                        [ img [ src "quedice.svg", width 24, height 24, style "margin-right" "2px" ] []
                        , text "Play!"
                        ]
                    ]
                , div [ class "edFooter--box edFooter--box__links" ] <|
                    [ link (StaticPageRoute Help) "How to play" "help" ]
                , div [ class "edFooter--box edFooter--box__links" ] <|
                    [ a [ href "https://store.steampowered.com/app/2255020/Qdice/", class "edFooter--box__link" ]
                        [ i [ class "material-icons" ] [ text "open_in_new" ]
                        , text "Qdice on Steam"
                        ]
                    ]
                -- , div [ class "edFooter--box edFooter--box__links" ] <|
                    -- [ link (StaticPageRoute About) "What's Qdice.wtf?" "info" ]
                -- , div [ class "edFooter--box edFooter--box__links" ] <|
                    -- [ link CommentsRoute "Posts" "comment" ]
                -- , div [ class "edFooter--box edFooter--box__links" ] <|
                    -- [ a [ href "https://discord.gg/E2m3Gra", class "edFooter--box__link" ]
                        -- [ i [ class "material-icons" ] [ text "headset" ]
                        -- , text "Discord"
                        -- ]
                    -- ]
                ]
            , div [ class "edFooter--row" ]
                [ statusMessage route version status
                ]
            ]
        ]



link : Route -> String -> String -> Html Types.Msg
link route label iconName =
    a [ href <| routeToString False route, class "edFooter--box__link" ]
        [ i [ class "material-icons" ] [ text iconName ]
        , text label
        ]


statusMessage : Route -> String -> ConnectionStatus -> Html Types.Msg
statusMessage route version status =
    let
        message =
            case status of
                Reconnecting attempts _ ->
                    case attempts of
                        1 ->
                            "Reconnecting..."

                        count ->
                            "Reconnecting... (" ++ String.fromInt count ++ " retries)"

                Connecting table ->
                    case table of
                        Just t ->
                            "Connecting to " ++ t ++ "..."

                        Nothing ->
                            "Connecting ..."

                Subscribing _ ( ( client, all ), table ) ->
                    case route of
                        GameRoute _ ->
                            "Linking "
                                ++ (if client then
                                        "1"

                                    else
                                        "0"
                                   )
                                ++ (if all then
                                        "1"

                                    else
                                        "0"
                                   )
                                ++ Maybe.withDefault "---" table

                        _ ->
                            if client && all then
                                "Online off table"

                            else
                                "Linking..."

                Offline _ ->
                    "Offline"

                Online _ table ->
                    "Online on " ++ table

        icon =
            case status of
                Offline _ ->
                    "signal_wifi_off"

                Connecting _ ->
                    "signal_wifi_off"

                Reconnecting _ _ ->
                    "signal_wifi_off"

                Subscribing _ ( _, table ) ->
                    case table of
                        Just _ ->
                            "perm_scan_wifi"

                        _ ->
                            "wifi"

                Online _ _ ->
                    "network_wifi"
    in
    div []
        [ span []
            [ text <| "Version: "
            -- , a [ href <| "https://github.com/benjajaja/qdice/commit/" ++ version ]
                -- [ text version ]
            , text version
            , text <| ", Status: "
            ]
        , span [ dataTestId "connection-status" ] [ text <| message ++ " ", Icon.iconSized 8 icon ]
        ]
