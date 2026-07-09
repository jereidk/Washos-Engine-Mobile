package;

import flixel.FlxG;
import flixel.FlxState;

#if mobile
import mobile.backend.AndroidRPC;
import mobile.backend.AndroidUtils;
#end

/**
 * Init state that prepares backend classes before entering the main menu.
 * This runs once at startup before any gameplay or menus.
 */
class Init extends FlxState
{
	override public function create():Void
	{
		super.create();

		// Initialize ASTC texture support on Android
		// This MUST happen before any textures are loaded
		#if (android && cpp)
		mobile.backend.AstcSupport.check();
		mobile.backend.AstcLoader.installContextHandler();
		#end

		// Continue to the next state (typically TitleState)
		FlxG.switchState(Type.createInstance(Main.initialState, []));
	}
}
