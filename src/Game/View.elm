module Game.View exposing (view)

import Backend.Types exposing (ConnectionStatus(..))
import Board
import Game.Chat
import Game.Footer exposing (footer)
import Game.PlayerCard as PlayerCard
import Game.State exposing (findUserPlayer)
import Game.Types exposing (PlayerAction(..), TableInfo)
import Html exposing (..)
import Html.Attributes exposing (class, style, type_)
import Html.Events
import Material
import Material.Button as Button
import Material.Icon as Icon
import Material.List as Lists
import Material.Options as Options
import Ordinal exposing (ordinal)
import Tables exposing (Table)
import Time exposing (posixToMillis)
import Types exposing (Model, Msg(..))


view : Model -> Html.Html Types.Msg
view model =
    let
        board =
            Board.view model.game.board
                |> Html.map BoardMsg
    in
        div [ class "edGame" ]
            --[ header model
            [ div [ class "edMainScreen" ]
                [ div [ class "edGameBoardWrapper" ]
                    [ tableInfo model
                    , board
                    , sitInModal model
                    , boardFooter model
                    ]
                , div [ class "edGame__meta" ]
                    [ div [ class "edPlayerChips" ] <| List.indexedMap (PlayerCard.view False model) model.game.players
                    , gameChat model
                    ]
                , div [ class "edGame__meta2" ]
                    [ gameLogOverlay model
                    , userCard model.user
                    ]
                , Game.Footer.footer model
                ]
            ]


header : Model -> Html.Html Types.Msg
header model =
    div [ class "edGameHeader" ]
        [ div [ class "edGameHeader__content" ]
            [ seatButton model
            , text <| model.game.table
            , endTurnButton model
            ]
        , div [ class "edGameHeader__decoration" ] []
        ]


boardFooter : Model -> Html.Html Types.Msg
boardFooter model =
    div [ class "edGameBoardFooter" ]
        [ div [ class "edGameBoardFooter__content" ]
            [ seatButton model
            , div [ class "edPlayerChips" ] <| List.indexedMap (PlayerCard.view True model) model.game.players
            , endTurnButton model
            ]
        ]


seatButton : Model -> Html.Html Types.Msg
seatButton model =
    let
        canPlay =
            case model.backend.status of
                Online ->
                    True

                _ ->
                    False

        ( label, onClick ) =
            case findUserPlayer model.user model.game.players of
                Just player ->
                    if model.game.status == Game.Types.Playing then
                        if player.out then
                            ( "Sit in", Options.onClick <| GameCmd SitIn )
                        else
                            ( "Sit out", Options.onClick <| GameCmd SitOut )
                    else
                        ( "Leave", Options.onClick <| GameCmd Leave )

                Nothing ->
                    case model.user of
                        Types.Anonymous ->
                            ( "Join", Options.onClick <| ShowLogin Types.LoginShowJoin )

                        Types.Logged user ->
                            ( "Join", Options.onClick <| GameCmd Join )

        disabled =
            if not canPlay then
                Button.disabled
            else
                Options.nop
    in
        Button.view
            Types.Mdl
            "button-game"
            model.mdc
            (onClick
                :: [ Button.raised
                     --, Button.colored
                   , Button.ripple
                   , Options.cs "edGameHeader__button"
                   , disabled
                   ]
            )
            [ text label ]


endTurnButton : Model -> Html.Html Types.Msg
endTurnButton model =
    Button.view
        Types.Mdl
        "button-end-turn"
        model.mdc
        [ Button.ripple
        , Options.cs "edGameHeader__button"
        , Options.onClick <| GameCmd EndTurn
        , if not model.game.hasTurn then
            Button.disabled
          else
            Options.nop
        ]
        [ text "End turn" ]


gameLogOverlay : Model -> Html.Html Types.Msg
gameLogOverlay model =
    Game.Chat.gameBox
        model.mdc
        model.game.gameLog
    <|
        "gameLog-"
            ++ model.game.table


gameChat : Model -> Html.Html Types.Msg
gameChat model =
    div [ class "chatboxContainer" ]
        [ Game.Chat.chatBox
            model.game.chatInput
            (List.map .color model.game.players)
            model.mdc
            model.game.chatLog
          <|
            "chatLog-"
                ++ model.game.table
        ]


userCard : Types.User -> Html.Html Types.Msg
userCard user_ =
    case user_ of
        Types.Logged user ->
            div [ class "edGame__user", Html.Events.onClick <| NavigateTo <| Types.ProfileRoute user.id ] <|
                [ div
                    [ class "edPlayerChip__picture"
                    , style "width" "70px"
                    , style "height" "70px"
                    ]
                    [ div
                        [ class "edPlayerChip__picture__image"
                        , style "background-image" ("url(" ++ user.picture ++ ")")
                        , style "background-size" "cover"
                        ]
                        []
                    ]
                , div [] [ text <| user.name ]
                , div [] [ text <| "✪ " ++ String.fromInt user.points ]
                ]

        Types.Anonymous ->
            text "not logged"


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
        [ Button.view
            Types.Mdl
            "button-sit-in"
            model.mdc
            [ Button.raised
            , Button.ripple
            , Options.cs ""
            , Options.onClick <| GameCmd SitIn
            ]
            [ text "Sit in!" ]
        ]


tableInfo : Model -> Html Types.Msg
tableInfo model =
    div [ class "edGameStatus" ]
        [ span [ class "edGameStatus__chip" ]
            [ text "Table "
            , span [ class "edGameStatus__chip--strong" ]
                [ text <| model.game.table
                ]
            ]
        , span [ class "edGameStatus__chip" ] <|
            List.append
                [ text ", "
                , span [ class "edGameStatus__chip--strong" ]
                    [ text <|
                        if model.game.playerSlots == 0 then
                            "∅"
                        else
                            String.fromInt model.game.playerSlots
                    ]
                , text " player game is "
                , span [ class "edGameStatus__chip--strong" ]
                    [ text <| Debug.toString model.game.status ]
                ]
                (case model.game.gameStart of
                    Nothing ->
                        [ text <| " round " ++ String.fromInt model.game.roundCount ]

                    Just timestamp ->
                        [ text " starting in "
                        , span [ class "edGameStatus__chip--strong" ]
                            [ text <| String.fromInt (round <| toFloat timestamp - ((toFloat <| posixToMillis model.time) / 1000)) ++ "s" ]
                        ]
                )
        ]
