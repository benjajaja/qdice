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
                    Debug.log ("Error in message: \"" ++ error ++ "\"") ( topic, message )
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
                        , if hasDuplexSubscribed clientId topic subscribed then
                            Cmd.batch
                                [ subscribe <| Tables model.game.table ClientDirection
                                , subscribe <| Tables model.game.table Broadcast
                                ]
                          else
                            case topic of
                                Tables table direction ->
                                    publish <| TableMsg table (Join "me")

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
                    model ! []

                Chat user text ->
                    (updateBackendChatLog model (List.append model.backend.chatLog [ LogChat user text ]))
                        -- model
                        !
                            []


updateBackendChatLog : Types.Model -> List ChatLogEntry -> Types.Model
updateBackendChatLog model chatLog =
    let
        backend =
            model.backend

        updated =
            { backend | chatLog = chatLog }
    in
        { model | backend = updated }


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
                            Debug.log "decoded OK" msg

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

        "Server" ->
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


hasDuplexSubscribed : String -> Topic -> List Topic -> Bool
hasDuplexSubscribed id topic subscribed =
    (topic == Client id || topic == AllClients)
        && subscribed
        == [ Client id, AllClients ]


port mqttConnect : String -> Cmd msg


publish : Msg -> Cmd msg
publish message =
    encodeTopicMessage message |> mqttPublish


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
