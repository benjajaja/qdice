module State exposing (joinTable)

import Backend
import Tables
import Types exposing (Model, Msg(..))


joinTable : Types.User -> Tables.Table -> Cmd Msg
joinTable user table =
    Cmd.map Types.BckMsg <| Backend.joinTable user table
