module State exposing (..)

import Types exposing (Model, Msg(..))
import Tables
import Backend


joinTable : Types.User -> Tables.Table -> Cmd Msg
joinTable user table =
    Cmd.map Types.BckMsg <| Backend.joinTable user table
