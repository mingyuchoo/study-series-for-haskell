module Todo exposing (Priority(..), Status(..), Todo, nextPriority, nextStatus, priorities, priorityName, statusName, statuses)


type Priority
    = Low
    | Medium
    | High


type Status
    = Pending
    | Doing
    | Done


type alias Todo =
    { id : Int
    , title : String
    , createdAt : String
    , priority : Priority
    , status : Status
    }


priorities : List Priority
priorities =
    [ Low, Medium, High ]


statuses : List Status
statuses =
    [ Pending, Doing, Done ]


priorityName : Priority -> String
priorityName priority =
    case priority of
        Low ->
            "Low"

        Medium ->
            "Medium"

        High ->
            "High"


statusName : Status -> String
statusName status =
    case status of
        Pending ->
            "Todo"

        Doing ->
            "Doing"

        Done ->
            "Done"


nextPriority : Priority -> Priority
nextPriority priority =
    case priority of
        Low ->
            Medium

        Medium ->
            High

        High ->
            Low


nextStatus : Status -> Status
nextStatus status =
    case status of
        Pending ->
            Doing

        Doing ->
            Done

        Done ->
            Pending
