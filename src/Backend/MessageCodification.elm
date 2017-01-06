module Backend.MessageCodification exposing (decodeTopicMessage, encodeTopic, encodeTopicMessage)

import Backend.Types exposing (..)
import Tables exposing (Table(..))
import Json.Decode as Dec exposing (..)
import Json.Encode as Enc exposing (..)


type alias ChatMessage =
    { username : String, message : String }


decodeTopicMessage : Topic -> String -> Result String Msg
decodeTopicMessage topic message =
    case topic of
        Client id ->
            Err "not implemented"

        AllClients ->
            case message of
                "present" ->
                    Ok <| AllClientsMsg PresentYourself

                _ ->
                    Err "not impl"

        Tables table direction ->
            decodeTableMessage table message

        -- Just <| TableMsg table <| Join "somebody"
        Presence ->
            Err "not impl"


decodeTableMessage : Table -> String -> Result String Msg
decodeTableMessage table message =
    case decodeString ("type" := Dec.string) message of
        Err err ->
            Err err

        Ok mtype ->
            case mtype of
                "chat" ->
                    case
                        decodeString
                            (object2 (,)
                                ("user" := Dec.string)
                                ("message" := Dec.string)
                            )
                            message
                    of
                        Ok chat ->
                            Ok (TableMsg table <| uncurry Chat <| chat)

                        Err err ->
                            Err err

                "join" ->
                    case decodeString ("user" := Dec.string) message of
                        Ok user ->
                            Ok <| TableMsg table <| Join user

                        Err err ->
                            Err err

                "leave" ->
                    case decodeString ("user" := Dec.string) message of
                        Ok user ->
                            Ok <| TableMsg table <| Leave user

                        Err err ->
                            Err err

                _ ->
                    Err <| "unknown type \"" ++ mtype ++ "\""


encodeTopicMessage : Msg -> ( String, String )
encodeTopicMessage msg =
    case msg of
        TableMsg table message ->
            ( encodeTopic <| Tables table Broadcast
            , encode 2 <|
                case message of
                    Chat user text ->
                        object
                            [ ( "type", Enc.string "chat" )
                            , ( "user", Enc.string user )
                            , ( "message", Enc.string text )
                            ]

                    Join user ->
                        object
                            [ ( "type", Enc.string "join" )
                            , ( "user", Enc.string user )
                            ]

                    Leave user ->
                        object
                            [ ( "type", Enc.string "leave" )
                            , ( "user", Enc.string user )
                            ]
            )

        _ ->
            Debug.crash <| "cannot send " ++ (toString msg)


encodeTopic : Topic -> String
encodeTopic topic =
    case topic of
        AllClients ->
            "clients"

        Client id ->
            "clients/" ++ id

        Presence ->
            "presence"

        Tables table direction ->
            "tables/" ++ (toString table) ++ "/" ++ (encodeDirection direction)


encodeDirection : TopicDirection -> String
encodeDirection direction =
    case direction of
        ClientDirection ->
            "clients"

        ServerDirection ->
            "server"

        Broadcast ->
            "broadcast"
