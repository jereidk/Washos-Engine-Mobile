package;

import flixel.FlxG;
import flixel.FlxState;
import openfl.utils.AssetType;

#if mobile
import mobile.backend.AndroidRPC;
import mobile.backend.AndroidUtils;
#end

#if flxanimate
import flxanimate.FlxAnimateAssets;
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

		// Route FlxAnimate spritemap texture loads through Paths so that
		// ASTC overrides and external-storage paths are handled transparently.
		#if flxanimate
		FlxAnimateAssets.getBitmapData = (path) -> {
			var result = backend.Paths.image(path);
			return result == null ? null : result.bitmap;
		};
		FlxAnimateAssets.exists = (path, _) -> {
			if (backend.Paths.fileExists(path, IMAGE)) return true;
			#if (android && cpp)
			if (path.endsWith('.png')) {
				var astcPath = mobile.backend.AstcLoader.deriveAstcPath(path);
				return astcPath != null && backend.Paths.fileExists(astcPath, IMAGE);
			}
			#end
			return false;
		};
		FlxAnimateAssets.getText = (path) -> {
			try return backend.Paths.getTextFromFile(path) catch (e:Dynamic) { return null; };
		};
		// Replace .astc with .png in FlxAnimate's folder scanner so spritemap
		// image selection always resolves to a .png counterpart that FlxAnimate expects.
		var _animListOrig = FlxAnimateAssets.list;
		FlxAnimateAssets.list = function(path, ?type, ?lib, subs = false) {
			var r = _animListOrig(path, type, lib, subs);
			if (r == null) return [];
			return r.map(f -> f.endsWith('.astc') ? f.substr(0, f.length - 5) + '.png' : f);
		};
		#end

		// Continue to the next state (typically TitleState)
		FlxG.switchState(Type.createInstance(Main.initialState, []));
	}
}
