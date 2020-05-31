module Awards exposing (awardsShortList)

import Game.Types exposing (Award)
import Html exposing (..)
import Html.Attributes exposing (..)
import Ordinal exposing (ordinal)
import Svg exposing (svg, use)
import Svg.Attributes
import Types exposing (Msg(..))


awardsShortList : Int -> List Award -> List (Html Msg)
awardsShortList size awards =
    if List.length awards > 0 then
        List.map (awardIcon size) awards

    else
        []


awardIcon : Int -> Award -> Html Msg
awardIcon size award =
    svg
        [ Svg.Attributes.viewBox "0 0 100 100"
        , Svg.Attributes.fill "currentColor"
        , Svg.Attributes.width <| String.fromInt size
        , Svg.Attributes.height <| String.fromInt size

        -- , Svg.Attributes.style "background:white;border-radius:50%; color: black"
        ]
    <|
        [ Svg.use
            [ Svg.Attributes.xlinkHref <| "assets/awards.svg#" ++ awardSvgId award
            , Svg.Attributes.fill <| awardFill award
            ]
            [ Svg.title [] [ Svg.text <| awardTitle award ]
            ]
        ]
            ++ awardText award


awardFill : Award -> String
awardFill award =
    case award.type_ of
        "monthly_rank" ->
            case award.position of
                1 ->
                    "goldenrod"

                2 ->
                    "silver"

                3 ->
                    "bronze"

                _ ->
                    "darkgrey"

        "weekly_rank" ->
            "#cccccc"

        _ ->
            "#222222"


awardSvgId : Award -> String
awardSvgId award =
    case award.type_ of
        "monthly_rank" ->
            "laurel"

        "weekly_rank" ->
            "box_golden_round"

        "early_adopter" ->
            "lander"

        _ ->
            ""


awardText : Award -> List (Html Msg)
awardText award =
    if award.type_ == "monthly_rank" || award.type_ == "weekly_rank" then
        [ Svg.text_
            [ Svg.Attributes.x "50%"
            , Svg.Attributes.y "50%"
            , Svg.Attributes.textAnchor "middle"
            , Svg.Attributes.dominantBaseline "middle"
            , Svg.Attributes.fontSize "4em"
            ]
            [ Svg.text <| String.fromInt <| award.position
            ]
        ]

    else
        []


awardTitle : Award -> String
awardTitle award =
    case award.type_ of
        "early_adopter" ->
            "Early Adopter 💝"

        "monthly_rank" ->
            "Monthly rank: " ++ ordinal award.position

        "weekly_rank" ->
            "Weekly rank"
                ++ (case award.table of
                        Just table ->
                            " on table " ++ table

                        Nothing ->
                            ""
                   )
                ++ ": "
                ++ ordinal award.position

        _ ->
            "???"
