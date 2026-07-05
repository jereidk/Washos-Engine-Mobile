package mobile.backend;

import flixel.FlxG;
import flixel.FlxBasic;
import mobile.backend.flixel.input.FlxMobileInputID;
import mobile.backend.flixel.FlxButton;

class MobileUtil {
	public static var isTouchActive(default, null):Bool = true;
    
	public static var mobileIDs:Map<String, Array<FlxMobileInputID>> = [
		'note_up'		=> [noteUP, UP2],
		'note_left'		=> [noteLEFT, LEFT2],
		'note_down'		=> [noteDOWN, DOWN2],
		'note_right'	=> [noteRIGHT, RIGHT2],

		'ui_up'			=> [UP, noteUP],
		'ui_left'		=> [LEFT, noteLEFT],
		'ui_down'		=> [DOWN, noteDOWN],
		'ui_right'		=> [RIGHT, noteRIGHT],

		'accept'		=> [A],
		'back'			=> [B],
		'pause'			=> [NONE],
		'reset'			=> [NONE]
	];

	/**
	 * Check what the last input used by the player was.
	 * Call this in `main` or in the controller itself.
	 */
	public static function updateInputMethod():Void 
	{
		if (FlxG.touches.justStarted().length > 0) 
		{
			isTouchActive = true;
			return; 
		}

		if (FlxG.keys.justPressed.ANY) 
		{
			isTouchActive = false;
			return;
		}

		if (FlxG.gamepads.numActiveGamepads > 0) 
		{
			for (gamepad in FlxG.gamepads.getActiveGamepads()) 
			{
				if (gamepad.justPressed.ANY) 
				{
					isTouchActive = false;
					return;
				}
			}
		}
	}

	/**
	 * Updates the visibility and activation of an element and its internal buttons.
	 * @param container The main class that contains the buttons (e.g., this)
	 * @param buttons The array of buttons
	 */
	public static function setControlsState(container:FlxBasic, buttons:Array<FlxButton>):Void 
	{
		if (container.visible != isTouchActive) 
		{
			container.visible = isTouchActive;
			
			if (buttons != null) 
			{
				for (btn in buttons) 
				{
					btn.active = isTouchActive;
					btn.visible = isTouchActive;
				}
			}
		}
	}
}