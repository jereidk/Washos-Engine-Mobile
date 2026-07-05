package mobile.backend;

import mobile.backend.flixel.input.FlxMobileInputID;

class MobileUtil {
    // There will be more soon
    
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
}