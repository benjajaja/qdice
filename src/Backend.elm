port module Backend exposing (..)

import Json.Encode exposing (..)
import String
import Backend.Types exposing (..)
import Types
import Tables exposing (Table(..))


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
                , if subscribed == [ Client, AllClients ] then
                    let
                        tableTopic =
                            "tables/" ++ toString model.game.table
                    in
                        Cmd.batch
                            [ mqttPublish ( "presence", encode 0 (object [ ( "id", string model.backend.clientId ), ( "status", string "connected" ) ]) )
                            , mqttSubscribe tableTopic
                            ]
                  else
                    case topic of
                        Tables table ->
                            mqttPublish ( "tables/" ++ toString table, "join" )

                        _ ->
                            Cmd.none
                )

        Message topic command ->
            case topic of
                AllClients ->
                    case command of
                        PresentYourself ->
                            ( model, mqttPublish ( "presence", encode 0 (object [ ( "id", string model.backend.clientId ), ( "status", string "connected" ) ]) ) )

                        _ ->
                            ( model, Cmd.none )

                Client ->
                    ( model, Cmd.none )

                Tables table ->
                    case command of
                        Join ->
                            let
                                _ =
                                    Debug.log "someone joined"
                            in
                                ( model, Cmd.none )

                        _ ->
                            ( model, Cmd.none )


subscriptions : Types.Model -> Sub Types.Msg
subscriptions model =
    Sub.batch
        [ mqttOnConnect (Connect >> Types.BckMsg)
        , mqttOnSubscribed (decodeTopic model.backend.clientId >> Subscribed >> Types.BckMsg)
        , mqttOnMessage (decodeMessage model.backend.clientId >> Types.BckMsg)
        ]


decodeMessage : ClientId -> ( String, String ) -> Msg
decodeMessage clientId ( stringTopic, message ) =
    let
        topic =
            (decodeTopic clientId stringTopic)
    in
        case topic of
            Client ->
                crashUnknownMessage stringTopic message

            AllClients ->
                case message of
                    "present" ->
                        Message topic PresentYourself

                    _ ->
                        crashUnknownMessage stringTopic message

            Tables table ->
                case message of
                    "join" ->
                        Message topic Join

                    _ ->
                        crashUnknownMessage stringTopic message


crashUnknownMessage : String -> String -> Msg
crashUnknownMessage topic message =
    Debug.crash <| "unknown message in topic \"" ++ topic ++ "\": " ++ message


decodeTopic : ClientId -> String -> Topic
decodeTopic clientId string =
    if string == "client_" ++ clientId then
        Client
    else
        case string of
            "clients" ->
                AllClients

            _ ->
                if String.startsWith "tables/" string then
                    Tables <| decodeTable <| String.dropLeft (String.length "tables/") string
                else
                    Debug.crash <| "Unknown topic: " ++ string


decodeTable : String -> Table
decodeTable name =
    case name of
        "Melchor" ->
            Melchor

        _ ->
            Debug.crash <| "unknown table: " ++ name


port mqttConnect : String -> Cmd msg


port mqttPublish : ( String, String ) -> Cmd msg


port mqttSubscribe : String -> Cmd msg


port mqttOnConnect : (String -> msg) -> Sub msg


port mqttOnSubscribed : (String -> msg) -> Sub msg


port mqttOnMessage : (( String, String ) -> msg) -> Sub msg
