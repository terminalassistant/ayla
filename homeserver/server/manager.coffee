# SERVER: MANAGER
# -----------------------------------------------------------------------------
# Wrapper for all managers. A "manager" is responsible for automated actions
# based on data processed by relevant API modules.
class Manager

    expresser = require "expresser"
    logger = expresser.logger
    settings = expresser.settings

    fs = require "fs"
    lodash = expresser.libs.lodash
    path = require "path"

    # Modules will be populated on init.
    modules: {}

    # INIT
    # -------------------------------------------------------------------------

    # Init Ayla API.
    init: (callback) =>
        rootPath = path.join __dirname, "../"
        managerPath = rootPath + "server/manager/"

        # Init modules.
        files = fs.readdirSync managerPath
        for f in files
            if f isnt "baseManager.coffee" and f.indexOf(".coffee") > 0
                disabled = lodash.contains settings.modules.disabled, f.replace(".coffee", "")

                # Only add if not on the disabled modules setting.
                if disabled
                    logger.debug "Manager.init", f, "Module is disabled and won't be instantiated."
                else
                    module = require "./manager/#{f}"
                    module.init()
                    @modules[module.moduleId] = module

        # Proceed with callback?
        callback() if callback?


# Singleton implementation.
# -----------------------------------------------------------------------------
Manager.getInstance = ->
    @instance = new Manager() if not @instance?
    return @instance

module.exports = exports = Manager.getInstance()