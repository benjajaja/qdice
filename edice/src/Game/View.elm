module Game.View exposing (view)

import Awards
import Backend.Types exposing (ConnectionStatus(..))
import Board
import Game.Chat
import Game.Footer
import Game.PlayerCard as PlayerCard exposing (playerPicture)
import Game.State exposing (canHover)
import Game.Types exposing (PlayerAction(..), isBot, statusToString)
import Helpers exposing (dataTestId, pointsSymbol, pointsToNextLevel)
import Html exposing (..)
import Html.Attributes exposing (class, disabled, href, style, target, type_)
import Html.Events exposing (onClick)
import Icon
import LeaderBoard.View
import Ordinal exposing (ordinal)
import Routing exposing (routeToString)
import Time exposing (posixToMillis)
import Types exposing (Model, Msg(..), PushEvent(..), Route(..), User(..))


view : Model -> Html Types.Msg
view model =
    let
        board =
            Board.view model.game.board
                (case model.game.board.hovered of
                    Just emoji ->
                        if canHover model.game emoji then
                            model.game.board.hovered
                            -- for Html.lazy ref-check

                        else
                            Nothing

                    Nothing ->
                        Nothing
                )
                |> Html.map BoardMsg
    in
    div [ class "edMainScreen" ]
        [ div [ class "edGameBoardWrapper" ]
            [ tableInfo model
            , header model
            , board
            , sitInModal model
            , boardFooter model
            , tableDetails model
            ]
        , div [ class "edGame__meta cartonCard" ]
            [ gameChat model
            , gameLog model
            ]
        , div [ class "edBoxes cartonCard" ] <|
            playerBox model
                ++ leaderboardBox model
        , Game.Footer.footer model
        ]


header : Model -> Html.Html Types.Msg
header model =
    div [ class "edGameHeader" ]
        [ playerBar 4 model
        ]


boardFooter : Model -> Html.Html Types.Msg
boardFooter model =
    let
        toolbar =
            if model.screenshot then
                []

            else
                [ div [ class "edGameBoardFooter__content" ] <| seatButtons model
                ]
    in
    div [ class "edGameBoardFooter" ] <|
        playerBar 0 model
            :: toolbar


playerBar : Int -> Model -> Html Msg
playerBar dropCount model =
    div [ class "edPlayerChips" ] <|
        List.indexedMap (PlayerCard.view model dropCount) <|
            List.take 4 <|
                List.drop dropCount <|
                    model.game.players


seatButtons : Model -> List (Html.Html Types.Msg)
seatButtons model =
    if model.backend.status /= Online then
        [ button [ class "edButton edGameHeader__button", disabled True ] [ Icon.icon "signal_wifi_off" ]
        ]

    else
        onlineButtons model


joinButton : String -> Types.Msg -> Html.Html Types.Msg
joinButton label msg =
    button
        [ class "edButton edGameHeader__button"
        , onClick msg
        , dataTestId "button-seat"
        ]
        [ text label ]


