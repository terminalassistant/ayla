# SERVER: ROUTES
# -----------------------------------------------------------------------------
# All server routes are defined here.
class Routes

    expresser = require "expresser"
    cron = expresser.cron
    logger = expresser.logger
    settings = expresser.settings

    email = require "./api/email.coffee"
    fs = require "fs"
    fitbit = require "./api/fitbit.coffee"
    toshl = require "./api/network.coffee"
    network = require "./api/network.coffee"
    ninja = require "./api/ninja.coffee"
    path = require "path"
    security = require "./security.coffee"
    toshl = require "./api/toshl.coffee"
    withings = require "./api/withings.coffee"
    wunderground = require "./api/wunderground.coffee"

    # INIT
    # -------------------------------------------------------------------------

    # Set most routes on init. The app (from Expresser) must be passed here.
    init: =>
        app = expresser.app.server

        # Main route.
        app.get "/", indexPage

        # Commander routes.
        app.get "/commander/:cmd/:params", commanderCallback
        app.get "/commander/:cmd", commanderCallback

        # Email routes.
        app.get "/email", emailPage

        # Fitbit routes.
        app.get "/fitbit", fitbitPage
        app.get "/fitbit/auth", fitbitAuth
        app.get "/fitbit/auth/callback", fitbitAuthCallback
        app.post "/fitbit/auth/callback", fitbitAuthCallback

        # Ninja Blocks routes.
        app.get "/ninja", ninjaPage

        # System routes.
        app.get "/system/jobs", systemJobsPage
        app.get "/system/network", systemNetworkPage

        # Toshl routes.
        app.get "/toshl", toshlPage
        app.get "/toshl/auth", toshlAuth
        app.get "/toshl/auth/callback", toshlAuthCallback
        app.post "/toshl/auth/callback", toshlAuthCallback

        # Withings routes.
        app.get "/withings", withingsPage
        app.get "/withings/auth", withingsAuth
        app.get "/withings/auth/callback", withingsAuthCallback
        app.post "/withings/auth/callback", withingsAuthCallback

        # Weather underground routes.
        app.get "/wunderground", wundergroundPage

    # MAIN ROUTES
    # -------------------------------------------------------------------------

    # The index homepage.
    indexPage = (req, res) ->
        renderPage req, res, "index"

    # COMMANDER ROUTES
    # -------------------------------------------------------------------------

    # The commander processor.
    commanderCallback = (req, res) ->
        renderPage req, res, "commander"

    # EMAIL ROUTES
    # -------------------------------------------------------------------------

    # Main Email entrance page.
    emailPage = (req, res) ->
        email.getDashboard (err, result) -> renderPage req, res, "email", {err: err, result: result}

    # FITBIT ROUTES
    # -------------------------------------------------------------------------

    # Main Fitbit entrance page.
    fitbitPage = (req, res) ->
        fitbit.getDashboard (err, result) -> renderPage req, res, "fitbit", {err: err, result: result}

    # Get Fitbit OAuth tokens.
    fitbitAuth = (req, res) ->
        fitbit.auth req, res

    # Callback for Fitbit OAuth.
    fitbitAuthCallback = (req, res) ->
        fitbit.auth req, res

    # NINJA BLOCKS ROUTES
    # -------------------------------------------------------------------------

    # Main Fitbit entrance page.
    ninjaPage = (req, res) ->
        ninja.getDashboard (err, result) -> renderPage req, res, "ninja", {err: err, result: result}

    # SYSTEM ROUTES
    # -------------------------------------------------------------------------

    # Cron jobs page.
    systemJobsPage = (req, res) ->
        renderPage req, res, "system.jobs", {pageTitle: "Scheduled jobs", jobs: cron.jobs}

    # Cron jobs page.
    systemNetworkPage = (req, res) ->
        renderPage req, res, "system.network", {pageTitle: "Network overview", status: network.status}

    # TOSHL ROUTES
    # -------------------------------------------------------------------------

    # Main Toshl entrance page.
    toshlPage = (req, res) ->
        toshl.getDashboard (err, result) -> renderPage req, res, "toshl", {err: err, result: result}

    # Get Toshl OAuth tokens.
    toshlAuth = (req, res) ->
        toshl.auth req, res

    # Callback for Toshl OAuth.
    toshlAuthCallback = (req, res) ->
        toshl.auth req, res

    # WITHINGS ROUTES
    # -------------------------------------------------------------------------

    # Main Withings entrance page.
    withingsPage = (req, res) ->
        withings.getDashboard (err, result) -> renderPage req, res, "withings", {err: err, result: result}

    # Get Withings OAuth tokens.
    withingsAuth = (req, res) ->
        withings.auth req, res

    # Callback for Withings OAuth.
    withingsAuthCallback = (req, res) ->
        withings.auth req, res

    # WUNDERGROUND ROUTES
    # -------------------------------------------------------------------------

    # Main Weather Underground entrance page.
    wundergroundPage = (req, res) ->
        wunderground.getCurrentWeather (err, result) -> renderPage req, res, "wunderground", {err: err, result: result}

    # HELPER METHODS
    # -------------------------------------------------------------------------

    # Helper to render pages.
    renderPage = (req, res, filename, options) ->
        options = {} if not options?
        options.pageTitle = filename if not options.pageTitle?
        options.title = settings.general.appTitle if not options.title?

        # Check if current view have an external JS to be loaded.
        jsName = filename.replace "jade",""
        jsPath = path.resolve __dirname, "../", "assets/js/views/#{jsName}.coffee"
        if fs.existsSync jsPath
            options.loadJs = [] if not options.loadJs?
            options.loadJs.push "views/#{jsName}.js"

        # Force .jade extension.
        filename += ".jade" if filename.indexOf(".jade") < 0

        # Render page.
        res.render filename, options

    # When the server can't return a valid result,
    # send an error response with status code 500.
    sendErrorResponse = (res, method, message) ->
        message = JSON.stringify message
        res.statusCode = 500
        res.send "Error: #{method} - #{message}"
        expresser.logger.error "HTTP Error", method, message

    # Log the request to the console if `debug` is true.
    logRequest = (method, params) ->
        if expresser.settings.general.debug
            if params?
                console.log "Request", method, params
            else
                console.log "Request", method


# Singleton implementation.
# -----------------------------------------------------------------------------
Routes.getInstance = ->
    @instance = new Routes() if not @instance?
    return @instance

module.exports = exports = Routes.getInstance()