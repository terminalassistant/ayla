# BASE VIEW
# --------------------------------------------------------------------------
class BaseView

    # PROPERTIES
    # ----------------------------------------------------------------------

    # Holds view data.
    data: {}

    # MAIN METHODS
    # ----------------------------------------------------------------------

    # Init the view and set elements.
    init: =>
        @setElements()
        @setHeader()
        @setData()
        @bindSockets()

        # Call view `onReady` but only if present.
        @onReady() if @onReady?

        # Knockout.js bindings.
        ko.applyBindings @data if @data?

    # This will iterate over the `elements` property to create the dom cache
    # and set the main wrapper based on the `wrapperId` property. The list
    # is optional, and can be used to add elements after the page has loaded.
    setElements: (list) =>
        if not @dom?
            @dom = {}

            if @wrapperId
                @dom.wrapper = $ "#" + @wrapperId
            else
                @dom.wrapper = $ "#contents"

        # Set default elements if list is not provided.
        list = @elements if not list?

        return if not list?

        # Set elements cache.
        for s in list
            firstChar = s.substring 0, 1

            if firstChar is "#" or firstChar is "."
                domId = s.substring 1
            else
                domId = s

            @dom[domId] = @dom.wrapper.find s

    # Set active navigation and header properties.
    setHeader: =>
        $(document).foundation()

        currentPath = location.pathname.substring 1
        if currentPath isnt "/" and currentPath isnt ""
            $("nav").find(".#{currentPath}").addClass "active"

    # Create a KO compatible object based on the original `serverData` property.
    setData: (key, data) =>
        @data = {} if not @data?

        if not key?
            for k, v of ayla.serverData
                @dataProcessor k, v if @dataProcessor?
                @data[k] = ko.observable v
        else
            @dataProcessor key, data if @dataProcessor?

            if @data[key]?
                @data[key] data
            else
                @data[key] = ko.observable data

    # Helper to listen to socket events sent by the server. If no event name is
    # passed then use the view's default.
    bindSockets: =>
        @socketsName = "#{@wrapperId}Manager" if not @socketsName?

        # Listen to global sockets updates.
        ayla.sockets.on @socketsName + ".error", (err) => console.warn "ERROR!", err
        ayla.sockets.on @socketsName + ".result", (result) => console.warn "RESULT!", result
        ayla.sockets.on @socketsName + ".data", (key, data) => @onData key, data

    # DATA UPDATES
    # ----------------------------------------------------------------------

    # Updates data sent by the server.
    onData: (key, data) =>
        @setData key, data

# BIND BASE VIEW AND OPTIONS TO WINDOW
# --------------------------------------------------------------------------
window.ayla.BaseView = BaseView
window.ayla.optsDataDTables = {bAutoWidth: true, bInfo: false}
