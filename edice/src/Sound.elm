port module Sound exposing (..)
import Types exposing (SessionPreferences)
import Types exposing (Msg)
import Types exposing (SoundPreference(..))

type Sound
  = Kick
  | RollSuccessPlayer
  | RollSuccess
  | RollDefeat
  | Start
  | Finish
  | Turn
  | GiveDice


playSound : SessionPreferences -> Sound -> Cmd Msg
playSound preferences sound =
    case preferences.sound of
        Mute -> Cmd.none
        Notify -> if isNotify sound then
                playSoundToString sound
            else
                Cmd.none

        _ -> playSoundToString sound

isNotify : Sound -> Bool
isNotify sound =
  List.member sound [Start, Turn]

playSoundToString : Sound -> Cmd msg
playSoundToString sound =
  let
      str = case sound of
          Kick -> "kick"
          RollSuccessPlayer -> "rollSuccessPlayer"
          RollSuccess -> "rollSuccess"
          RollDefeat -> "rollDefeat"
          Start -> "start"
          Finish -> "finish"
          Turn -> "turn"
          GiveDice -> "giveDice"
  in
    playSoundString str

port playSoundString : String -> Cmd msg


