# FITBIT API
# -----------------------------------------------------------------------------
class Fitbit extends (require "./baseApi.coffee")

    expresser = require "expresser"
    database= expresser.database
    events = expresser.events
    logger = expresser.logger
    settings = expresser.settings

    async = expresser.libs.async
    lodash = expresser.libs.lodash
    moment = expresser.libs.moment
    security = require "../security.coffee"

    # INIT
    # -------------------------------------------------------------------------

    # Init the Fitbit module.
    init: =>
        @baseInit()

    # Start the Fitbit module.
    start: =>
        @baseStart()

    # Stop the Fitbit module.
    stop: =>
        @baseStop()

    # API BASE METHODS
    # -------------------------------------------------------------------------

    # Authentication helper for Fitbit.
    auth: (req, res) =>
        security.processAuthToken "fitbit", req, res

    # Make a request to the Fitbit API.
    apiRequest: (path, params, callback) =>
        if not callback? and lodash.isFunction params
            callback = params
            params = null

        # Get data from the security module and set request URL.
        authCache = security.authCache["fitbit"]
        reqUrl = settings.fitbit.api.url + path
        reqUrl += "?" + params if params?

        logger.debug "Fitbit.apiRequest", reqUrl

        # Make request using OAuth.
        authCache.oauth.get reqUrl, authCache.data.token, authCache.data.tokenSecret, (err, result) ->
            result = JSON.parse result if lodash.isString result
            callback err, result if callback?

    # GET DATA
    # -------------------------------------------------------------------------

    # Get sleep data for the specified date.
    getSleep: (date, callback) =>
        if not date? or not callback?
            throw new Error "Fitbit.getSleep: parameters date and callback must be specified."

        @apiRequest "user/-/sleep/date/#{date}.json", (err, result) =>
            if err?
                @logError "Fitbit.getSleep", date, err
            else
                logger.debug "Fitbit.getSleep", date, result
            callback err, result

    # Get activity data (steps, calories, etc) for the specified date.
    getActivities: (date, callback) =>
        if not date? or not callback?
            throw new Error "Fitbit.getSteps: parameters date and callback must be specified."

        @apiRequest "user/-/activities/date/#{date}.json", (err, result) =>
            if err?
                @logError "Fitbit.getSteps", date, err
            else
                logger.debug "Fitbit.getSteps", date, result
            callback err, result

    # POST DATA
    # -------------------------------------------------------------------------

    # Post an activity to Fitbit.
    postActivity: (activity, callback) =>
        console.warn activity

    # JOBS
    # -------------------------------------------------------------------------

    # Scheduled job to check for missing Fitbit data.
    jobCheckMissingData: =>
        for d in settings.fitbit.checkMissingDataDays
            do (d) =>
                date = moment().subtract("d", d).format settings.fitbit.dateFormat
                @getSleep date, (err, result) =>
                    if err?
                        @logError "Fitbit.jobCheckMissingData", "getSleep", date, err
                        return false

                    # Has sleep data? Stop here, otherwise emit missing sleep event.
                    return if result?.sleep?.length > 0
                    events.emit "fitbit.sleep.missing", result

    # PAGES
    # -------------------------------------------------------------------------

    # Get the Fitbit dashboard data.
    getDashboard: (callback) =>
        yesterday = moment().subtract("d", 1).format settings.fitbit.dateFormat
        getSleepYesterday = (cb) => @getSleep yesterday, (err, result) -> cb err, {sleepYesterday: result}
        getActivitiesYesterday = (cb) => @getActivities yesterday, (err, result) -> cb err, {activitiesYesterday: result}

        async.parallel [getSleepYesterday, getActivitiesYesterday], (err, result) =>
            callback err, result

# Singleton implementation.
# -----------------------------------------------------------------------------
Fitbit.getInstance = ->
    @instance = new Fitbit() if not @instance?
    return @instance

module.exports = exports = Fitbit.getInstance()