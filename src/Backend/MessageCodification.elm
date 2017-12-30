module Backend.MessageCodification exposing (..)

import Types exposing (Msg(..))
import Backend.Types exposing (..)
import Tables exposing (Table(..))
import Game.Types
import Json.Decode as Dec exposing (..)
import Json.Encode as Enc exposing (..)
import Backend.Decoding exposing (..)
import Land exposing (Emoji)


type alias ChatMessage =
    { username : String, message : String }


{-| Maybe Table because it might be a table message for this client only
-}
decodeTopicMessage : Maybe Table -> Topic -> String -> Result String Msg
decodeTopicMessage table topic message =
    case topic of
        Client id ->
            case table of
                Just table ->
                    decodeTableMessage table message

                Nothing ->
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
                            Err <| "unknown global message type \"" ++ mtype ++ "\""

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
                            (field "payload"
                                (map2 (,)
                                    (field "user" (Dec.nullable Dec.string))
                                    (field "message" Dec.string)
                                )
                            )
                            message
                    of
                        Ok chat ->
                            Ok (TableMsg table <| uncurry Chat <| chat)

                        Err err ->
                            Err err

                "enter" ->
                    case decodeString (field "payload" Dec.string) message of
                        Ok user ->
                            Ok <| TableMsg table <| Join <| Just user

                        Err err ->
                            Ok <| TableMsg table <| Join Nothing

                "exit" ->
                    case decodeString (field "payload" Dec.string) message of
                        Ok user ->
                            Ok <| TableMsg table <| Leave <| Just user

                        Err err ->
                            Ok <| TableMsg table <| Leave Nothing

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

                "elimination" ->
                    case decodeString (field "payload" eliminationDecoder) message of
                        Ok elimination ->
                            Ok <| TableMsg table <| Elimination elimination

                        Err err ->
                            Err err

                "error" ->
                    case decodeString (field "payload" Dec.string) message of
                        Ok error ->
                            Ok <| TableMsg table <| Error error

                        Err err ->
                            Ok <| TableMsg table <| Error <| "💣"

                _ ->
                    Err <| "unknown table message type \"" ++ mtype ++ "\""


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
