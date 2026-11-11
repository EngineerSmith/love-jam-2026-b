local uiManager = require("menu:uiManager")

uiManager.registerTheme("lj26b:ui.mainMenuTheme", "menu:themes.mainMenu")
uiManager.registerTheme("lj26b:ui.inventoryTheme", "lj26b:themes.inventoryTheme")

uiManager.registerComponent("lj26b:ui.cell", "cell")
uiManager.registerComponent("lj26b:ui.recipe", "recipe")

uiManager.addSceneModifier("game:menu.MainMenu", "lj26b:ui.mainMenu")
uiManager.registerScene("lj26b:ui.inventory", "game:menu.inventory")
uiManager.registerScene("lj26b:ui.cookingPot", "game:menu.cookingPot")