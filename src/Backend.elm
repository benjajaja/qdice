port module Backend exposing (..)

import Json.Encode exposing (..)
import String
import Backend.Types exposing (..)
import Types
import Tables exposing (Table(..), decodeTable)


connect : Cmd msg
connect =
    mqttConnect "ws://localhost:8080"


init : Model
init =
    { clientId = ""
    , subscribed = []
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

        Connect clientId ->
            let
                backend =
                    model.backend
            in
                ( { model | backend = { backend | clientId = clientId } }
                , Cmd.batch
                    [ mqttSubscribe <| "client_" ++ clientId
                    , mqttSubscribe <| "clients"
                    ]
                )

        Subscribed topic ->
            let
                backend =
                    model.backend

                subscribed =
                    topic :: backend.subscribed
            in
                ( { model | backend = { backend | subscribed = subscribed } }
                , if hasDuplexSubscribed topic subscribed then
                    let
                        tableTopic =
                            "tables/" ++ toString model.game.table
                    in
                        Cmd.batch
                            [ mqttPublish ( "presence", "connected" )
                            , mqttSubscribe tableTopic
                            ]
                  else
                    case topic of
                        Tables table ->
                            mqttPublish ( "tables/" ++ toString table, "join" )

                        _ ->
                            Cmd.none
                )

        ClientMsg msg ->
            model ! []

        AllClientsMsg msg ->
            model ! []

        TableMsg table msg ->
            let
                _ =
                    case msg of
                        Join user ->
                            Debug.log "joined" user
            in
                model ! []


subscriptions : Types.Model -> Sub Types.Msg
subscriptions model =
    Sub.batch
        [ mqttOnConnect (Connect >> Types.BckMsg)
        , mqttOnSubscribed (decodeSubscribed model.backend.clientId >> Types.BckMsg)
        , mqttOnMessage (decodeMessage model.backend.clientId >> Types.BckMsg)
        ]


decodeSubscribed : ClientId -> String -> Msg
decodeSubscribed clientId stringTopic =
    case decodeTopic clientId stringTopic of
        Just topic ->
            Subscribed topic

        Nothing ->
            UnknownTopicMessage "unknown topic" stringTopic "*subscribed"


decodeMessage : ClientId -> ( String, String ) -> Msg
decodeMessage clientId ( stringTopic, message ) =
    case decodeTopic clientId stringTopic of
        Just topic ->
            case decodeTopicMessage topic message of
                Just msg ->
                    msg

                Nothing ->
                    UnknownTopicMessage "unrecognized message" stringTopic message

        Nothing ->
            UnknownTopicMessage "unrecognized topic" stringTopic message


decodeTopicMessage topic message =
    case topic of
        Client ->
            Nothing

        AllClients ->
            case message of
                "present" ->
                    Just <| AllClientsMsg PresentYourself

                _ ->
                    Nothing

        Tables table ->
            Just <| TableMsg Melchor <| Join "somebody"


decodeTopic : ClientId -> String -> Maybe Topic
decodeTopic clientId string =
    if string == "client_" ++ clientId then
        Just Client
    else
        case string of
            "clients" ->
                Just AllClients

            _ ->
                if String.startsWith "tables/" string then
                    Just <| Tables <| decodeTable <| String.dropLeft (String.length "tables/") string
                else
                    let
                        _ =
                            Debug.log "Cannot decode topic" string
                    in
                        Nothing


hasDuplexSubscribed : Topic -> List Topic -> Bool
hasDuplexSubscribed topic subscribed =
    (topic == Client || topic == AllClients)
        && subscribed
        == [ Client, AllClients ]


port mqttConnect : String -> Cmd msg


port mqttPublish : ( String, String ) -> Cmd msg


port mqttSubscribe : String -> Cmd msg


port mqttOnConnect : (String -> msg) -> Sub msg


port mqttOnSubscribed : (String -> msg) -> Sub msg


port mqttOnMessage : (( String, String ) -> msg) -> Sub msg