onlineButtons : Model -> List (Html.Html Types.Msg)
onlineButtons model =
    if model.game.status /= Game.Types.Playing then
        case model.game.player of
            Just player ->
                [ label
                    [ class <|
                        "edCheckbox edGameHeader__checkbox"
                            ++ (if Maybe.withDefault player.ready model.game.isReady then
                                    " edGameHeader__checkbox--checked"

                                else
                                    ""
                               )
                    , onClick <| GameCmd <| ToggleReady <| not <| Maybe.withDefault player.ready model.game.isReady
                    , dataTestId "check-ready"
                    ]
                    [ Icon.icon <|
                        if Maybe.withDefault player.ready model.game.isReady then
                            "check_box"

                        else
                            "check_box_outline_blank"
                    , text "Ready"
                    ]
                , joinButton "Leave" <| GameCmd Leave
                ]

            Nothing ->
                [ case model.user of
                    Types.Anonymous ->
                        joinButton "Join" <| ShowLogin Types.LoginShowJoin

                    Types.Logged user ->
                        if user.points >= model.game.points then
                            joinButton "Join" <| GameCmd Join

                        else
                            text <| "Table has minimum points of " ++ String.fromInt model.game.points
                ]

    else
        case model.game.player of
            Nothing ->
                if model.game.players |> List.any isBot then
                    case model.user of
                        Types.Anonymous ->
                            [ joinButton "Join & Take over a bot" <| ShowLogin Types.LoginShowJoin ]

                        -- TODO: check if newly registered users will be able to play by points
                        Types.Logged user ->
                            if user.points >= model.game.points then
                                [ joinButton "Join & Take over a bot" <| GameCmd Join ]

                            else
                                [ text <| "Table has minimum points of " ++ String.fromInt model.game.points ]

                else
                    []

            Just player ->
                let
                    sitButton =
                        if player.out then
                            [ button
                                [ class "edButton edGameHeader__button edGameHeader__button--left"
                                , onClick <| GameCmd SitIn
                                , dataTestId "button-seat"
                                ]
                                [ text "Sit in!" ]
                            ]

                        else if not model.game.hasTurn then
                            [ button
                                [ class "edButton edGameHeader__button edGameHeader__button--left"
                                , onClick <| GameCmd SitOut
                                , dataTestId "button-seat"
                                ]
                                [ text "Sit out" ]
                            ]

                        else
                            []

                    checkbox =
                        if model.game.canFlag then
                            [ label
                                [ class "edCheckbox edGameHeader__checkbox"
                                , onClick <| GameCmd <| Flag <| not <| Maybe.withDefault False model.game.flag
                                , dataTestId "check-flag"
                                ]
                                [ Icon.icon "flag"
                                , text <|
                                    if model.game.playerPosition == List.length model.game.players then
                                        "Surrender"

                                    else
                                        ordinal model.game.playerPosition
                                ]
                            ]

                        else
                            []

                    turnButton =
                        if model.game.hasTurn then
                            [ button
                                [ class "edButton edGameHeader__button"
                                , onClick <| GameCmd EndTurn
                                , dataTestId "button-seat"
                                ]
                                [ text "End turn" ]
                            ]

                        else
                            []
                in
                sitButton ++ checkbox ++ turnButton


gameLog : Model -> Html.Html Types.Msg
gameLog model =
    Game.Chat.gameBox
        model.game.gameLog
    <|
        "gameLog-"
            ++ Maybe.withDefault "NOTABLE" model.game.table


gameChat : Model -> Html.Html Types.Msg
gameChat model =
    div [ class "chatboxContainer" ]
        [ Game.Chat.chatBox
            model.game.chatInput
            (List.map .color model.game.players)
            model.game.chatLog
          <|
            "chatLog-"
                ++ Maybe.withDefault "NOTABLE" model.game.table
        ]


sitInModal : Model -> Html.Html Types.Msg
sitInModal model =
    div
        [ if model.game.isPlayerOut then
            style "" ""

          else
            style "display" "none"
        , class "edGame__SitInModal"
        , Html.Events.onClick <| GameCmd SitIn
        ]
        [ button
            [ onClick <| GameCmd SitIn
            ]
            [ text "Sit in!" ]
        ]


tableInfo : Model -> Html Types.Msg
tableInfo model =
    div [ class "edGameStatus" ] <|
        (case model.game.table of
            Just table ->
                [ text "Table "
                , text <| table
                , text " is"
                , span [ class "edGameStatus__chip--strong", dataTestId "game-status" ]
                    [ text <| "\u{00A0}" ++ statusToString model.game.status ++ "\u{00A0}" ]
                ]
                    ++ (case model.game.gameStart of
                            Nothing ->
                                [ text <| "round " ++ String.fromInt model.game.roundCount ]

                            Just timestamp ->
                                [ text "starting in"
                                , span [ class "edGameStatus__chip--strong" ]
                                    [ text <| "\u{00A0}" ++ String.fromInt (round <| toFloat timestamp - ((toFloat <| posixToMillis model.time) / 1000)) ++ "s" ]
                                ]
                       )

            Nothing ->
                []
        )
            ++ [ button [ class "edGameStatus__button edButton--icon", onClick RequestFullscreen ] [ Icon.icon "zoom_out_map" ] ]


