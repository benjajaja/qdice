port module Backend exposing (addSubscribed, baseUrl, connect, decodeDirection, decodeMessage, decodeSubscribed, decodeTopic, hasDuplexSubscribed, hasSubscribedTable, init, mqttConnect, mqttOnConnect, mqttOnConnected, mqttOnMessage, mqttOnOffline, mqttOnReconnect, mqttOnSubscribed, mqttOnUnSubscribed, mqttSubscribe, mqttUnsubscribe, onToken, setStatus, subscribe, subscribeGameTable, subscriptions, toDie, toDiesEmojis, toRollLog, unsubscribe, unsubscribeGameTable, updateConnected, updateSubscribed)

import Backend.MessageCodification exposing (..)
import Backend.MqttCommands exposing (..)
import Backend.Types exposing (..)
import Game.Types exposing (Player, PlayerAction(..), RollLog)
import Helpers exposing (find, consoleDebug)
import Land exposing (Color(..))
import Url exposing (Url, Protocol(..))
import String
import Tables exposing (Table)
import Types exposing (Msg(..))
import Time exposing (millisToPosix)
import Task


port onToken : (String -> msg) -> Sub msg


port mqttConnect : String -> Cmd msg


port mqttSubscribe : String -> Cmd msg


port mqttUnsubscribe : String -> Cmd msg


port mqttOnConnect : (String -> msg) -> Sub msg


port mqttOnReconnect : (Int -> msg) -> Sub msg


port mqttOnOffline : (String -> msg) -> Sub msg


port mqttOnConnected : (String -> msg) -> Sub msg


port mqttOnSubscribed : (String -> msg) -> Sub msg


port mqttOnUnSubscribed : (String -> msg) -> Sub msg


port mqttOnMessage : (( String, String ) -> msg) -> Sub msg


connect : Cmd msg
connect =
    mqttConnect ""


baseUrl : Url -> String
baseUrl location =
    if "localhost" == location.host || "lvh.me" == location.host then
        "http://localhost:5001"
    else
        let
            protocol =
                case location.protocol of
                    Https ->
                        "https"

                    Http ->
                        "http"
        in
            protocol ++ "://" ++ "api.qdice.wtf"


init : Url -> Bool -> ( Model, Cmd Msg )
init location isTelegram =
    ( { baseUrl = baseUrl location
      , jwt = Nothing
      , clientId = Nothing
      , subscribed = []
      , status = Offline
      , findTableTimeout =
            if isTelegram then
                2000
            else
                1000
      , lastHeartbeat = millisToPosix 0
      }
    , connect
    )


updateConnected : Types.Model -> String -> ( Types.Model, Cmd Msg )
updateConnected model clientId =
    let
        backend =
            model.backend
    in
        ( setStatus SubscribingGeneral { model | backend = { backend | clientId = Just clientId } }
        , Cmd.batch
            [ subscribe <| Client clientId
            , subscribe AllClients
            ]
        )


updateSubscribed : Types.Model -> Topic -> ( Types.Model, Cmd Msg )
updateSubscribed model topic =
    case model.backend.clientId of
        Nothing ->
            ( model
            , Cmd.none
            )

        Just clientId ->
            let
                model_ =
                    addSubscribed model topic

                subscribed =
                    model_.backend.subscribed

                hasSubscribedGeneral =
                    hasDuplexSubscribed
                        [ Client clientId
                        , AllClients
                        ]
                        subscribed
                        topic
            in
                if hasSubscribedGeneral then
                    case model_.game.table of
                        Just table ->
                            subscribeGameTable model_ table

                        Nothing ->
                            ( model_, Cmd.none )
                else
                    case topic of
                        Tables table direction ->
                            case model_.game.table of
                                Nothing ->
                                    ( model_
                                    , consoleDebug "subscribed to table but not in table"
                                    )

                                Just gameTable ->
                                    if table /= gameTable then
                                        ( model_
                                        , consoleDebug "subscribed to another table"
                                        )
                                    else if hasSubscribedTable subscribed table then
                                        ( setStatus Online model_
                                        , Task.succeed (EnterGame table)
                                            |> Task.perform identity
                                        )
                                    else
                                        ( model_
                                        , Cmd.none
                                        )

                        _ ->
                            ( model_
                            , Cmd.none
                            )


subscribeGameTable : Types.Model -> Table -> ( Types.Model, Cmd Msg )
subscribeGameTable model table =
    if hasSubscribedTable model.backend.subscribed table then
        ( model, consoleDebug "ignoring already subbed" )
    else
        ( setStatus SubscribingTable model
        , Cmd.batch <|
            [ subscribe <| Tables table ClientDirection
            , subscribe <| Tables table Broadcast
            ]
        )


unsubscribeGameTable : Types.Model -> Table -> ( Types.Model, Cmd Msg )
unsubscribeGameTable model table =
    let
        backend =
            model.backend

        subscribed =
            List.filter
                (\topic ->
                    case topic of
                        Tables t _ ->
                            t /= table

                        _ ->
                            True
                )
                backend.subscribed
    in
        ( { model | backend = { backend | subscribed = subscribed } }
        , Cmd.batch
            [ --publish <| TableMsg table <| Backend.Types.Leave <| Types.getUsername model
              exit model.backend table
            , unsubscribe <| Tables table ClientDirection
            , unsubscribe <| Tables table Broadcast
            ]
        )


addSubscribed : Types.Model -> Topic -> Types.Model
addSubscribed model topic =
    let
        backend =
            model.backend

        subscribed =
            topic :: backend.subscribed
    in
        { model | backend = { backend | subscribed = subscribed } }


