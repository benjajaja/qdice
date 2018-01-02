port module Backend exposing (..)

import String
import Navigation exposing (Location)
import Json.Decode exposing (list, string)
import Task
import Backend.Types exposing (..)
import Backend.Decoding exposing (..)
import Backend.Encoding exposing (..)
import Backend.MessageCodification exposing (..)
import Backend.HttpCommands exposing (..)
import Backend.MqttCommands exposing (..)
import Types exposing (Msg(..))
import Tables exposing (Table(..), decodeTable)
import Game.Types exposing (Player, PlayerAction(..), RollLog)
import Land exposing (Color(..))
import Helpers exposing (find)


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


baseUrl : Location -> String
baseUrl location =
    if "localhost" == location.hostname || "lvh.me" == location.hostname then
        "http://localhost:5001"
    else
        location.protocol ++ "//" ++ "api." ++ location.hostname


init : Location -> Table -> ( Model, Cmd Msg )
init location table =
    ( { baseUrl = baseUrl location
      , jwt = Nothing
      , clientId = Nothing
      , subscribed = []
      , status = Offline
      }
    , connect
    )


updateConnected : Types.Model -> String -> ( Types.Model, Cmd Msg )
updateConnected model clientId =
    let
        backend =
            model.backend
    in
        setStatus SubscribingGeneral ({ model | backend = { backend | clientId = Just clientId } })
            ! [ subscribe <| Client clientId
              , subscribe AllClients
              ]


updateSubscribed : Types.Model -> Topic -> ( Types.Model, Cmd Msg )
updateSubscribed model topic =
    case model.backend.clientId of
        Nothing ->
            model ! []

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
                    subscribeGameTable model_ model_.game.table
                else
                    case topic of
                        Tables table direction ->
                            if table /= model_.game.table then
                                let
                                    _ =
                                        Debug.log "subscribed to another table"
                                in
                                    model_ ! []
                            else if hasSubscribedTable subscribed table then
                                setStatus Online model_
                                    ! [ --publish <| TableMsg table <| Backend.Types.Join <| Types.getUsername model_
                                        enter model.backend model_.game.table
                                      ]
                            else
                                model_ ! []

                        _ ->
                            model_ ! []


subscribeGameTable : Types.Model -> Table -> ( Types.Model, Cmd Msg )
subscribeGameTable model table =
    let
        _ =
            if hasSubscribedTable model.backend.subscribed table then
                Debug.log "already subscribed, subscribing again" model.game.table
            else
                table
    in
        setStatus SubscribingTable model
            ! [ subscribe <| Tables model.game.table ClientDirection
              , subscribe <| Tables model.game.table Broadcast
              ]


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
        { model | backend = { backend | subscribed = subscribed } }
            ! [ --publish <| TableMsg table <| Backend.Types.Leave <| Types.getUsername model
                exit model.backend table
              , unsubscribe <| Tables table ClientDirection
              , unsubscribe <| Tables table Broadcast
              ]


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
        , mqttOnMessage <| decodeMessage model.backend.clientId <| Just model.game.table
        , onToken LoadToken
        ]


decodeSubscribed : Maybe ClientId -> String -> Msg
decodeSubscribed clientId stringTopic =
    case clientId of
        Nothing ->
            UnknownTopicMessage "no client id yet" stringTopic "-"

        Just clientId ->
            case decodeTopic clientId stringTopic of
                Just topic ->
                    Subscribed topic

                Nothing ->
                    UnknownTopicMessage "unknown topic" stringTopic "*subscribed"


decodeMessage : Maybe ClientId -> Maybe Table -> ( String, String ) -> Msg
decodeMessage clientId table ( stringTopic, message ) =
    case clientId of
        Nothing ->
            UnknownTopicMessage "no client id yet" stringTopic "-"

        Just clientId ->
            case decodeTopic clientId stringTopic of
                Just topic ->
                    case decodeTopicMessage table topic message of
                        Ok msg ->
                            msg

                        Err err ->
                            let
                                _ =
                                    Debug.log "unknown message" <| UnknownTopicMessage err stringTopic message
                            in
                                ErrorToast "Failed to parse an update"

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

                Just tableName ->
                    case decodeTable tableName of
                        Nothing ->
                            Nothing

                        Just table ->
                            case direction of
                                Nothing ->
                                    Nothing

                                Just direction ->
                                    case decodeDirection direction of
                                        Nothing ->
                                            Nothing

                                        Just direction ->
                                            Just <| Tables table direction
    else
        case string of
            "clients" ->
                Just AllClients

            _ ->
                let
                    _ =
                        Debug.log "Cannot decode topic" string
                in
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
        && List.all (flip List.member <| subscribed) topics


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
