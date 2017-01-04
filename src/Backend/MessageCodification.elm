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


encodeTopicMessage : Msg -> ( String, String )
encodeTopicMessage msg =
    case msg of
        TableMsg table message ->
            ( encodeTopic <| Tables table Broadcast
            , encode 2 <|
                case message of
                    Chat user text ->
                        object
                            [ ( "user", Enc.string user )
                            , ( "message", Enc.string text )
                            ]

                    Join user ->
                        object [ ( "join", Enc.string user ) ]
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
