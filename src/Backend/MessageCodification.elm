module Backend.MessageCodification exposing (..)

import Types exposing (Msg(..))
import Backend.Types exposing (..)
import Tables exposing (Table(..))
import Json.Decode as Dec exposing (..)
import Json.Encode as Enc exposing (..)
import Backend.Decoding exposing (..)
import Land exposing (Emoji)


type alias ChatMessage =
    { username : String, message : String }


decodeTopicMessage : Topic -> String -> Result String Msg
decodeTopicMessage topic message =
    case topic of
        Client id ->
            Err "not implemented"

        AllClients ->
            case decodeString (field "type" Dec.string) message of
                Err err ->
                    Err err

                Ok mtype ->
                    case mtype of
                        "tables" ->
                            case decodeString (field "payload" <| Dec.list tableInfoDecoder) message of
                                Ok tables ->
                                    Ok <| AllClientsMsg <| TablesInfo tables

                                Err err ->
                                    Err err

                        _ ->
                            Err <| "unknown type \"" ++ mtype ++ "\""

        Tables table direction ->
            decodeTableMessage table message


decodeTableMessage : Table -> String -> Result String Msg
decodeTableMessage table message =
    case decodeString (field "type" Dec.string) message of
        Err err ->
            Err err

        Ok mtype ->
            case mtype of
                "chat" ->
                    case
                        decodeString
                            (map2 (,)
                                (field "user" Dec.string)
                                (field "message" Dec.string)
                            )
                            message
                    of
                        Ok chat ->
                            Ok (TableMsg table <| uncurry Chat <| chat)

                        Err err ->
                            Err err

                "join" ->
                    case decodeString (field "user" Dec.string) message of
                        Ok user ->
                            Ok <| TableMsg table <| Join user

                        Err err ->
                            Err err

                "leave" ->
                    case decodeString (field "user" Dec.string) message of
                        Ok user ->
                            Ok <| TableMsg table <| Leave user

                        Err err ->
                            Err err

                "update" ->
                    case decodeString (field "payload" tableDecoder) message of
                        Ok update ->
                            Ok <| TableMsg table <| Update update

                        Err err ->
                            Err err

                "roll" ->
                    case decodeString (field "payload" rollDecoder) message of
                        Ok roll ->
                            Ok <| TableMsg table <| Roll roll

                        Err err ->
                            Err err

                "move" ->
                    case decodeString (field "payload" moveDecoder) message of
                        Ok move ->
                            Ok <| TableMsg table <| Move move

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

                    Update status ->
                        object
                            [ ( "type", Enc.string "status" )
                            ]

                    Roll status ->
                        object
                            [ ( "type", Enc.string "roll" )
                            ]

                    Move status ->
                        object
                            [ ( "type", Enc.string "move" )
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


attackEncoder : Emoji -> Emoji -> Enc.Value
attackEncoder from to =
    Enc.list [ Enc.string from, Enc.string to ]
