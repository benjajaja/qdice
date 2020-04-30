port module Backend exposing (addSubscribed, baseUrl, connect, decodeMessage, decodeSubscribed, decodeTopic, hasDuplexSubscribed, hasSubscribedTable, init, mqttConnect, mqttOnConnect, mqttOnConnected, mqttOnMessage, mqttOnOffline, mqttOnReconnect, mqttOnSubscribed, mqttOnUnSubscribed, mqttSubscribe, mqttUnsubscribe, reset, setStatus, subscribe, subscribeGameTable, subscriptions, toDie, toDiesEmojis, toRollLog, unsubscribe, unsubscribeGameTable, updateConnected, updateSubscribed)

import Backend.HttpCommands exposing (loadMe)
import Backend.MessageCodification exposing (..)
import Backend.MqttCommands exposing (..)
import Backend.Types exposing (..)
import Game.Types exposing (PlayerAction(..), RollLog)
import Helpers exposing (consoleDebug, find)
import Land exposing (Color(..))
import String
import Tables exposing (Table)
import Task
import Time exposing (millisToPosix)
import Types exposing (Msg(..))
import Url exposing (Protocol(..), Url)


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


port mqttOnError : (String -> msg) -> Sub msg


connect : String -> Cmd msg
connect jwt =
    mqttConnect jwt


baseUrl : Url -> String
baseUrl location =
    case Maybe.withDefault 80 location.port_ of
        5000 ->
            "http://localhost:5001/api"

        _ ->
            case location.host of
                "localhost" ->
                    "/api"

                "nginx" ->
                    -- e2e tests
                    "/api"

                _ ->
                    "https://qdice.wtf/api"


init : String -> Url -> Maybe String -> Bool -> ( Model, Cmd Msg )
init version location token isTelegram =
    let
        model =
            { version = version
            , baseUrl = baseUrl location
            , jwt = token
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
    in
    ( model
    , case token of
        Just jwt ->
            Cmd.batch [ connect jwt, loadMe model ]

        Nothing ->
            connect ""
    )


updateConnected : Types.Model -> String -> ( Types.Model, Cmd Msg )
updateConnected model clientId =
    let
        backend =
            model.backend
    in
    ( setStatus { model | backend = { backend | clientId = Just clientId } } SubscribingGeneral
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
                        if not <| hasSubscribedTable subscribed table then
                            subscribeGameTable model_ ( table, Nothing )

                        else
                            ( model_, Cmd.none )

                    Nothing ->
                        ( model_, Cmd.none )

            else
                case topic of
                    AllClients ->
                        ( model_, Cmd.none )

                    Client _ ->
                        ( model_, Cmd.none )

                    Tables table _ ->
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
                                    ( setStatus model_ Online
                                    , Backend.MqttCommands.enter model.backend table
                                    )

                                else
                                    ( model_
                                    , Cmd.none
                                    )


subscribeGameTable : Types.Model -> ( Table, Maybe Table ) -> ( Types.Model, Cmd Msg )
subscribeGameTable model ( table, oldTable ) =
    if hasSubscribedTable model.backend.subscribed table then
        ( model, consoleDebug "ignoring already subbed" )

    else
        let
            ( model_, unsub ) =
                Maybe.map (\old -> unsubscribeGameTable model old) oldTable
                    |> Maybe.withDefault ( model, Cmd.none )
        in
        ( setStatus model_ SubscribingTable
        , Cmd.batch <|
            [ unsub
            , subscribe <| Tables table ClientDirection
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
        [ exit model.backend table
        , unsubscribe <| Tables table ClientDirection
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
        , mqttOnOffline StatusOffline
        , mqttOnError StatusError
        ]


decodeSubscribed : Maybe ClientId -> String -> Msg
decodeSubscribed clientId stringTopic =
    case clientId of
        Nothing ->
            UnknownTopicMessage "no client id yet" stringTopic "-" "null"

        Just clientId_ ->
            case decodeTopic clientId_ stringTopic of
                Just topic ->
                    Subscribed topic

                Nothing ->
                    UnknownTopicMessage "unknown topic" stringTopic "*subscribed" clientId_


decodeMessage : Maybe ClientId -> Maybe Table -> ( String, String ) -> Msg
decodeMessage clientId table ( stringTopic, message ) =
    case clientId of
        Nothing ->
            UnknownTopicMessage "no client id yet" stringTopic "-" "null"

        Just clientId_ ->
            case decodeTopic clientId_ stringTopic of
                Just topic ->
                    case decodeTopicMessage table topic message of
                        Ok msg ->
                            msg

                        Err err ->
                            RuntimeError "Failed to parse an update" <| err ++ "/" ++ stringTopic ++ "/" ++ message

                Nothing ->
                    UnknownTopicMessage "unrecognized topic" stringTopic message clientId_


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
        Maybe.andThen
            (\table ->
                Maybe.andThen decodeDirection direction
                    |> Maybe.andThen (Just << Tables table)
            )
            tableName

    else
        case string of
            "clients" ->
                Just AllClients

            _ ->
                Nothing


setStatus : Types.Model -> ConnectionStatus -> Types.Model
setStatus model status =
    let
        backend =
            model.backend
    in
    { model | backend = { backend | status = status } }


reset : Types.Model -> ConnectionStatus -> Types.Model
reset model status =
    let
        backend =
            model.backend
    in
    { model
        | backend =
            { backend
                | status = status
                , subscribed = []
                , lastHeartbeat = millisToPosix 0
            }
    }


hasDuplexSubscribed : List Topic -> List Topic -> Topic -> Bool
hasDuplexSubscribed topics subscribed topic =
    List.member topic topics
        && List.all ((\b a -> List.member a b) <| subscribed) topics


hasSubscribedTable : List Topic -> Table -> Bool
hasSubscribedTable subscribed table =
    List.member (Tables table ClientDirection) subscribed


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
            Maybe.andThen
                (\land ->
                    if land.color == Land.Neutral then
                        Just neutralPlayer

                    else
                        find (\p -> p.color == land.color) players
                )
                attackerLand

        defender =
            Maybe.andThen
                (\land ->
                    if land.color == Land.Neutral then
                        Just neutralPlayer

                    else
                        find (\p -> p.color == land.color) players
                )
                defenderLand

        success =
            List.sum roll.from.roll > List.sum roll.to.roll

        steal =
            if success then
                Helpers.tupleCombine ( defender, defenderLand )
                    |> Maybe.andThen
                        (\( player, land ) ->
                            Maybe.andThen (\_ -> Just <| land.points + player.reserveDice) land.capital
                        )

            else
                Nothing
    in
    { attacker = Maybe.withDefault errorPlayer attacker |> .name
    , attackerColor = Maybe.withDefault errorPlayer attacker |> .color
    , defender = Maybe.withDefault errorPlayer defender |> .name
    , defenderColor =
        Maybe.map .color defender
            |> Maybe.withDefault Black
            |> (\color ->
                    if color == Neutral then
                        Black

                    else
                        color
               )
    , attackRoll = List.sum roll.from.roll
    , attackDiesEmojis = toDiesEmojis roll.from.roll
    , attackDiceCount = List.length roll.from.roll
    , defendRoll = List.sum roll.to.roll
    , defendDiesEmojis = toDiesEmojis roll.to.roll
    , defendDiceCount = List.length roll.to.roll
    , success = success
    , steal = steal
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
