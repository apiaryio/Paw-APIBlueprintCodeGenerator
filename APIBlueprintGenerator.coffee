# in API v0.2.0 and below (Paw 2.2.2 and below), require had no return value
((root) ->
  if root.bundle?.minApiVersion('0.2.0')
    root.Mustache = require("./mustache")
  else
    require("mustache.js")
)(this)

APIBlueprintGenerator = ->

  # Generate a response dictionary for the mustache context from a paw HTTPExchange
  #
  # @param [HTTPExchange] exchange The paw HTTP exchange for the response
  #
  # @return [Object] The template context object
  #
  @response = (exchange) ->
    if !exchange
      return null

    headers = []
    is_json = false
    for key, value of exchange.responseHeaders
      if key in ['Content-Type', 'Connection', 'Date', 'Via', 'Server', 'Content-Length']
        is_json = (key == 'Content-Type' && value.search(/(json)/i) > -1)
        continue

      headers.push({ key: key, value: value })
    has_headers = (headers.length > 0)

    body = exchange.responseBody
    has_body = body.length > 0
    if has_body
      if is_json
        body = JSON.stringify(JSON.parse(body), null, 4)
      body_indentation = '        '
      if has_headers
        body_indentation += '    '
      body = body.replace(/^/gm, body_indentation)

    return {
      statusCode: exchange.responseStatusCode,
      contentType: exchange.responseHeaders['Content-Type'],
      "headers?": has_headers,
      headers: headers
      "body?": has_headers && has_body,
      body: body,
    }

  # Generate a request dictionary for the mustache context from a paw Request
  #
  # @param [Request] exchange The paw HTTP request
  #
  # @return [Object] The template context object
  #
  @request = (paw_request) ->
    headers = []
    is_json = false
    for key, value of paw_request.headers
      if key in ['Content-Type']
        is_json = (value.search(/(json)/i) > -1)
        continue

      headers.push({ key: key, value: value })
    has_headers = (headers.length > 0)

    body = paw_request.body
    has_body = body.length > 0
    if has_body
      if is_json
        body = JSON.stringify(JSON.parse(body), null, 4)
      body_indentation = '        '
      if has_headers
        body_indentation += '    '
      body = body.replace(/^/gm, body_indentation)

    description = paw_request.description
    has_description = description && description.length > 0

    if has_headers || has_body || paw_request.headers['Content-Type']
      return {
        "headers?": has_headers,
        headers: headers,
        contentType: paw_request.headers['Content-Type'],
        "body?": has_headers && has_body,
        body: body,
        "description?": has_description,
        description: description,
      }

  # Generate a parameter List for the mustache context from a paw Request
  #
  # @param [Request] exchange The paw HTTP request
  #
  # @return [Object] The template context object
  #
  @parameter = (paw_request) ->
    parameters = []
    body = paw_request.body
    has_body = body.length > 0
    url_parameters = paw_request.getUrlParameters()
    for key, value of url_parameters
      parameters.push({
        name: key,
        example: value,
        type: @isNumber(value)
        })
    if has_body
      is_json = @isJSON(paw_request)
      if is_json
        body_parameters = JSON.parse(body)
        for key,value of body_parameters
          parameters.push({
            name: key,
            example: value,
            type: @isNumber(value)
            })
      else
        body_parameters = body.split("&")
        for value in body_parameters
          param = value.split("=")
          parameters.push({
            name: param[0],
            example: param[1],
            type: @isNumber(param[1])
            })
    return {
      "parameters?":parameters.length > 0,
      parameters:parameters
    }

  # Get a path from a URL
  #
  # @param [String] url The given URL
  #
  # @return [String] The path from the URL
  @path = (url) ->
    path = url.replace(/^https?:\/\/[^\/]+/i, '')
    if !path
      path = '/'

    path

  # Check is Json Content
  @isJSON = (paw_request) ->
    for key, value of paw_request.headers
      if key in ['Content-Type']
        is_json = (value.search(/(json)/i) > -1)
        break
    return is_json

  @isNumber = (value) ->
    match = /^[0-9]*$/.test(value)
    if(match && value.length != 0 )
      return "number"
    else
      return "string"

  @generate = (context) ->
    paw_request = context.getCurrentRequest()
    url = paw_request.url
    template = readFile("apiblueprint.mustache")
    Mustache.render(template,
      method: paw_request.method,
      path: @path(url),
      request: @request(paw_request),
      response: @response(paw_request.getLastExchange()),
      parameter: @parameter(paw_request),
    )

  return

APIBlueprintGenerator.identifier = "io.apiary.PawExtensions.APIBlueprintGenerator"
APIBlueprintGenerator.title = "API Blueprint Generator"
APIBlueprintGenerator.fileExtension = "md"

registerCodeGenerator APIBlueprintGenerator
