-- Config.lua
-- Configuration constants and settings for MenuAnimator system

local Config = {}

-- Animation constants
Config.HOVER_SCALE = 1.08
Config.HOVER_ROTATION = 3
Config.CLICK_Y_OFFSET = 3
Config.CLICK_SCALE = 0.95
Config.ACTIVATE_ROTATION = -3
Config.ACTIVATE_SCALE = 1.12
Config.ANIMATION_DURATION = 0.25
Config.MENU_ANIMATION_DURATION = 0.4
Config.MENU_CLOSE_ANIMATION_DURATION = 0.25
Config.BOUNCE_DURATION = 0.15

-- Camera effects constants
Config.BLUR_SIZE = 15
Config.DEFAULT_FOV = 70
Config.MENU_FOV = 50
Config.CAMERA_EFFECT_DURATION = 0.5

-- Sound effects constants
Config.VOLUME_TO_REDUCE = 0.1

return Config
