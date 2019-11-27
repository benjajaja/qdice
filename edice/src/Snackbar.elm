port module Snackbar exposing (toastError, toastMessage)

import Task
import Types exposing (Msg)
import Helpers exposing (consoleDebug)
import Json.Encode as E


toastError : String -> String -> Cmd Msg
toastError message debug =
    Cmd.batch
        [ toast <| E.object [ ( "text", E.string message ) ]
        , consoleDebug debug
        ]


toastMessage : String -> Int -> Cmd Msg
toastMessage message duration =
    toast <| E.object [ ( "text", E.string message ), ( "duration", E.int duration ) ]


port toast : E.Value -> Cmd msg
