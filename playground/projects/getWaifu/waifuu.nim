import std/[os, strutils]
import src/downloader
import src/get_config

proc confirmAdultContent(): bool =
  ## Asks user to confirm age for adult content.
  echo "⚠️ Oh no! NSFW content ahead!"
  echo "Are you 18 or older? (y/n)?"
  let ans = readLine(stdin)
  return ans.strip().toLowerAscii() == "y"

proc run(nsfwFlag: bool, limit: int) =
  ## Main execution logic: loads config, checks age if needed, and downloads images.
  let config = getConfig()
  let actualNsfw = nsfwFlag or config.nsfw

  if actualNsfw and not confirmAdultContent():
    echo "Aww... looks like you don't have permission to continue."
    quit(0)

  echo "Haii~ Fetching ", limit, " images in category: '", (
    if config.category == "": "none" else: config.category), "'"
  echo "Rate limit active: 1 request per 100ms"
  echo "(NSFW: ", actualNsfw, ")"
  for i in 1..limit:
    try:
      downloadAndFetchWaifu(actualNsfw, config.category, config.downloadPath)
      if i < limit:
        sleep(100)
    except Exception as e:
      echo "Oh no :c something went wrong while fetching the images: ", e.msg
      break

when isMainModule:
  ## Entry point for the CLI tool.
  var nsfwEnabled = false
  var limit = 1
  let args = commandLineParams()

  for i in 0..<args.len:
    if args[i] == "--nsfw":
      nsfwEnabled = true
    elif args[i] == "-l":
      if i + 1 < args.len:
        limit = args[i+1].parseInt()

  run(nsfwEnabled, limit)