tableDetails : Model -> Html Types.Msg
tableDetails model =
    div [ class "edGameDetails" ] <|
        case model.game.table of
            Just table ->
                [ span [ class "edGameStatus__chip" ] <|
                    [ text <|
                        if model.game.playerSlots == 0 then
                            "∅"

                        else
                            String.fromInt model.game.playerSlots
                    , text " players"
                    , if model.game.params.botLess then
                        text ", no bots"

                      else
                        text ", bots will join"
                    , text <| ", starts with " ++ String.fromInt model.game.startSlots ++ " players"
                    ]
                ]

            Nothing ->
                []


playerBox : Model -> List (Html Msg)
playerBox model =
    [ div [ class "edBox edPlayerBox" ]
        [ div [ class "edBox__header" ] [ text "Profile " ]
        , div [ class "edBox__inner" ] <|
            case model.user of
                Logged user ->
                    [ div [ class "edPlayerBox__Picture" ] [ playerPicture "medium" user.picture ]
                    , div [ class "edPlayerBox__Name" ]
                        [ a [ href <| routeToString False <| ProfileRoute user.id user.name ]
                            [ text user.name
                            ]
                        ]
                    , div [ class "edPlayerBox__stat" ] [ text "Level: ", text <| String.fromInt user.level ++ "▲" ]
                    , if List.length user.awards > 0 then
                        div [ class "edPlayerBox__awards" ] <| Awards.awardsShortList 20 user.awards

                      else
                        text ""
                    , div [ class "edPlayerBox__stat" ] [ text "Points: ", text <| String.fromInt user.points ++ pointsSymbol ]
                    , div [ class "edPlayerBox__stat" ]
                        [ text <| (String.fromInt <| pointsToNextLevel user.level user.levelPoints) ++ pointsSymbol
                        , text " points to next level"
                        ]
                    , div [ class "edPlayerBox__stat" ] [ text "Monthly rank: ", text <| ordinal user.rank ]
                    , div [ class "edPlayerBox__settings" ] <|
                        [ div []
                            [ a [ href "/me" ]
                                [ text "Account & Settings"
                                ]
                            ]
                        ]
                            ++ (if not model.sessionPreferences.notificationsEnabled then
                                    [ div [] [ text "You can get notifications when the tab is in background and it's your turn or the game starts:" ]
                                    , div [] [ button [ onClick RequestNotifications ] [ text "Enable notifications" ] ]
                                    ]

                                else
                                    []
                               )
                    ]
                        ++ (if not <| List.member "topwebgames" user.voted then
                                [ div [ class "edPlayerBox__settings" ]
                                    [ div [] [ text <| "You can get 1000" ++ pointsSymbol ++ " by voting for qdice.wtf" ]
                                    , div []
                                        [ a
                                            [ href <|
                                                "http://topwebgames.com/in.aspx?ID=11959&uid="
                                                    ++ user.id
                                                    ++ (case model.backend.clientId of
                                                            Just clientId ->
                                                                "&client_id=" ++ clientId

                                                            Nothing ->
                                                                ""
                                                       )
                                            , target
                                                "_blank"
                                            ]
                                            [ text "Vote for qdice" ]
                                        ]
                                    ]
                                ]

                            else
                                []
                           )

                Anonymous ->
                    [ div [] [ text "You're not logged in." ]
                    , button
                        [ onClick <| ShowLogin Types.LoginShow
                        ]
                        [ text "Pick a username" ]
                    ]
        ]
    ]


leaderboardBox : Model -> List (Html Msg)
leaderboardBox model =
    [ div [ class "edBox edLeaderboardBox" ]
        [ div [ class "edBox__header" ]
            [ a
                [ href "/leaderboard"
                ]
                [ text "Leaderboard" ]
            , text <| " for " ++ model.leaderBoard.month
            ]
        , div [ class "edBox__inner" ]
            [ LeaderBoard.View.table 10 model.leaderBoard.top ]
        ]
    ]
