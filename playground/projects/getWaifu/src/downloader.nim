import httpclient, os, json, strutils

const baseUrl = "https://api.waifu.im/images"

proc fetchWaifu(nsfw: bool, category: string): string =
  ## Fetches a waifu from the API
  var url = baseUrl & "?IsNsfw=" & (if nsfw: "True" else: "False")
  # apply category filter if specified
  if category.len > 0:
    url &= "&IncludedTags=" & category
  
  let client = newHttpClient(
    headers = newHttpHeaders({
      "User-Agent": "yu/1.0",
      "Accept": "application/json"
    })
  )

  let response = client.request(url, httpMethod = HttpGet)
  client.close()
  
  if response.code != Http200:
    raise newException(Exception, "Oh no! :c API request failed with code: " & $response.code)

  let root = parseJson(response.body)
  return root["items"][0]["url"].getStr()

proc downloadWaifu(url: string, downloadPath: string) =
  ## Downloads a file from a URL and saves it to downloadPath
  if not dirExists(downloadPath):
    createDir(downloadPath)
    
  let client = newHttpClient()
  let filename = url.split("/")[^1]
  let path = downloadPath / filename

  echo "Downloading: ", url
  client.downloadFile(url, path)
  client.close()

  echo "Saved to: ", path

proc downloadAndFetchWaifu*(nsfw: bool, category: string, downloadPath: string) =
    fetchWaifu(nsfw, category).downloadWaifu(downloadPath=downloadPath)