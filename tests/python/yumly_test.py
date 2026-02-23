from yumly import Yumly

data = Yumly().load("example.yumly")
result = Yumly().validate_file("example.yumly")
result_content = Yumly().validate_content("""
include { .env }
                                          
(app) {
    name ;string = "yumly",
    version ;string = "0.0.1",
    debug ;bool = true,
    number = 42,
    pi = 3.14159,
    mi = 3e2,
    (hello) {
        name = "hello", myBool ;bool = true,
        version2 = "0.1",
        desktop = $["XDG_SESSION_DESKTOP"]
    }
}""")
print(data)
print(result)
print(result_content)