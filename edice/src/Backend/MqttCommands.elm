port module Backend.MqttCommands exposing (attack, enter, exit, leave, sendGameCommand)

import Backend.Encoding exposing (..)
import Backend.MessageCodification exposing (..)
import Backend.Types exposing (ClientId, Model, Topic(..), TopicDirection(..))
import Game.Types exposing (PlayerAction(..), actionToString)
import Helpers exposing (consoleDebug)
import Land exposing (Color(..))
import Snackbar exposing (toastError)
import Tables exposing (Table)
import Task
import Time
import Types exposing (Msg(..))


port mqttPublish : ( String, String ) -> Cmd msg


publish : Maybe String -> Maybe ClientId -> Table -> PlayerAction -> Cmd Msg
publish jwt clientId table action =
    case clientId of
        Just clientId_ ->
            case encodePlayerAction jwt clientId_ action of
                Ok playerAction ->
                    Cmd.batch
                        [ ( encodeTopic <|
                                Tables table ServerDirection
                          , playerAction
                          )
                            |> mqttPublish
                        , Task.perform SetLastHeartbeat Time.now
                        ]

                Err err ->
                    toastError ("Command error: " ++ err) err

        Nothing ->
            consoleDebug <| "attempted publish without clientId: " ++ actionToString action


sendGameCommand : Model -> Maybe Table -> PlayerAction -> Cmd Msg
sendGameCommand model table playerAction =
    case table of
        Just t ->
            publish model.jwt model.clientId t playerAction

        Nothing ->
            consoleDebug "sendGameCommand without table"


enter : Model -> Table -> Cmd Msg
enter model table =
    publish model.jwt model.clientId table Enter


exit : Model -> Table -> Cmd Msg
exit model table =
    publish model.jwt model.clientId table Exit


leave : Model -> Table -> Cmd Msg
leave model table =
    publish model.jwt model.clientId table Leave


attack : Model -> Table -> Land.Emoji -> Land.Emoji -> Cmd Msg
attack model table from to =
    publish model.jwt model.clientId table <| Attack from to
