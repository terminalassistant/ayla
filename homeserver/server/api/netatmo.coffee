# NETATMO API
# -----------------------------------------------------------------------------
# Collect weather and climate data from Netatmo devices. Supports indoor and
# outdoor modules, and device list is fetched via the getDevices method.
# # More info at http://dev.netatmo.com
class Netatmo extends (require "./baseApi.coffee")

    expresser = require "expresser"
    logger = expresser.logger
    settings = expresser.settings

    lodash = expresser.libs.lodash
    moment = expresser.libs.moment
    querystring = require "querystring"

    # INIT
    # -------------------------------------------------------------------------

    # Netatmo init.
    init: ->
        @baseInit()

    # Start collecting weather data. If OAuth is fine, get devlice list straight away.
    start: =>
        @oauthInit (err, result) =>
            if err?
                @logError "Netatmo.start", err
            else
                @baseStart()
                if settings.modules.getDataOnStart
                    @getDevices (err, result) =>
                        if not err?
                            @getIndoor()
                            @getOutdoor()

    # Stop collecting weather data.
    stop: =>
        @baseStop()

    # API BASE METHODS
    # -------------------------------------------------------------------------

    # Helper to get a formatted result.
    getResultBody = (result, params) ->
        arr = []
        types = params.type.split ","

        # Iterate result body and create the formatted object.
        for key, value of result.body
            f = {timestamp: key}
            i = 0

            # Iterate each type to set formatted value.
            for t in types
                f[t.toLowerCase()] = value[i]
                i++

            # Push to the final array.
            arr.push f

        # Return formatted array.
        return arr

    # Make a request to the Netatmo API.
    apiRequest: (path, params, callback) =>
        if lodash.isFunction params
            callback = params
            params = null

        if not @isRunning [@oauth.client]
            callback "Module not running or OAuth client not ready. Please check Netatmo API settings." if callback?
            return

        # Set default parameters and request URL.
        reqUrl = settings.netatmo.api.url + path + "?"
        params = {} if not params?
        params.optimize = false

        # Add parameters to request URL.
        reqUrl += querystring.stringify params

        logger.debug "Netatmo.apiRequest", reqUrl

        # Make request using OAuth. Force parse err and result as JSON.
        @oauth.get reqUrl, (err, result) =>
            result = JSON.parse result if result? and lodash.isString result
            err = JSON.parse err if err? and lodash.isString err
            callback err, result if callback?

    # Helper to get API request parameters based on the passed filter.
    # Sets default end date to now and scale to 30 minutes.
    getParams: (filter) =>
        filter = {} if not filter?

        params = {}
        params["date_begin"] = filter.startDate or filter.date_begin or null
        params["date_end"] = filter.endDate or filter.date_end or "last"
        params["scale"] = filter.scale or "30min"
        params["module_id"] = filter.moduleId or filter.module_id or null
        params["device_id"] = filter.deviceId or filter.device_id or @data.devices[0].value[0]["_id"]

        return params

    # GET DATA
    # -------------------------------------------------------------------------

    # Get device and related modules from Netatmo.
    getDevices: (callback) =>
        params =  {app_type: "app_station"}

        @apiRequest "devicelist", params, (err, result) =>
            if err?
                @logError "Netatmo.getDevices", err
            else
                deviceData = result.body.devices

                # Merge devices and modules results.
                for d in deviceData
                    d.modules = lodash.filter result.body.modules, {"main_device": d["_id"]}

                @setData "devices", deviceData
                logger.info "Netatmo.getDevices", "Got #{result.body.devices.length} devices, #{result.body.modules.length} modules."

            callback err, result if callback?

    # Get outdoor readings from Netatmo. A moduleId must be set on the filter.
    getOutdoor: (filter, callback) =>
        if lodash.isFunction filter
            callback = filter
            filter = null

        # Set outdoor parameters.
        params = @getParams filter
        params["type"] = "Temperature,Humidity"

        # Module ID is mandatory!
        if not params["module_id"]?
            callback "A valid outdoor moduleId is mandatory."
            return

        # Make the request for outdoor readings.
        @apiRequest "getmeasure", params, (err, result) =>
            if err?
                @logError "Netatmo.getOutdoor", filter, err
            else
                body = getResultBody result, params
                @setData "outdoor", body, filter
                logger.info "Netatmo.getOutdoor", filter, body

            callback err, result if callback?

    # Get current conditions for all outdoor modules (module type NAModule1).
    getAllOutdoor: =>
        if not @data.devices?
            logger.warn "Netatmo.getAllOutdoor", "No devices found, please check the Netamo API settings."
            return

        # Iterate and get data for all outdoor modules.
        for d in @data.devices[0].value
            modules = lodash.filter d.modules, {type: "NAModule1"}
            @getOutdoor {device_id: d["_id"], module_id: m["_id"]} for m in modules

    # Get indoor readings from Netatmo. Default is to get only the most current data.
    getIndoor: (filter, callback) =>
        if lodash.isFunction filter
            callback = filter
            filter = null

        # Set indoor parameters.
        params = @getParams filter
        params["type"] = "Temperature,Humidity,Pressure,CO2,Noise"

        # Make the request for indoor readings.
        @apiRequest "getmeasure", params, (err, result) =>
            if err?
                @logError "Netatmo.getIndoor", filter, err
            else
                body = getResultBody result, params
                @setData "indoor", body, filter
                logger.info "Netatmo.getIndoor", filter, body

            callback err, result if callback?

    # Get current conditions for all indoor modules (module type NAModule4).
    getAllIndoor: =>
        if not @data.devices?
            logger.warn "Netatmo.getAllIndoor", "No devices found, please check the Netamo API settings."
            return

        # Iterate and get data for all indoor modules.
        for d in @data.devices[0].value
            @getIndoor {device_id: d["_id"]}
            modules = lodash.filter d.modules, {type: "NAModule4"}
            @getIndoor {device_id: d["_id"], module_id: m["_id"]} for m in modules


# Singleton implementation.
# -----------------------------------------------------------------------------
Netatmo.getInstance = ->
    @instance = new Netatmo() if not @instance?
    return @instance

module.exports = exports = Netatmo.getInstance()