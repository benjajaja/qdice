port module Snackbar exposing (toastError, toastMessage)

import Helpers exposing (consoleDebug)
import Json.Encode as E
import Types exposing (Msg)


toastError : String -> String -> Cmd Msg
toastError message debug =
    Cmd.batch
        [ toast <| E.object [ ( "text", E.string message ) ]
        , consoleDebug debug
        ]


toastMessage : String -> Maybe Int -> Cmd Msg
toastMessage message duration =
    Cmd.batch
        [ toast <|
            E.object
                [ ( "text", E.string message )
                , ( "duration"
                  , case duration of
                        Just ms ->
                            E.int ms

                        Nothing ->
                            E.null
                  )
                ]
        , consoleDebug message
        ]


port toast : E.Value -> Cmd msg
