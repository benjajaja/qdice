port module Backend.MqttCommands exposing (attack, enter, exit, leave, sendGameCommand)

import Backend.Encoding exposing (..)
import Backend.MessageCodification exposing (..)
import Backend.Types exposing (ConnectionStatus(..), Model, Topic(..), TopicDirection(..))
import Game.Types exposing (PlayerAction(..), actionToString)
import Helpers exposing (consoleDebug)
import Land exposing (Color(..))
import Snackbar exposing (toastError)
import Tables exposing (Table)
import Task
import Time
import Types exposing (Msg(..))


port mqttPublish : ( String, String ) -> Cmd msg


publish : Maybe String -> ConnectionStatus -> Table -> PlayerAction -> Cmd Msg
publish jwt status table action =
    case status of
        Online clientId t ->
            case encodePlayerAction jwt clientId action of
                Ok playerAction ->
                    Cmd.batch <|
                        [ ( encodeTopic <|
                                Tables table ServerDirection
                          , playerAction
                          )
                            |> mqttPublish
                        , Task.perform SetLastHeartbeat Time.now
                        ]
                            ++ (if t /= table then
                                    [ consoleDebug <| "Warning: not subscribed but publish to table " ++ t ++ " (" ++ actionToString action ++ ")" ]

                                else
                                    []
                               )

                Err err ->
                    toastError ("Command error: " ++ err) err

        _ ->
            consoleDebug <| "publish but not online: " ++ actionToString action


sendGameCommand : Model -> Maybe Table -> PlayerAction -> Cmd Msg
sendGameCommand model table playerAction =
    case table of
        Just t ->
            publish model.jwt model.status t playerAction

        Nothing ->
            consoleDebug "sendGameCommand without table"


enter : Model -> Table -> Cmd Msg
enter model table =
    publish model.jwt model.status table Enter


exit : Model -> Table -> Cmd Msg
exit model table =
    publish model.jwt model.status table Exit


leave : Model -> Table -> Cmd Msg
leave model table =
    publish model.jwt model.status table Leave


attack : Model -> Table -> Land.Emoji -> Land.Emoji -> Cmd Msg
attack model table from to =
    publish model.jwt model.status table <| Attack from to
