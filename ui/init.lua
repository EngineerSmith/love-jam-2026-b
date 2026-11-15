local uiManager = require("menu:uiManager")

uiManager.registerTheme("lj26b:ui.mainMenuTheme", "menu:themes.mainMenu")
uiManager.registerTheme("lj26b:ui.inventoryTheme", "lj26b:themes.inventoryTheme")

uiManager.registerComponent("lj26b:ui.cell", "cell")
uiManager.registerComponent("lj26b:ui.recipe", "recipe")

uiManager.addSceneModifier("game:menu.MainMenu", "lj26b:ui.mainMenu")
uiManager.registerScene("lj26b:ui.inventory", "game:menu.inventory")
uiManager.registerScene("lj26b:ui.cookingPot", "game:menu.cookingPot")
uiManager.registerScene("lj26b:ui.tutorial1", "game:menu.tutorial1")
uiManager.registerScene("lj26b:ui.tutorial2", "game:menu.tutorial2")
uiManager.registerScene("lj26b:ui.tutorial3", "game:menu.tutorial3")
uiManager.registerScene("lj26b:ui.tutorial4", "game:menu.tutorial4")