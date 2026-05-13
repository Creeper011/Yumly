import Yumly
import strutils, sequtils, terminal

const configPath = "config.yumly"
type
    Drink = object
        name: string
        price: float
    Food = object
        name: string
        price: float
    Menu = object
        drinks: seq[Drink]
        foods: seq[Food]
    Order = object
        menu: Menu
        custumerName: string

proc getConfig(): YumlyConf =
    return loadYumly(configPath)

proc toMenu(yumly: YumlyConf): Menu =
    var menu: Menu
    let menuBlock = yumly.getBlock("menu")
    for item in menuBlock:
        let itemType = item["type"].getStr()
        case itemType
        of "drink":
            menu.drinks.add(item.to(Drink))
        of "food":
            menu.foods.add(item.to(Food))
        else:
            echo "Unknown item type: " & itemType
    menu

proc inputToOrder(order: Order, input: string): Order =
    var newOrder: Order
    for item in input.split(","):
        let item = item.strip()
        let itemIndex = item.parseInt()
        if itemIndex >= 1 and itemIndex <= order.menu.drinks.len:
            newOrder.menu.drinks.add(order.menu.drinks[itemIndex - 1])
        elif itemIndex > order.menu.drinks.len and itemIndex <=
                order.menu.drinks.len + order.menu.foods.len:
            newOrder.menu.foods.add(order.menu.foods[itemIndex -
                    order.menu.drinks.len - 1])
        else:
            echo "Invalid item number: " & item
            quit(1)
    newOrder

proc showMenu(order: Order)
proc consumeOrder(originalOrder: Order, newOrder: Order)

proc consumeOrder(originalOrder: Order, newOrder: Order) =
    echo ""
    echo "Your order: "
    for item in newOrder.menu.drinks:
        echo "- " & item.name & " ---------------------- $" & $item.price
    for item in newOrder.menu.foods:
        echo "- " & item.name & " ---------------------- $" & $item.price
    echo ""
    let drinksTotal = newOrder.menu.drinks.foldl(a + b.price, 0.0)
    let foodsTotal = newOrder.menu.foods.foldl(a + b.price, 0.0)
    echo "Total: $" & $(drinksTotal + foodsTotal)
    echo ""
    echo "Yummy yummy! You ate it!"
    echo ""
    echo "Do you want to order again? (y/n)"
    let again = readLine(stdin)
    if again.strip().toLowerAscii() == "y":
        eraseScreen stdout
        showMenu(originalOrder)
    else:
        echo ""
        echo "Thanks for visiting! See you next time. Goodbye!"
        quit(0)


proc showMenu(order: Order) =
    echo "Welcome, I'm " & order.custumerName & ", what would you like to order?"
    echo ""
    echo "Menu:"
    var i = 1
    for drink in order.menu.drinks:
        echo $i & ". " & drink.name & " ---------------------- $" & $drink.price
        i += 1
    for food in order.menu.foods:
        echo $i & ". " & food.name & " ---------------------- $" & $food.price
        i += 1
    echo ""
    echo "What would you like to order? (choose a number, or 'q' to quit)"
    let input = readLine(stdin)
    if input.strip().toLowerAscii() == "q":
        echo ""
        echo "Thanks for visiting! See you next time. Goodbye!"
        quit(0)
    let newOrder = inputToOrder(order = order, input = input)
    eraseScreen stdout
    consumeOrder(originalOrder = order, newOrder = newOrder)

proc main() =
    let config = getConfig()
    var menu = toMenu(config)
    let order = Order(
        menu: menu,
        custumerName: config["custumerName"].getStr()
    )
    showMenu(order)

when isMainModule:
    main()
