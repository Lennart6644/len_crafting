Locales = {}

function Localize(value)
    if type(value) ~= 'table' then
        return value
    end
    return value[Config.Locale] or value.en or value.de
end

function _L(key, ...)
    local lang = Locales[Config.Locale] or Locales.en
    local text = lang[key] or Locales.en[key] or key
    if select('#', ...) > 0 then
        return string.format(text, ...)
    end
    return text
end
