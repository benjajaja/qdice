port module Backend exposing (addSubscribed, connect, desiredTable, init, mqttConnect, mqttOnConnect, mqttOnConnected, mqttOnMessage, mqttOnOffline, mqttOnReconnect, mqttOnSubscribed, mqttOnUnSubscribed, mqttSubscribe, mqttUnsubscribe, reset, setConnected, setStatus, subscribeGameTable, subscriptions, toRollLog, unsubscribeGameTable)

import Backend.HttpCommands exposing (loadMe)
import Backend.MessageCodification exposing (..)
import Backend.MqttCommands exposing (..)
import Backend.Types exposing (..)
import Game.Types exposing (PlayerAction(..), RollLog)
import Helpers exposing (consoleDebug, find, toDiesEmojis)
import Land exposing (Color(..))
import String
import Tables exposing (Table)
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


init : String -> Url -> Maybe String -> ( Model, Cmd Msg )
init version location token =
    let
        model : Backend.Types.Model
        model =
            { version = version
            , baseUrl = baseUrl location
            , jwt = token
            , status = Offline Nothing
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


setConnected : Types.Model -> String -> ( Types.Model, Cmd Msg )
setConnected model clientId =
    let
        backend =
            model.backend
    in
    ( { model | backend = { backend | status = Subscribing clientId ( ( False, False ), Nothing ) } }
    , Cmd.batch <|
        [ subscribe <| Client clientId
        , subscribe AllClients
        ]
            ++ (case desiredTable backend of
                    Just desired ->
                        [ subscribe <| Tables desired ClientDirection ]

                    Nothing ->
                        []
               )
    )


addSubscribed : Types.Model -> Topic -> ( Types.Model, Cmd Msg )
addSubscribed model topic =
    let
        backend =
            model.backend

        ( model_, cmd ) =
            case backend.status of
                Subscribing clientId ( ( client, all ), mTable ) ->
                    case topic of
                        AllClients ->
                            ( { model
                                | backend =
                                    { backend
                                        | status =
                                            if client then
                                                case mTable of
                                                    Just table ->
                                                        Online clientId table

                                                    Nothing ->
                                                        Subscribing clientId ( ( True, True ), mTable )

                                            else
                                                Subscribing clientId ( ( client, True ), mTable )
                                    }
                              }
                            , Cmd.none
                            )

                        Client _ ->
                            ( { model
                                | backend =
                                    { backend
                                        | status =
                                            if all then
                                                case mTable of
                                                    Just table ->
                                                        Online clientId table

                                                    Nothing ->
                                                        Subscribing clientId ( ( True, True ), mTable )

                                            else
                                                Subscribing clientId ( ( True, all ), mTable )
                                    }
                              }
                            , Cmd.none
                            )

                        Tables table _ ->
                            ( { model
                                | backend =
                                    { backend
                                        | status =
                                            if client && all then
                                                Online clientId table

                                            else
                                                Subscribing clientId ( ( client, all ), Just table )
                                    }
                              }
                            , case model.game.table of
                                Nothing ->
                                    consoleDebug <| "subscribed to table but game not in table: " ++ table

                                Just gameTable ->
                                    if table /= gameTable then
                                        consoleDebug <| "subscribed to table " ++ table ++ " but game is in another table: " ++ gameTable

                                    else
                                        Cmd.none
                            )

                Online _ _ ->
                    ( model, consoleDebug <| "subscribed to " ++ encodeTopic topic ++ " but already Online" )

                _ ->
                    ( model, consoleDebug <| "subscribed to " ++ encodeTopic topic ++ " while not subscribing" )
    in
    ( model_
    , case model_.backend.status of
        Online _ table ->
            case backend.status of
                Online _ _ ->
                    cmd

                _ ->
                    Cmd.batch
                        [ Backend.MqttCommands.enter model_.backend table
                        , cmd
                        ]

        _ ->
            cmd
    )


subscribeGameTable : Types.Model -> ( Table, Maybe Table ) -> ( Types.Model, Cmd Msg )
subscribeGameTable model ( table, oldTable ) =
    let
        backend =
            model.backend
    in
    case model.backend.status of
        Online clientId subscribedTable ->
            if subscribedTable == table then
                ( model, consoleDebug <| "already subscribed: " ++ table )

            else
                ( { model | backend = { backend | status = Subscribing clientId <| ( ( True, True ), Nothing ) } }
                , Cmd.batch
                    [ subscribe <| Tables table ClientDirection
                    , Maybe.map
                        (\old ->
                            if old /= table then
                                Cmd.batch
                                    [ exit model.backend old
                                    , unsubscribe <| Tables old ClientDirection
                                    , consoleDebug <| "exit " ++ table
                                    ]

                            else
                                consoleDebug <| "old same as new: " ++ table
                        )
                        oldTable
                        |> Maybe.withDefault Cmd.none
                    ]
                )

        Subscribing clientId ( ( client, all ), subscribedTable ) ->
            ( { model | backend = { backend | status = Subscribing clientId <| ( ( client, all ), Nothing ) } }
            , Cmd.batch
                [ subscribe <| Tables table ClientDirection
                , Maybe.map
                    (\old ->
                        if old /= table then
                            Cmd.batch
                                [ exit model.backend old
                                , unsubscribe <| Tables old ClientDirection
                                , consoleDebug <| "exit " ++ table
                                ]

                        else
                            consoleDebug <| "old same as new: " ++ table
                    )
                    oldTable
                    |> Maybe.withDefault Cmd.none
                ]
            )

        Connecting _ ->
            ( { model | backend = { backend | status = Connecting <| Just table } }
            , Cmd.none
            )

        Reconnecting count _ ->
            ( { model | backend = { backend | status = Reconnecting count <| Just table } }
            , consoleDebug "Subscribe to table: offline, setting desired table."
            )

        Offline _ ->
            ( { model | backend = { backend | status = Offline <| Just table } }
            , consoleDebug "Subscribe to table: offline, setting desired table."
            )


unsubscribeGameTable : Types.Model -> Table -> ( Types.Model, Cmd Msg )
unsubscribeGameTable model table =
    let
        backend =
            model.backend
    in
    case model.backend.status of
        Online clientId subscribedTable ->
            if subscribedTable == table then
                ( { model | backend = { backend | status = Subscribing clientId <| ( ( True, True ), Nothing ) } }
                , Cmd.batch
                    [ exit model.backend table
                    , unsubscribe <| Tables table ClientDirection
                    ]
                )

            else
                ( model, consoleDebug <| "not subscribed: " ++ table )

        Subscribing clientId ( ( client, all ), subscribedTable ) ->
            ( { model | backend = { backend | status = Subscribing clientId <| ( ( client, all ), Nothing ) } }
            , Cmd.batch
                [ exit model.backend table
                , unsubscribe <| Tables table ClientDirection
                ]
            )

        Connecting mTable ->
            case mTable of
                Just t ->
                    if t == table then
                        ( { model | backend = { backend | status = Connecting Nothing } }
                        , consoleDebug "Unubscribe from table: still connecting, unsetting desired table."
                        )

                    else
                        ( model, consoleDebug <| "unsubscribeGameTable mismatching table: " ++ table )

                Nothing ->
                    ( model, consoleDebug <| "unsubscribeGameTable mismatching table: " ++ table )

        Reconnecting _ mTable ->
            case mTable of
                Just t ->
                    if t == table then
                        ( { model | backend = { backend | status = Connecting Nothing } }
                        , consoleDebug "Unubscribe from table: still connecting, unsetting desired table."
                        )

                    else
                        ( model, consoleDebug <| "unsubscribeGameTable mismatching table: " ++ table )

                Nothing ->
                    ( model, consoleDebug <| "unsubscribeGameTable mismatching table: " ++ table )

        Offline mTable ->
            case mTable of
                Just t ->
                    if t == table then
                        ( { model | backend = { backend | status = Connecting Nothing } }
                        , consoleDebug "Unubscribe from table: still connecting, unsetting desired table."
                        )

                    else
                        ( model, consoleDebug <| "unsubscribeGameTable mismatching table: " ++ table )

                Nothing ->
                    ( model, consoleDebug <| "unsubscribeGameTable mismatching table: " ++ table )


subscriptions : Types.Model -> Sub Types.Msg
subscriptions model =
    Sub.batch
        [ mqttOnConnect StatusConnect
        , mqttOnReconnect StatusReconnect
        , mqttOnConnected Types.Connected
        , mqttOnSubscribed <| decodeSubscribed model.backend.status
        , mqttOnUnSubscribed <| decodeSubscribed model.backend.status
        , mqttOnMessage <| decodeMessage model.backend.status
        , mqttOnOffline StatusOffline
        , mqttOnError StatusError
        ]


decodeSubscribed : ConnectionStatus -> String -> Msg
decodeSubscribed status stringTopic =
    case decodeTopic status stringTopic of
        Ok topic ->
            Subscribed topic

        Err err ->
            UnknownTopicMessage "unknown topic" stringTopic err status


decodeMessage : ConnectionStatus -> ( String, String ) -> Msg
decodeMessage status ( stringTopic, message ) =
    case decodeTopic status stringTopic of
        Ok topic ->
            case decodeTopicMessage topic message of
                Ok msg ->
                    msg

                Err err ->
                    RuntimeError "Failed to parse an update" <| err ++ "/" ++ stringTopic ++ "/" ++ message

        Err err ->
            UnknownTopicMessage "unrecognized topic" stringTopic err status


decodeTopic : ConnectionStatus -> String -> Result String Topic
decodeTopic status string =
    if String.startsWith "tables/" string then
        let
            parts =
                String.split "/" string |> List.drop 1

            tableName =
                List.head parts

            direction =
                parts |> List.drop 1 |> List.head
        in
        Result.fromMaybe "no table part in topic" tableName
            |> Result.andThen
                (\table ->
                    Result.fromMaybe "no direction part in topic" direction
                        |> Result.andThen decodeDirection
                        |> Result.andThen (Ok << Tables table)
                )

    else
        case statusToClientId status of
            Just clientId ->
                if string == "clients/" ++ clientId then
                    Ok <| Client clientId

                else
                    case string of
                        "clients" ->
                            Ok AllClients

                        _ ->
                            Err <| "cannot match topic " ++ string

            Nothing ->
                Err <| "no client id yet"


statusToClientId : ConnectionStatus -> Maybe String
statusToClientId status =
    case status of
        Subscribing clientId _ ->
            Just clientId

        Online clientId _ ->
            Just clientId

        _ ->
            Nothing


setStatus : Types.Model -> ConnectionStatus -> Types.Model
setStatus model status =
    let
        backend =
            model.backend
    in
    { model | backend = { backend | status = status } }


reset : Types.Model -> (Maybe Table -> ConnectionStatus) -> Types.Model
reset model toStatus =
    let
        backend =
            model.backend
    in
    { model
        | backend =
            { backend
                | status = toStatus <| desiredTable backend
                , lastHeartbeat = millisToPosix 0
            }
    }


subscribe : Topic -> Cmd msg
subscribe =
    mqttSubscribe << encodeTopic


unsubscribe : Topic -> Cmd msg
unsubscribe =
    mqttUnsubscribe << encodeTopic


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


desiredTable : Model -> Maybe Table
desiredTable model =
    case model.status of
        Connecting table ->
            table

        Subscribing _ ( _, table ) ->
            table

        Online _ table ->
            Just table

        Offline table ->
            table

        Reconnecting _ table ->
            table
