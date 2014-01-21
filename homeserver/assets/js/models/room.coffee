# ROOM MODEL
# --------------------------------------------------------------------------
# Represents a room.
class RoomModel extends ayla.baseModel

    # CONSTRUCTOR AND PARSING
    # ----------------------------------------------------------------------

    # Construct a new room model.
    constructor: (@originalData) ->
        @temperature = ko.observable()
        @humidity = ko.observable()
        @pressure = ko.observable()
        @co2 = ko.observable()

        # Init model.
        @init @originalData


# EXPORTS
# --------------------------------------------------------------------------
 window.ayla.roomModel = RoomModel
