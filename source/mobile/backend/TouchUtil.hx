package mobile.backend;

import flixel.FlxG;

class TouchUtil 
{
	/**
	 * Verifica se a tela do celular foi tocada
	 * Retorna true no exato momento
	 */
	public static function justPressed():Bool 
	{
		var pressed:Bool = false;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
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
}
