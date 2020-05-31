module LeaderBoard.Chart exposing (view)

import Board.Colors
import Color.Manipulate as Manipulate
import Game.Types exposing (Msg(..))
import Html exposing (..)
import Html.Attributes exposing (class)
import Land
import LeaderBoard.ChartTypes exposing (..)
import LineChart
import LineChart.Area as Area
import LineChart.Axis as Axis
import LineChart.Axis.Intersection as Intersection
import LineChart.Axis.Line as AxisLine
import LineChart.Axis.Range as Range
import LineChart.Axis.Tick as Tick
import LineChart.Axis.Ticks as Ticks
import LineChart.Axis.Title as Title
import LineChart.Colors as Colors
import LineChart.Container as Container
import LineChart.Dots as Dots
import LineChart.Events as Events
import LineChart.Grid as Grid
import LineChart.Interpolation as Interpolation
import LineChart.Junk as Junk
import LineChart.Legends as Legends
import LineChart.Line as Line
import Svg


view : List ( PlayerRef, List Datum ) -> Maybe Datum -> Html Msg
view days hinted =
    div [ class "edLeaderboardChart" ]
        [ LineChart.viewCustom (chartConfig hinted) <|
            List.indexedMap
                (\i ( ref, datums ) ->
                    LineChart.line
                        (i + 1 |> Land.playerColor |> Board.Colors.base)
                        Dots.circle
                        ref.name
                        datums
                )
            <|
                days
        ]


chartConfig : Maybe Datum -> LineChart.Config Datum Msg
chartConfig hinted =
    { y = yAxisConfig
    , x = xAxisConfig
    , container = containerConfig
    , interpolation = Interpolation.monotone
    , intersection = Intersection.default
    , legends = Legends.default
    , events = eventsConfig
    , junk = Junk.default
    , grid = Grid.default
    , area = Area.default
    , line = lineConfig hinted
    , dots = Dots.custom (Dots.disconnected 4 2)
    }



-- CHART CONFIG / AXES


yAxisConfig : Axis.Config Datum Msg
yAxisConfig =
    Axis.custom
        { title = Title.atDataMax -10 -10 "Score"
        , variable = Just << toFloat << .score
        , pixels = 250
        , range = Range.padded 20 20
        , axisLine = AxisLine.rangeFrame Colors.gray
        , ticks =
            Ticks.default

        -- Ticks.custom <|
        -- \dataRange axisRange ->
        -- [ tickRain ( dataRange.min, "bits" )
        -- , tickRain ( middle dataRange, "some" )
        -- , tickRain ( dataRange.max, "lots" )
        -- ]
        }


xAxisConfig : Axis.Config Datum msg
xAxisConfig =
    let
        ticks : Ticks.Config msg
        ticks =
            Ticks.intCustom 7 tickTime
    in
    Axis.custom
        { title = Title.default "Weekday"
        , variable = Just << toFloat << .time
        , pixels = 426
        , range = Range.padded 20 20
        , axisLine = AxisLine.none
        , ticks = ticks
        }



-- CHART CONFIG / AXES / TICKS


tickTime : Int -> Tick.Config msg
tickTime i =
    Tick.custom
        { position = toFloat i
        , color = Colors.gray
        , width = 1
        , length = 7
        , grid = True
        , direction = Tick.positive
        , label =
            Just
                (tickLabel <|
                    case i of
                        0 ->
                            "Mon"

                        1 ->
                            "Tue"

                        2 ->
                            "Wed"

                        3 ->
                            "Thu"

                        4 ->
                            "Fri"

                        5 ->
                            "Sat"

                        6 ->
                            "Sun"

                        _ ->
                            "Err"
                )
        }


tickLabel : String -> Svg.Svg msg
tickLabel =
    Junk.label Colors.black



-- CHART CONFIG / CONTIANER


containerConfig : Container.Config Msg
containerConfig =
    Container.custom
        { attributesHtml = []
        , attributesSvg = []
        , size = Container.relative
        , margin = Container.Margin 10 140 10 70
        , id = "line-chart-lines"
        }



-- CHART CONFIG / EVENTS


eventsConfig : Events.Config Datum Game.Types.Msg
eventsConfig =
    Events.custom
        [ Events.onMouseMove Hint Events.getNearest
        , Events.onMouseLeave (Hint Nothing)
        ]



-- CHART CONFIG / LINE


lineConfig : Maybe Datum -> Line.Config Datum
lineConfig maybeHovered =
    Line.custom (toLineStyle maybeHovered)


toLineStyle : Maybe Datum -> List Datum -> Line.Style
toLineStyle maybeHovered lineData =
    case maybeHovered of
        Nothing ->
            Line.style 1 identity

        Just hovered ->
            if List.any ((==) hovered) lineData then
                Line.style 2 identity

            else
                Line.style 1 Manipulate.grayscale
