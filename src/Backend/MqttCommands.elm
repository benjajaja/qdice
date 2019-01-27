port module Backend.MqttCommands exposing (attack, enter, exit, gameCommand, leave, mqttPublish, publish)

import Backend.Encoding exposing (..)
import Backend.MessageCodification exposing (..)
import Backend.Types exposing (ClientId, Model, Topic(..), TopicDirection(..))
import Game.Types exposing (Player, PlayerAction(..))
import Land exposing (Color(..))
import Snackbar exposing (toastCmd)
import Tables exposing (Table)
import Task
import Time
import Types exposing (Msg(..))


port mqttPublish : ( String, String ) -> Cmd msg


publish : Maybe String -> Maybe ClientId -> Table -> PlayerAction -> Cmd Msg
publish jwt clientId table action =
    case clientId of
        Just clientId_ ->
            Cmd.batch
                [ ( encodeTopic <|
                        Tables table ServerDirection
                  , encodePlayerAction jwt clientId_ action
                  )
                    |> mqttPublish
                , Task.perform SetLastHeartbeat Time.now
                ]

        Nothing ->
            toastCmd "Command error: not connected"


gameCommand : Model -> Table -> PlayerAction -> Cmd Msg
gameCommand model table playerAction =
    publish model.jwt model.clientId table playerAction


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