subscriptions : Types.Model -> Sub Types.Msg
subscriptions model =
    Sub.batch
        [ mqttOnConnect StatusConnect
        , mqttOnReconnect StatusReconnect
        , mqttOnConnected Connected
        , mqttOnSubscribed <| decodeSubscribed model.backend.clientId
        , mqttOnUnSubscribed <| decodeSubscribed model.backend.clientId
        , mqttOnMessage <| decodeMessage model.backend.clientId <| model.game.table
        , onToken LoadToken
        ]


decodeSubscribed : Maybe ClientId -> String -> Msg
decodeSubscribed clientId stringTopic =
    case clientId of
        Nothing ->
            UnknownTopicMessage "no client id yet" stringTopic "-"

        Just clientId_ ->
            case decodeTopic clientId_ stringTopic of
                Just topic ->
                    Subscribed topic

                Nothing ->
                    UnknownTopicMessage "unknown topic" stringTopic "*subscribed"


decodeMessage : Maybe ClientId -> Maybe Table -> ( String, String ) -> Msg
decodeMessage clientId table ( stringTopic, message ) =
    case clientId of
        Nothing ->
            UnknownTopicMessage "no client id yet" stringTopic "-"

        Just clientId_ ->
            case decodeTopic clientId_ stringTopic of
                Just topic ->
                    case decodeTopicMessage table topic message of
                        Ok msg ->
                            msg

                        Err err ->
                            ErrorToast "Failed to parse an update" <| err ++ "/" ++ stringTopic ++ "/" ++ message

                Nothing ->
                    UnknownTopicMessage "unrecognized topic" stringTopic message


decodeTopic : ClientId -> String -> Maybe Topic
decodeTopic clientId string =
    if string == "clients/" ++ clientId then
        Just <| Client clientId
    else if String.startsWith "tables/" string then
        let
            parts =
                String.split "/" string |> List.drop 1

            tableName =
                List.head parts

            direction =
                parts |> List.drop 1 |> List.head
        in
            case tableName of
                Nothing ->
                    Nothing

                Just table ->
                    case direction of
                        Nothing ->
                            Nothing

                        Just direction1 ->
                            case decodeDirection direction1 of
                                Nothing ->
                                    Nothing

                                Just direction2 ->
                                    Just <| Tables table direction2
    else
        case string of
            "clients" ->
                Just AllClients

            _ ->
                --let
                --_ =
                --Debug.log "Cannot decode topic" string
                --in
                Nothing


decodeDirection : String -> Maybe TopicDirection
decodeDirection string =
    case string of
        "clients" ->
            Just ClientDirection

        "server" ->
            Just ServerDirection

        "broadcast" ->
            Just Broadcast

        _ ->
            Nothing


setStatus : ConnectionStatus -> Types.Model -> Types.Model
setStatus status model =
    let
        backend =
            model.backend
    in
        { model | backend = { backend | status = status } }


hasDuplexSubscribed : List Topic -> List Topic -> Topic -> Bool
hasDuplexSubscribed topics subscribed topic =
    List.member topic topics
        && List.all ((\b a -> List.member a b) <| subscribed) topics


hasSubscribedTable : List Topic -> Table -> Bool
hasSubscribedTable subscribed table =
    List.all
        (\direction ->
            List.member (Tables table direction) subscribed
        )
        [ ClientDirection
        , Broadcast
        ]


subscribe : Topic -> Cmd msg
subscribe topic =
    mqttSubscribe <| encodeTopic topic


unsubscribe : Topic -> Cmd msg
unsubscribe topic =
    mqttUnsubscribe <| encodeTopic topic


toRollLog : Types.Model -> Game.Types.Roll -> RollLog
toRollLog model roll =
    let
        lands =
            model.game.board.map.lands

        players =
            model.game.players

        attackerLand =
            find (\l -> l.emoji == roll.from.emoji) lands

        defenderLand =
            find (\l -> l.emoji == roll.to.emoji) lands

        neutralPlayer : Game.Types.Player
        neutralPlayer =
            Game.Types.makePlayer "Neutral"

        errorPlayer =
            Game.Types.makePlayer "(⚠ unknown player)"

        attacker =
            case attackerLand of
                Just land ->
                    if land.color == Land.Neutral then
                        Just neutralPlayer
                    else
                        find (\p -> p.color == land.color) players

                Nothing ->
                    Nothing

        defender =
            case defenderLand of
                Just land ->
                    if land.color == Land.Neutral then
                        Just neutralPlayer
                    else
                        find (\p -> p.color == land.color) players

                Nothing ->
                    Nothing
    in
        { attacker = Maybe.withDefault errorPlayer attacker |> .name
        , defender = Maybe.withDefault errorPlayer defender |> .name
        , attackRoll = List.sum roll.from.roll
        , attackDiesEmojis = toDiesEmojis roll.from.roll
        , attackDiceCount = List.length roll.from.roll
        , defendRoll = List.sum roll.to.roll
        , defendDiesEmojis = toDiesEmojis roll.to.roll
        , defendDiceCount = List.length roll.to.roll
        , success = List.sum roll.from.roll > List.sum roll.to.roll
        }


toDiesEmojis : List Int -> String
toDiesEmojis list =
    List.foldl (++) "" <| List.map toDie list


toDie : Int -> String
toDie face =
    case face of
        1 ->
            "⚀"

        2 ->
            "⚁"

        3 ->
            "⚂"

        4 ->
            "⚃"

        5 ->
            "⚄"

        6 ->
            "⚅"

        _ ->
            "🎲"
