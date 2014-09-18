# SERVER: BASE MODEL
# -----------------------------------------------------------------------------
class BaseModel

    expresser = require "expresser"
    moment = expresser.libs.moment

    # Set ID and update timestamp after setting data.
    afterSetData: (obj) =>
        if obj.id? and not @id?
            @id = obj.id

        if obj.timestamp?
            @timestamp = obj.timestamp
        else if obj.modified?
            @timestamp = moment(new Date(obj.modified.substring 20)).unix()

        # Remove all undefined and null properties.
        for key, data of this
            delete @[key] if not data?

# Exports model.
# -----------------------------------------------------------------------------
module.exports = exports = BaseModel
