# SERVER: OAUTH
# -----------------------------------------------------------------------------
# Controls authentication using OAuth1 or OAuth2.
class OAuth

    expresser = require "expresser"
    database = expresser.database
    events = expresser.events
    logger = expresser.logger
    settings = expresser.settings

    lodash = expresser.libs.lodash
    moment = expresser.libs.moment
    oauthModule = require "oauth"
    url = require "url"

    # INIT
    # -------------------------------------------------------------------------

    # Init the OAuth module and refresh auth tokens from the database.
    constructor: (@service) ->
        logger.debug "OAuth", "New for #{@service}"

        @data = {}

    # AUTH SYNC
    # -------------------------------------------------------------------------

    # Get most recent auth tokens from the database and update the `oauth` DB collection.
    # Callback (err, result) is optional.
    loadTokens: (callback) =>
        @defaultUser = lodash.findKey settings.users, {isDefault: true}

        database.get "oauth", {"service": @service, "active": true}, (err, result) =>
            if err?
                logger.critical "OAuth.loadTokens", err
                callback err, false if callback?
            else
                logger.debug "OAuth.loadTokens", result

                # Iterate results to create OAuth clients for all users.
                for t in result
                    @client = getClient @service
                    @data[t.user] = t

                    # Needs refresh?
                    @refresh t.user if t.expires? and moment().unix() > t.expires

                if callback?
                    callback null, result

    # Remove old auth tokens from the database.
    cleanTokens: (callback) =>
        minTimestamp = moment().unix() - (settings.modules.maxAuthTokenAgeDays * 24 * 60 * 60)

        database.del "oauth", {timestamp: {$lt: minTimestamp}}, (err, result) =>
            if err?
                logger.error "OAuth.cleanTokens", "Timestamp #{minTimestamp}", err
            else
                logger.debug "OAuth.cleanTokens", "Timestamp #{minTimestamp}", "OK"
            if callback?
                callback err, result

    # Save the specified auth token to the database. Please note that tokens must be associated with a specific user.
    # If no uyser is set, use the default user (flagged with isDefault=true on the settings file).
    saveToken: (params, callback) =>
        if not callback? and lodash.isFunction params
            callback = params
            params = null

        # Get current time and set data.
        now = moment().unix()
        data = lodash.defaults params, {service: @service, active: true, timestamp: now}

        # Add extra parameters, if any.
        data.timestamp = params.oauth_timestamp if params.oauth_timestamp?
        data.userId = params.encoded_user_id if params.encoded_user_id?
        data.userId = params.userid if params.userid?

        # Make sure user is associated, or assume default user.
        data.user = @defaultUser if not data.user? or data.user is ""

        # Set local oauth cache.
        @data[data.user] = data

        # Update oauth collection and set related tokens `active` to false.
        database.set "oauth", {active: false}, {patch: true, upsert: false, filter: {service: @service}}, (err, result) =>
            if err?
                logger.error "OAuth.saveToken", @service, "Set active=false", err
            else
                logger.debug "OAuth.saveToken", @service, "Set active=false", "OK"

            # Save to database.
            database.set "oauth", data, (err, result) =>
                if err?
                    logger.error "OAuth.saveToken", @service, data, err
                else
                    logger.debug "OAuth.saveToken", @service, data, "OK"
                if callback?
                    callback err, result

    # PROCESSING AND REQUESTING
    # -------------------------------------------------------------------------

    # Helper to the an OAuth client for a particular service.
    getClient = (service) ->
        callbackUrl = settings.general.appUrl + service + "/auth/callback"
        headers = {"Accept": "*/*", "Connection": "close", "User-Agent": "Ayla OAuth Client"}
        version = settings[service].api.oauthVersion

        if version is "2.0"
            obj = new oauthModule.OAuth2(
                settings[service].api.clientId,
                settings[service].api.secret,
                settings[service].api.oauthUrl,
                settings[service].api.oauthPathAuthorize,
                settings[service].api.oauthPathToken,
                headers)
        else
            obj = new oauthModule.OAuth(
                settings[service].api.oauthUrl + "request_token",
                settings[service].api.oauthUrl + "access_token",
                settings[service].api.clientId,
                settings[service].api.secret,
                version,
                callbackUrl,
                "HMAC-SHA1",
                null,
                headers)

        # Use authorization header instead of passing token via querystrings?
        if settings[service].api.oauthUseHeader
            obj.useAuthorizationHeaderforGET true

        return obj

    # Get an OAuth protected resource. If no `user` is passed it will use the default one.
    get: (reqUrl, user, callback) =>
        if not callback? and lodash.isFunction user
            callback = user
            user = null

        user = @defaultUser if not user?

        if not @data[user]?
            callback "No oauth data for #{user}. Please authorize first on #{@service} for that user."
            return

        # OAuth2 have only an access token, OAuth1 has a token and a secret.
        if settings[@service].api.oauthVersion is "2.0"
            @client.get reqUrl, @data[user].accessToken, (err, result) =>
                if err?
                    description = err.data?.error_description or err.data?.error?.message or null
                    @refresh user if description?.indexOf("expired") > 0
                callback err, result
        else
            @client.get reqUrl, @data[user].token, @data[user].tokenSecret, (err, result) =>
                callback err, result

    # Try getting OAuth data for a particular request / response.
    process: (req, res) =>
        user = req.session.user or @defaultUser

        # Make sure OAuth client is set.
        if not @client?
            @client = getClient @service
            @data[user] = {}

        # Check if request has token on querystring.
        qs = url.parse(req.url, true).query if req?

        # Helper function to get the request token using OAUth 1.x.
        getRequestToken1 = (err, oauth_token, oauth_token_secret, oauth_authorize_url, additionalParameters) =>
            if err?
                logger.error "OAuth.process", "getRequestToken1", @service, err
                return

            logger.info "OAuth.process", "getRequestToken1", @service, oauth_token

            # Set token secret cache and redirect to authorization URL.
            @data[user].tokenSecret = oauth_token_secret
            res?.redirect "#{settings[@service].api.oauthUrl}authorize?oauth_token=#{oauth_token}"

        # Helper function to get the access token using OAUth 1.x.
        getAccessToken1 = (err, oauth_token, oauth_token_secret, additionalParameters) =>
            if err?
                logger.error "OAuth.process", "getAccessToken1", @service, err
                return

            logger.info "OAuth.process", "getAccessToken1", @service, oauth_token

            # Save oauth details to DB and redirect user to service page.
            oauthData = lodash.defaults {user: user, token: oauth_token, tokenSecret: oauth_token_secret}, additionalParameters
            @saveToken oauthData
            res?.redirect "/#{@service}"

        # Helper function to get the access token using OAUth 2.x.
        getAccessToken2 = (err, oauth_access_token, oauth_refresh_token, results) =>
            if err?
                logger.error "OAuth.process", "getAccessToken2", @service, err
                return

            logger.info "OAuth.process", "getAccessToken2", @service, oauth_access_token

            # Schedule token to be refreshed automatically with 10% of the expiry time left.
            expires = results?.expires_in or results?.expires or 43200
            lodash.delay @refresh, expires * 900, user

            # Save oauth details to DB and redirect user to service page.
            oauthData = {user: user, accessToken: oauth_access_token, refreshToken: oauth_refresh_token, expires: moment().add("s", expires).unix()}
            @saveToken oauthData
            res?.redirect "/#{@service}"

        # Set correct request handler based on OAUth parameters and query tokens.
        if settings[@service].api.oauthVersion is "2.0"

            # Use cliend credentials (password) or authorization code?
            if settings[@service].api.username?
                opts = {"grant_type": "password", username: settings[@service].api.username, password: settings[@service].api.password}
            else
                opts = {"grant_type": "authorization_code"}

            if settings[@service].api.oauthResponseType?
                opts["response_type"] = settings[@service].api.oauthResponseType

            if settings[@service].api.oauthState?
                opts["state"] = settings[@service].api.oauthState

            # Get authorization code from querystring.
            qCode = qs?.code

            if qCode?
                @client.getOAuthAccessToken qCode, opts, getAccessToken2
            else
                res.redirect @client.getAuthorizeUrl opts

        # Getting an OAuth1 access token?
        else if qs?.oauth_token?
            @client.getOAuthAccessToken qs.oauth_token, @data[user].tokenSecret, qs.oauth_verifier, getAccessToken1
        else
            @client.getOAuthRequestToken {}, getRequestToken1

    # Helper to refresh an OAuth2 token.
    refresh: (user) =>
        if not @client?
            logger.warn "OAuth.refresh", @service, "OAuth client not ready. Abort refresh!"
            return

        # Abort if token is already being refreshed.
        return if @refreshing

        # Get oauth object and refresh token and set grant type to refresh_token.
        @refreshing = true
        refreshToken = @data[user].refreshToken
        opts = {"grant_type": "refresh_token"}

        # Proceed and get OAuth2 tokens.
        @client.getOAuthAccessToken refreshToken, opts, (err, oauth_access_token, oauth_refresh_token, results) =>
            @refreshing = false

            if err?
                logger.error "OAuth.refresh", @service, err
                return

            logger.info "OAuth.refresh", @service, oauth_access_token

            # Schedule token to be refreshed with 10% of time left.
            expires = results?.expires_in or results?.expires or @data[user].expires or 43200
            lodash.delay @refresh, expires * 900, user

            # If no refresh token is returned, keep the last one.
            oauth_refresh_token = @data[user].refreshToken if not oauth_refresh_token? or oauth_refresh_token is ""

            # Save oauth details to DB and redirect user to service page.
            oauthData = {user: user, accessToken: oauth_access_token, refreshToken: oauth_refresh_token, expires: moment().add("s", expires).unix()}
            @saveToken oauthData


# Exports
# -----------------------------------------------------------------------------
module.exports = exports = OAuth