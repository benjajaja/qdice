port module Backend exposing (connect, init, update, subscriptions, publish)

import String
import Backend.Types exposing (..)
import Backend.MessageCodification exposing (..)
import Types
import Tables exposing (Table(..), decodeTable)


connect : Cmd msg
connect =
    mqttConnect ""


init : Model
init =
    { clientId = Nothing
    , subscribed = []
    , status = Offline
    , chatLog = []
    }


update : Msg -> Types.Model -> ( Types.Model, Cmd Types.Msg )
update msg model =
    case Debug.log "Backend Msg" msg of
        UnknownTopicMessage error topic message ->
            let
                _ =
                    Debug.log ("Error in message: \"" ++ error ++ "\"") topic
            in
                model ! []

        StatusConnect _ ->
            (setStatus Connecting model) ! []

        StatusReconnect attemptCount ->
            (setStatus (Reconnecting attemptCount) model) ! []

        StatusOffline _ ->
            (setStatus Offline model) ! []

        Connected clientId ->
            let
                backend =
                    model.backend
            in
                setStatus Online ({ model | backend = { backend | clientId = Just clientId } })
                    ! [ subscribe <| Client clientId
                      , subscribe AllClients
                      ]

        Subscribed topic ->
            case model.backend.clientId of
                Nothing ->
                    model ! []

                Just clientId ->
                    let
                        backend =
                            model.backend

                        subscribed =
                            topic :: backend.subscribed
                    in
                        ( { model | backend = { backend | subscribed = subscribed } }
                        , if
                            hasDuplexSubscribed
                                [ Client clientId
                                , AllClients
                                ]
                                subscribed
                                topic
                          then
                            Cmd.batch
                                [ subscribe <| Tables model.game.table ClientDirection
                                , subscribe <| Tables model.game.table ServerDirection
                                , subscribe <| Tables model.game.table Broadcast
                                ]
                          else
                            case topic of
                                Tables table direction ->
                                    if
                                        hasDuplexSubscribed
                                            [ Tables table ClientDirection
                                            , Tables table ServerDirection
                                            ]
                                            subscribed
                                            topic
                                    then
                                        publish <| TableMsg table <| Join <| Types.getUsername model
                                    else
                                        let
                                            _ =
                                                Debug.log "not duplex table yet" subscribed
                                        in
                                            Cmd.none

                                _ ->
                                    Cmd.none
                        )

        ClientMsg msg ->
            model ! []

        AllClientsMsg msg ->
            model ! []

        TableMsg table msg ->
            case msg of
                Join user ->
                    updateBackendChatLog model <| LogJoin user

                Leave user ->
                    updateBackendChatLog model <| LogLeave user

                Chat user text ->
                    updateBackendChatLog model <| LogChat user text


updateBackendChatLog : Types.Model -> ChatLogEntry -> ( Types.Model, Cmd Types.Msg )
updateBackendChatLog model entry =
    let
        backend =
            model.backend

        chatLog =
            List.append model.backend.chatLog [ entry ]

        updated =
            { backend | chatLog = chatLog }
    in
        { model | backend = updated } ! [ scrollChat model.game.chatBoxId ]


subscriptions : Types.Model -> Sub Types.Msg
subscriptions model =
    Sub.batch
        [ mqttOnConnect (StatusConnect >> Types.BckMsg)
        , mqttOnReconnect (StatusReconnect >> Types.BckMsg)
        , mqttOnConnected (Connected >> Types.BckMsg)
        , mqttOnSubscribed (decodeSubscribed model.backend.clientId >> Types.BckMsg)
        , mqttOnMessage (decodeMessage model.backend.clientId >> Types.BckMsg)
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


decodeMessage : Maybe ClientId -> ( String, String ) -> Msg
decodeMessage clientId ( stringTopic, message ) =
    case clientId of
        Nothing ->
            UnknownTopicMessage "no client id yet" stringTopic "-"

        Just clientId ->
            case decodeTopic clientId stringTopic of
                Just topic ->
                    case decodeTopicMessage topic message of
                        Ok msg ->
                            msg

                        Err err ->
                            UnknownTopicMessage err stringTopic message

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


port mqttConnect : String -> Cmd msg


publish : Msg -> Cmd msg
publish message =
    encodeTopicMessage message |> Debug.log "publish" |> mqttPublish


port mqttPublish : ( String, String ) -> Cmd msg


subscribe : Topic -> Cmd msg
subscribe topic =
    mqttSubscribe <| encodeTopic topic


port mqttSubscribe : String -> Cmd msg


port mqttOnConnect : (String -> msg) -> Sub msg


port mqttOnReconnect : (Int -> msg) -> Sub msg


port mqttOnOffline : (String -> msg) -> Sub msg


port mqttOnConnected : (String -> msg) -> Sub msg


port mqttOnSubscribed : (String -> msg) -> Sub msg


port mqttOnMessage : (( String, String ) -> msg) -> Sub msg


port scrollChat : String -> Cmd msg
