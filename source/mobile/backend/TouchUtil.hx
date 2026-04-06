package mobile.backend;

import flixel.FlxG;

class TouchUtil 
{
	public static function justPressed():Bool 
	{
		var justPressed:Bool = false;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				justPressed = true;
				break;
			}
		}

		return justPressed;
		#else
		return false;
		#end
	}
	
	public static function pressed():Bool 
	{
		var pressed:Bool = false;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.pressed)
			{
				pressed = true;
				break;
			}
		}

		return pressed;
		#else
		return false;
		#end
	}
	
	public static function justReleased():Bool 
	{
		var justReleased:Bool = false;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justReleased)
			{
				justReleased = true;
				break;
			}
		}

		return justReleased;
		#else
		return false;
		#end
	}
	
	public static function released():Bool 
	{
		var released:Bool = false;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.released)
			{
				released = true;
				break;
			}
		}

		return released;
		#else
		return false;
		#end
	}
}
