module Game.View exposing (view)

import Game.Types exposing (PlayerAction(..), TableInfo)
import Game.State exposing (findUserPlayer)
import Game.Chat
import Game.Footer exposing (footer)
import Game.PlayerCard as PlayerCard
import Html exposing (..)
import Html.Attributes exposing (class, style, type_)
import Html.Events
import Material
import Material.Options as Options
import Material.Button as Button
import Material.Icon as Icon
import Material.Footer as Footer
import Material.List as Lists
import Material.Toggles as Toggles
import Types exposing (Model, Msg(..))
import Tables exposing (Table)
import Board
import Backend.Types exposing (ConnectionStatus(..))
import Time exposing (inMilliseconds)
import Ordinal exposing (ordinal)


view : Model -> Html.Html Types.Msg
view model =
    let
        board =
            Board.view model.game.board
                |> Html.map BoardMsg
    in
        div [ class "edGame" ]
            [ header model
            , div [ class "edMainScreen" ]
                [ div [ class "edGameBoardWrapper" ]
                    [ tableInfo model
                    , board
                    , sitInModal model
                    ]
                , div [ class "edGame__meta" ]
                    [ div [ class "edPlayerChips" ] <| List.indexedMap (PlayerCard.view model) model.game.players
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
            , flagCheckbox model
            , endTurnButton model
            ]
        , div [ class "edGameHeader__decoration" ] []
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

        player =
            findUserPlayer model.user model.game.players

        ( label, onClick ) =
            case player of
                Just player ->
                    (if model.game.status == Game.Types.Playing then
                        (if player.out then
                            ( "Sit in", Options.onClick <| GameCmd SitIn )
                         else
                            ( "Sit out", Options.onClick <| GameCmd SitOut )
                        )
                     else
                        ( "Leave", Options.onClick <| GameCmd Leave )
                    )

                Nothing ->
                    case model.user of
                        Types.Anonymous ->
                            ( "Join", Options.onClick <| ShowLogin Types.LoginShowJoin )

                        Types.Logged user ->
                            ( "Join", Options.onClick <| GameCmd Join )
    in
        Button.render
            Types.Mdl
            [ 1 ]
            model.mdl
            (onClick
                :: [ Button.raised
                   , Button.colored
                   , Button.ripple
                   , Options.cs "edGameHeader__button"
                   , Options.disabled <| not canPlay
                   ]
            )
            [ text label ]


endTurnButton : Model -> Html.Html Types.Msg
endTurnButton model =
    Button.render
        Types.Mdl
        [ 1 ]
        model.mdl
        [ Button.colored
        , Button.ripple
        , Options.cs "edGameHeader__button"
        , Options.onClick <| GameCmd EndTurn
        , Options.disabled <| not model.game.hasTurn
        ]
        [ text "End turn" ]


gameLogOverlay : Model -> Html.Html Types.Msg
gameLogOverlay model =
    Game.Chat.gameBox
        model.mdl
        model.game.gameLog
    <|
        "gameLog-"
            ++ (toString model.game.table)


gameChat : Model -> Html.Html Types.Msg
gameChat model =
    div [ class "chatboxContainer" ]
        [ Game.Chat.chatBox
            (not model.isTelegram)
            model.game.chatInput
            (List.map .color model.game.players)
            model.mdl
            model.game.chatLog
          <|
            "chatLog-"
                ++ (toString model.game.table)
        ]


userCard : Types.User -> Html.Html Types.Msg
userCard user =
    case user of
        Types.Logged user ->
            div [ class "edGame__user", Html.Events.onClick <| NavigateTo <| Types.ProfileRoute user.id ] <|
                [ div
                    [ class "edPlayerChip__picture"
                    , style [ ( "width", "70px" ), ( "height", "70px" ) ]
                    ]
                    [ div
                        [ class "edPlayerChip__picture__image"
                        , style
                            [ ( "background-image", ("url(" ++ user.picture ++ ")") )
                            , ( "background-size", "cover" )
                            ]
                        ]
                        []
                    ]
                , div [] [ text <| user.name ]
                , div [] [ text <| "✪ " ++ toString user.points ]
                ]

        Types.Anonymous ->
            text "not logged"


sitInModal : Model -> Html.Html Types.Msg
sitInModal model =
    div
        [ style <|
            if model.game.isPlayerOut then
                []
            else
                [ ( "display", "none" ) ]
        , class "edGame__SitInModal"
        , Html.Events.onClick <| GameCmd SitIn
        ]
        [ Button.render
            Types.Mdl
            [ 0 ]
            model.mdl
            [ Button.raised
            , Button.colored
            , Button.ripple
            , Options.cs ""
            , Options.onClick <| GameCmd SitIn
            ]
            [ text "Sit in!" ]
        ]


flagCheckbox : Model -> Html Types.Msg
flagCheckbox model =
    div [ class "edGameFlag" ] <|
        case model.game.player of
            Nothing ->
                []

            Just player ->
                [ Toggles.checkbox Mdl
                    []
                    model.mdl
                    [ Options.onToggle <| GameCmd Flag
                    , Options.disabled <| (not model.game.canFlag)
                    , Toggles.ripple
                    , Toggles.value <|
                        case player.flag of
                            Nothing ->
                                False

                            Just _ ->
                                True
                    ]
                    [ text <|
                        "Flag "
                            ++ (ordinal <|
                                    case player.flag of
                                        Nothing ->
                                            player.gameStats.position

                                        Just position ->
                                            position
                               )
                    ]
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
                        (if model.game.playerSlots == 0 then
                            "∅"
                         else
                            toString model.game.playerSlots
                        )
                    ]
                , text " player game is "
                , span [ class "edGameStatus__chip--strong" ]
                    [ text <| toString model.game.status ]
                ]
                (case model.game.gameStart of
                    Nothing ->
                        [ text <| " round " ++ toString model.game.roundCount ]

                    Just timestamp ->
                        [ text " starting in "
                        , span [ class "edGameStatus__chip--strong" ]
                            [ text <| (toString (round <| (toFloat timestamp) - (inMilliseconds model.time / 1000))) ++ "s" ]
                        ]
                )
        ]
