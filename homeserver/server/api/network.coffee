# NETWORK API
# -----------------------------------------------------------------------------
class Network extends (require "./baseApi.coffee")

    expresser = require "expresser"
    events = expresser.events
    logger = expresser.logger
    settings = expresser.settings
    utils = expresser.utils

    http = require "http"
    lodash = require "lodash"
    mdns = require "mdns"
    moment = require "moment"
    netPing = require "net-ping"

    # PROPERTIES
    # -------------------------------------------------------------------------

    # Local network discovery / browser.
    browser: null

    # Is it running on the expected local network, or remotely?
    isHome: false

    # Holds user ping status (online timestamp, otherwise null if offline).
    onlineUsers: {}

    # INIT
    # -------------------------------------------------------------------------

    # Init the Network module.
    init: =>
        @browser = mdns.createBrowser mdns.tcp("http")
        @browser.on "serviceUp", @onServiceUp
        @browser.on "serviceDown", @onServiceDown

        @data.local = {devices: []}

        @checkIP()
        @baseInit()

    # Start monitoring the network.
    start: =>
        @browser.start()
        @probe()
        @baseStart()

    # Stop monitoring the network.
    stop: =>
        @baseStop()
        @browser.stop()

    # GET NETWORK STATS
    # -------------------------------------------------------------------------

    # Check if Ayla server is on the home network.
    checkIP: =>
        if not settings.network?.home?
            logger.warn "Network.checkIP", "Home network settings are not defined. Skip!"
            return
        else
            logger.debug "Network.checkIP", "Expected home IP: #{settings.network.home.ip}"

        # Get and process current IP.
        ips = utils.getServerIP()
        ips = "0," + ips.join ","
        homeSubnet = settings.network.home.ip.substring 0, 7

        if ips.indexOf(",#{homeSubnet}") < 0
            @isHome = false
        else
            @isHome = true

        logger.info "Network.checkIP", ips, "isHome = #{@isHome}"

    # Check if the specified device / server / URL is up.
    checkDevice: (device) =>
        logger.debug "Network.checkDevice", device

        # Abort if device was found using mdns.
        return if device.mdns

        # Are addresses set?
        if not device.addresses?
            device.addresses = []
            device.addresses.push device.localIP

        # Not checked yet? Set `up` to false.
        device.up = false if not device.up?

        # Try connecting.
        req = http.get {host: device.localIP, port: device.localPort}, (response) ->
            response.addListener "data", (data) -> response.isValid = true
            response.addListener "end", -> device.up = true if response.isValid

        # On request error, set device as down.
        req.on "error", (err) ->

    # Probe the current network and check device statuses.
    probe: =>
        for nKey, nData of settings.network
            @data[nKey] = lodash.cloneDeep(nData) if not @data[nKey]?

            # Iterate network devices.
            if @data[nKey].devices?
                @checkDevice d for d in @data[nKey].devices

    # Return a list of devices marked as offline (up=false).
    getOfflineDevices: =>
        result = []

        # Iterate network devices.
        for sKey, sData of @data
            for d in sData.devices
                result.push d if not d.up

        return result

    # SERVICE DISCOVERY
    # -------------------------------------------------------------------------

    # When a new service is discovered on the network.
    onServiceUp: (service) =>
        logger.debug "Network.onServiceUp", service

        for sKey, sData of @data
            if sData.devices?
                existingDevice = lodash.find sData.devices, (d) ->
                    if service.adresses?
                        return service.addresses.indexOf(d.localIP) >= 0 and service.port is d.localPort
                    else
                        return false

        # Create new device or update existing?
        if not existingDevice?
            logger.info "Network.onServiceUp", "New", service.name, service.addresses, service.port
            existingDevice = {id: service.name}
            isNew = true
        else
            logger.info "Network.onServiceUp", "Existing", service.name, service.addresses, service.port
            isNew = false

        # Set device properties.
        existingDevice.host = service.host
        existingDevice.addresses = service.addresses
        existingDevice.up = true
        existingDevice.mdns = true

        @data.local.devices.push existingDevice if isNew

    # When a service disappears from the network.
    onServiceDown: (service) =>
        logger.info "Network.onServiceDown", service.name

        for sKey, sData of @data
            existingDevice = lodash.find sData.devices, (d) =>
                return service.addresses.indexOf d.localIP >= 0 and service.port is d.localPort

            if existingDevice?
                existingDevice.up = false
                existingDevice.mdns = false

    # CHECK USER MOBILES
    # -------------------------------------------------------------------------

    # Ping user mobile phones to check if they're online or offline,
    # based on ICMP ping via wifi network.
    pingMobiles: =>
        try
            session = netPing.createSession()
        catch ex
            @logError "Network.pingMobilres", ex
            return

        # Iterate all users to ping their mobiles.
        for k, user of settings.users
            do (k, user) =>
                session.pingHost user.mobileIP, (err, result) =>
                    eventStatus = null

                    if err?
                        eventStatus = "offline" if not @onlineUsers[k]?
                        @onlineUsers[k] = null
                    else
                        eventStatus = "online" if not @onlineUsers[k]?
                        @onlineUsers[k] = moment().unix()

                    # Emit event if status has changed.
                    if eventStatus?
                        events.emit "user.#{k}.#{eventStatus}"

    # JOBS
    # -------------------------------------------------------------------------

    # Keep probing network.
    jobProbe: =>
        @probe()

    # Ping mobile phones every few seconds.
    jobPingMobiles: =>
        @pingMobiles()


# Singleton implementation.
# -----------------------------------------------------------------------------
Network.getInstance = ->
    @instance = new Network() if not @instance?
    return @instance

module.exports = exports = Network.getInstance()