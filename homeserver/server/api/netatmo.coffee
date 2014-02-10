# NETATMO API
# -----------------------------------------------------------------------------
# Module to collect weather data from Netatmo devices.
# More info at www.netatmo.com.
class Netatmo extends (require "./baseApi.coffee")

    expresser = require "expresser"
    database = expresser.database
    logger = expresser.logger
    settings = expresser.settings

    async = expresser.libs.async
    lodash = expresser.libs.lodash
    moment = expresser.libs.moment
    querystring = require "querystring"

    # PROPERTIES
    # -------------------------------------------------------------------------

    # Stores the current indoor and outdoor readings.
    currentReadings: {}

    # INIT
    # -------------------------------------------------------------------------

    # Init the Netatmo module.
    init: =>
        @baseInit()

    # Start collecting weather data.
    start: =>
        @oauthInit (err, result) =>
            if not err?
                @getIndoor()
                @getOutdoor()

        @baseStart()

    # Stop collecting weather data.
    stop: =>
        @baseStop()

    # API BASE METHODS
    # -------------------------------------------------------------------------

    # Make a request to the Netatmo API.
    makeRequest: (path, params, callback) =>
        if not @oauth.client?
            callback "OAuth client is not ready. Please check Fitbit API settings." if callback?
            return

        if not callback? and lodash.isFunction params
            callback = params
            params = null

        # Set default parameters and request URL.
        reqUrl = settings.netatmo.api.url + path + "?"
        params = {} if not params?
        params.optimize = false

        # Add parameters to request URL.
        reqUrl += querystring.stringify params

        logger.debug "Netatmo.makeRequest", reqUrl

        # Make request using OAuth. Force parse err and result as JSON.
        @oauth.get reqUrl, (err, result) =>
            result = JSON.parse result if result? and lodash.isString result
            err = JSON.parse err if err? and lodash.isString err

            # Token might need to be refreshed.
            if err?
                msg = err.data?.error?.message or err.error?.message or err.data
                if msg?.toString().indexOf("expired") > 0
                    security.refreshAuthToken "netatmo"

            callback err, result

    # GET DATA
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

    # Helper to get API request parameters based on the filter.
    getParams = (filter) ->
        filter = {} if not filter?

        params = {}
        params["device_id"] = settings.netatmo.deviceId if settings.netatmo?.deviceId?
        params["date_begin"] = filter.startDate if filter.startDate?
        params["date_end"] = filter.endDate or "last"
        params["scale"] = filter.scale or "30min"

        return params

    # Check if the returned results or parameters represent the current reading.
    isCurrent = (params) ->
        if params["date_end"] is "last"
            return true
        return false

    # Get outdoor readings from Netatmo. Default is to get only the most current data.
    getOutdoor: (filter, callback) =>
        if lodash.isFunction filter
            callback = filter
            filter = null

        # Set outdoor parameters. If no module_id is passed, use the one defined on the settings.
        params = getParams filter
        params["module_id"] = settings.netatmo?.outdoorModuleId if not params["module_id"]?
        params["type"] = "Temperature,Humidity"

        # Make the request for outdoor readings.
        @makeRequest "getmeasure", params, (err, result) =>
            if err?
                @logError "Netatmo.getOutdoor", filter, err
            else
                # Data represents current readings or historical values?
                if isCurrent params
                    body = getResultBody result, params
                    @setData "outdoor", body[0]
                    logger.info "Netatmo.getOutdoor", "Current", body[0]
                else
                    logger.info "Netatmo.getOutdoor", filter, body

            callback err, result if callback?

    # Get indoor readings from Netatmo. Default is to get only the most current data.
    getIndoor: (filter, callback) =>
        if lodash.isFunction filter
            callback = filter
            filter = null

        # Set indoor parameters.
        params = getParams filter
        params["type"] = "Temperature,Humidity,Pressure,CO2,Noise"

        # Make the request for indoor readings.
        @makeRequest "getmeasure", params, (err, result) =>
            if err?
                @logError "Netatmo.getIndoor", filter, err
            else
                # Data represents current readings or historical values?
                if isCurrent params
                    body = getResultBody result, params
                    @setData "indoor", body[0]
                    logger.info "Netatmo.getIndoor", "Current", body[0]
                else
                    logger.info "Netatmo.getIndoor", filter, body

            callback err, result if callback?

    # JOBS
    # -------------------------------------------------------------------------

    # Get current outdoor conditions (weather) every 30 minutes.
    jobGetOutdoor: =>
        logger.info "Netatmo.jobGetOutdoor"

        @getOutdoor()

    # Get current indoor conditions every 5 minutes.
    jobGetIndoor: =>
        logger.info "Netatmo.jobGetIndoor"

        @getIndoor()


# Singleton implementation.
# -----------------------------------------------------------------------------
Netatmo.getInstance = ->
    @instance = new Netatmo() if not @instance?
    return @instance

module.exports = exports = Netatmo.getInstance()