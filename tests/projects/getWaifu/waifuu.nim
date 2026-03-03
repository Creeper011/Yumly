import Yumly
import httpclient, os, json, strutils

const
  defaultCategorie = "neko"
  routeUrl = "https://waifu.pics/api"
  getManyEndpointPost = "/sfw/"
  saveDir = "waifus"
  indexPath = saveDir / "data.yumly"

var config: YumlyKind
var excludeList: seq[string] = @[]

proc getWaifus(exclude: seq[string]): JsonNode =
  let url = routeUrl & getManyEndpointPost & defaultCategorie

  let client = newHttpClient(
    headers = newHttpHeaders({
      "User-Agent": "Mozilla/5.0",
      "Accept": "application/json",
      "Content-Type": "application/json"
    })
  )
  let body = %*{
    "exclude": exclude
  }

  let response = client.request(
    url,
    body = $body,
    httpMethod = HttpPost
  )

  client.close()
  result = parseJson(response.body)

proc downloadWaifu(url: string) =
  let client = newHttpClient()
  let filename = url.split("/")[^1]
  let path = saveDir / filename
  client.downloadFile(url, path)
  client.close()

proc loadIndex(): YumlyKind =
  if fileExists(indexPath):
    result = loadYumly(indexPath)
    for p in result.pairs:
      if p.key == "exclude" and p.value.kind == vkList:
        for el in p.value.elements:
          if el.kind == vkString:
            excludeList.add(el.strVal)
  else:
    result = newYumly()
    result.addPair("exclude", newListValue(@[]))

proc saveToIndex(url: string) =
  var found = false
  for p in config.pairs.mitems:
    if p.key == "exclude" and p.value.kind == vkList:
      p.value.elements.add(newStringValue(url))
      found = true
      break

  if not found:
    config.addPair("exclude", newListValue(@[newStringValue(url)]))

  writeYumly(config, indexPath, true)

if not dirExists(saveDir):
  createDir(saveDir)

config = loadIndex()
let data = getWaifus(excludeList)
let url = data["url"].getStr()
downloadWaifu(url)
saveToIndex(url)
