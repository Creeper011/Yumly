import Yumly
import types/config

const configPath = "config.yumly"

proc getConfig*(): Config =
    ## Load Configuration
    let config = loadYumly(configPath)
    let appBlk = config["application"]

    let category = appBlk["category"].getStr()
    let nsfw = appBlk["nsfw"].getBool()
    let downloadPath = appBlk["download-path"].getStr()
    
    Config(category: category, nsfw: nsfw, downloadPath: downloadPath)