package mobile.backend;

#if (android && cpp)
import openfl.display.BitmapData;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DTextureFormat;
import openfl.display3D.textures.RectangleTexture;
import openfl.display3D.textures.TextureBase;
import openfl.Assets as OflAssets;
import openfl.Assets;
import openfl.events.Event;
import lime.utils.UInt8Array;
#end

/**
 * Loads raw ASTC texture files (16-byte header + compressed blocks) into
 * OpenFL BitmapData backed by a GPU-side compressed texture.
 *
 * ASTC files live next to their PNG counterpart with a .astc extension:
 *   assets/images/characters/bf.png  →  assets/images/characters/bf.astc
 * The original PNGs are never touched and always serve as fallback.
 * On devices that do not expose GL_KHR_texture_compression_astc_ldr
 * the loader returns null and the caller falls through to the PNG.
 *
 * Context-loss recovery: Android destroys the GPU context when the app is
 * backgrounded. BitmapData.fromTexture() has no CPU pixels and cannot be
 * restored automatically by OpenFL. This class registers a CONTEXT3D_CREATE
 * listener that re-uploads every tracked ASTC texture when the GL context
 * comes back, patching the existing RectangleTexture handles in-place so
 * all live BitmapData instances automatically see fresh GPU data.
 *
 * PNG fallback: if the .astc file is missing when the context is restored
 * (e.g. DLC uninstalled, SD-card corruption), the loader falls back to the
 * original PNG and switches that entry permanently to PNG-restore mode so
 * future restore cycles also use the PNG.
 */
@:access(openfl.display3D.textures.TextureBase)
@:access(openfl.display3D.Context3D)
@:access(openfl.display.BitmapData)
class AstcLoader
{
	// ASTC magic bytes (little-endian 0x5CA1AB13)
	static inline final MAGIC_0:Int = 0x13;
	static inline final MAGIC_1:Int = 0xAB;
	static inline final MAGIC_2:Int = 0xA1;
	static inline final MAGIC_3:Int = 0x5C;

	// ASTC header size in bytes
	static inline final HEADER_SIZE:Int = 16;

	// Compressed payloads at or below this size are kept in RAM so context
	// restoration can skip the disk re-read for small/medium textures.
	// At ASTC 8×8 this covers textures up to ~1024×1024.
	// Larger spritemaps re-read from disk on restore (lower RAM overhead vs.
	// occasional resume stutter is the accepted tradeoff).
	static inline final BYTES_CACHE_LIMIT:Int = 512 * 1024; // 512 KB

	#if (android && cpp)
	// Keyed by PNG path (= FunkinCache cache key).
	// glFormat == 0 is the PNG-fallback sentinel — valid ASTC entries always
	// arrive here with glFormat != 0 (blockSizeToGlFormat guards this).
	static var _recovery:Map<String, {
		astcPath:    String,
		rectTex:     RectangleTexture,
		width:       Int,
		height:      Int,
		glFormat:    Int,
		cachedBytes: Null<haxe.io.Bytes>
	}> = [];
	static var _listenerInstalled:Bool = false;
	#end

	/**
	 * Installs the CONTEXT3D_CREATE listener that re-uploads all tracked ASTC
	 * textures after an OpenGL context loss/restore cycle.
	 * Safe to call multiple times — only installs once.
	 * Call from Init.hx right after AstcSupport.check().
	 */
	public static function installContextHandler():Void
	{
		#if (android && cpp)
		if (_listenerInstalled) return;
		_listenerInstalled = true;
		FlxG.stage.stage3Ds[0].addEventListener(Event.CONTEXT3D_CREATE, _onContextRestored);
		#end
	}

	/**
	 * Removes a PNG cache key from the recovery map.
	 * Call from FunkinCache.removeFromCache() so evicted textures are not
	 * re-uploaded on context restoration.
	 */
	public static function removeTracking(cacheKey:String):Void
	{
		#if (android && cpp)
		_recovery.remove(cacheKey);
		#end
	}

	/**
	 * Derives the ASTC path for a PNG path and attempts to load it.
	 * Checks external storage first, then falls back to bundled APK assets.
	 * The returned BitmapData is registered for automatic context-loss recovery.
	 * Returns null if ASTC is unsupported, no .astc exists, or loading fails.
	 */
	public static function tryLoad(pngPath:String):Null<BitmapData>
	{
		#if (android && cpp)
		if (!AstcSupport.isSupported) {
			return null;
		}

		var astcPath = deriveAstcPath(pngPath);
		if (astcPath == null) {
			return null;
		}

		// External storage (extracted APK assets, DLC overrides) takes priority.
		if (sys.FileSystem.exists(astcPath))
		{
			try
			{
				var bytes = sys.io.File.getBytes(astcPath);
				return _loadAndTrack(pngPath, astcPath, bytes);
			}
			catch (e:Dynamic)
			{
				return null;
			}
		}

		// Bundled APK asset — allows shipping pre-compressed ASTC inside the APK.
		if (OflAssets.exists(astcPath) || Assets.exists(astcPath))
		{
			var bytes = OflAssets.getBytes(astcPath);
			if (bytes != null) {
				return _loadAndTrack(pngPath, astcPath, bytes);
			}
		}

		return null;
		#else
		return null;
		#end
	}

	/**
	 * Loads an .astc file from the filesystem and returns a GPU-backed BitmapData.
	 * Only call this after confirming the file exists and ASTC is supported.
	 * Note: textures loaded via this method are NOT tracked for context-loss recovery.
	 * Use tryLoad() for managed loading.
	 */
	public static function load(astcPath:String):Null<BitmapData>
	{
		#if (android && cpp)
		try
		{
			return loadFromBytes(astcPath, sys.io.File.getBytes(astcPath));
		}
		catch (e:Dynamic)
		{
			return null;
		}
		#else
		return null;
		#end
	}

	/**
	 * Uploads already-read ASTC bytes to the GPU and returns a BitmapData.
	 * Shared by both the filesystem and bundled-asset paths.
	 * Note: textures loaded via this method are NOT tracked for context-loss recovery.
	 * Use tryLoad() for managed loading.
	 */
	public static function loadFromBytes(astcPath:String, bytes:haxe.io.Bytes):Null<BitmapData>
	{
		#if (android && cpp)
		try
		{
			var result = _loadInternal(astcPath, bytes);
			return result == null ? null : result.bitmap;
		}
		catch (e:Dynamic)
		{
			return null;
		}
		#else
		return null;
		#end
	}

	// ---------------------------------------------------------------------------

	#if (android && cpp)

	/**
	 * Loads ASTC bytes, wraps in BitmapData, and registers in the recovery map
	 * so the texture survives an OpenGL context loss/restore cycle.
	 */
	static function _loadAndTrack(pngPath:String, astcPath:String, bytes:haxe.io.Bytes):Null<BitmapData>
	{
		try
		{
			var result = _loadInternal(astcPath, bytes);
			if (result == null) return null;

			// Keep the compressed bytes in RAM for small textures so context
			// restoration can skip the disk I/O round-trip. The bytes reference
			// is shared (no copy) — we just prevent it from being GC'd.
			var payloadSize = bytes.length - HEADER_SIZE;
			var cached:Null<haxe.io.Bytes> = (payloadSize <= BYTES_CACHE_LIMIT) ? bytes : null;

			_recovery.set(pngPath, {
				astcPath:    astcPath,
				rectTex:     result.rectTex,
				width:       result.width,
				height:      result.height,
				glFormat:    result.glFormat,
				cachedBytes: cached
			});

			return result.bitmap;
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	/**
	 * Parses the ASTC header, uploads the payload to the GPU, and returns the
	 * BitmapData together with the metadata needed for context-loss re-upload.
	 */
	static function _loadInternal(path:String, bytes:haxe.io.Bytes):Null<{bitmap:BitmapData, rectTex:RectangleTexture, width:Int, height:Int, glFormat:Int}>
	{
		if (bytes.length < HEADER_SIZE) return null;

		// Verify ASTC magic bytes
		if (bytes.get(0) != MAGIC_0 || bytes.get(1) != MAGIC_1 ||
			bytes.get(2) != MAGIC_2 || bytes.get(3) != MAGIC_3) {
			return null;
		}

		// Parse ASTC header
		// Block dimensions (3 bytes): [x, y, z]
		var bw:Int = bytes.get(4);
		var bh:Int = bytes.get(5);
		// Block coordinate dimensions (3 x 4 bytes, little-endian)
		var w:Int = bytes.get(8)  | (bytes.get(9) << 8);
		var h:Int = bytes.get(12) | (bytes.get(13) << 8);

		var glFormat:Int = blockSizeToGlFormat(bw, bh);
		if (glFormat == 0) return null;

		var context3D:Null<Context3D> = FlxG.stage.stage3Ds[0].context3D;
		if (context3D == null) return null;
		var gl = context3D.gl;

		// Create GPU texture
		var rectTex:RectangleTexture = context3D.createRectangleTexture(w, h, Context3DTextureFormat.BGRA, false);

		// Upload compressed ASTC data directly
		var compressedTex = _uploadCompressed(gl, bytes, w, h, glFormat);
		if (compressedTex == 0) return null;

		// Steal the GL handle from the wrapper
		rectTex.__textureID = compressedTex;

		// Create BitmapData wrapper around the GPU texture
		var bitmap:BitmapData = BitmapData.fromTexture(rectTex);

		return {bitmap: bitmap, rectTex: rectTex, width: w, height: h, glFormat: glFormat};
	}

	/**
	 * Uploads ASTC-compressed pixel data to the GPU via glCompressedTexImage2D.
	 * Returns the new GL texture handle, or 0 on failure.
	 */
	static function _uploadCompressed(gl:Dynamic, bytes:haxe.io.Bytes, w:Int, h:Int, glFormat:Int):Int
	{
		try
		{
			#if lime >= "8.0.0"
			var data:UInt8Array = new UInt8Array(bytes.length - HEADER_SIZE);
			for (i in 0...data.length) {
				data[i] = bytes.get(HEADER_SIZE + i);
			}
			#else
			var data:lime.utils.UInt8Array = new lime.utils.UInt8Array(bytes.length - HEADER_SIZE);
			for (i in 0...data.length) {
				data[i] = bytes.get(HEADER_SIZE + i);
			}
			#end

			var p:Int = 0;
			var mode:Int = 0x1902; // GL_TEXTURE_2D
			var level:Int = 0;
			var internalformat:Int = glFormat;
			var width:Int = w;
			var height:Int = h;
			var border:Int = 0;
			var imageSize:Int = data.length;

			// Call glCompressedTexImage2D via the GL context
			Reflect.callMethod(gl, Reflect.field(gl, "compressedTexImage2D"), [mode, level, internalformat, width, height, border, imageSize, data]);

			return 1; // Success indicator (actual handle managed by RectangleTexture)
		}
		catch (e:Dynamic)
		{
			return 0;
		}
	}

	/**
	 * Re-uploads all tracked ASTC textures after an OpenGL context loss/restore.
	 *
	 * For each tracked entry:
	 *   • glFormat != 0 (ASTC mode): uses cachedBytes if available (no I/O for
	 *     small textures), else re-reads from disk/APK. On missing file, falls
	 *     through to PNG fallback.
	 *   • glFormat == 0 (PNG fallback mode): re-uploads from the original PNG.
	 *
	 * On the initial CONTEXT3D_CREATE (before any ASTC textures are loaded) the
	 * recovery map is empty and this function returns immediately.
	 */
	static function _onContextRestored(_:Dynamic):Void
	{
		#if (android && cpp)
		var context3D:Null<Context3D> = FlxG.stage.stage3Ds[0].context3D;
		if (context3D == null) return;
		var gl = context3D.gl;

		var restored = 0;
		var failed = 0;
		var toRemove:Array<String> = [];

		for (pngPath => entry in _recovery)
		{
			// If the graphic is no longer in FlxG.bitmap the sprite that owned it was
			// destroyed without going through FunkinCache.removeFromCache.
			// There is nothing left to restore — skip the GPU upload and
			// evict this entry so _recovery stays lean.
			if (!FlxG.bitmap.checkCache(pngPath))
			{
				toRemove.push(pngPath);
				continue;
			}

			// PNG fallback mode — the .astc was missing on a previous restore;
			// this entry now permanently uses the PNG source.
			if (entry.glFormat == 0)
			{
				if (_restoreFromPng(context3D, pngPath))
					restored++;
				else
				{
					toRemove.push(pngPath);
					failed++;
				}
				continue;
			}

			// ASTC mode: prefer in-RAM cached bytes (small textures), otherwise
			// re-read from disk/APK to avoid an I/O stall only when necessary.
			var bytes:Null<haxe.io.Bytes> = entry.cachedBytes;
			if (bytes == null)
			{
				try
				{
					if (sys.FileSystem.exists(entry.astcPath))
						bytes = sys.io.File.getBytes(entry.astcPath);
					else if (OflAssets.exists(entry.astcPath))
						bytes = OflAssets.getBytes(entry.astcPath);
				}
				catch (e:Dynamic) {}
			}

			if (bytes == null)
			{
				// .astc file disappeared (DLC removed, SD-card corruption, etc.).
				// Attempt PNG fallback so live sprites are not permanently black.
				if (_restoreFromPng(context3D, pngPath))
					restored++;
				else
				{
					toRemove.push(pngPath);
					failed++;
				}
				continue;
			}

			var freshTex = _uploadCompressed(gl, bytes, entry.width, entry.height, entry.glFormat);
			if (freshTex == 0)
			{
				// GL upload error (driver-side failure). Skip and log.
				failed++;
				continue;
			}

			// The old __textureID is a dead handle after context loss; the driver
			// already freed all GPU resources. Overwrite with the fresh handle.
			// The BitmapData holds a reference to this same RectangleTexture, so
			// the renderer automatically uses the new handle on the next draw.
			entry.rectTex.__textureID = freshTex;
			restored++;
		}

		for (key in toRemove)
			_recovery.remove(key);

		if (restored > 0 || failed > 0)
			trace('[AstcLoader] Context restored: $restored textures re-uploaded, $failed failed');
		#end
	}

	/**
	 * Restores a tracked texture from its PNG counterpart.
	 *
	 * Creates a temporary RectangleTexture, uploads the PNG BitmapData to it
	 * via OpenFL's standard path (handles BGRA/RGBA format internally), then
	 * transfers the GL handle to entry.rectTex. Sets the temporary wrapper's
	 * __textureID to 0 so any future cleanup call on it is a harmless no-op.
	 *
	 * Permanently marks the entry as PNG mode (glFormat = 0) so all subsequent
	 * context-restore cycles also re-upload from PNG without retrying the ASTC.
	 */
	static function _restoreFromPng(context3D:Context3D, pngPath:String):Bool
	{
		var entry = _recovery.get(pngPath);
		if (entry == null) return false;

		var pngBitmap:Null<BitmapData> = null;
		try
		{
			// Mirrors Paths.image: filesystem first (external storage / mods, absolute path),
			// then OflAssets for APK-bundled assets (relative path).
			if (sys.FileSystem.exists(pngPath))
				pngBitmap = BitmapData.fromFile(pngPath);
			else if (OflAssets.exists(pngPath))
				// useCache=false: always decode fresh
				pngBitmap = OflAssets.getBitmapData(pngPath, false);
		}
		catch (e:Dynamic) {}

		if (pngBitmap == null)
		{
			return false;
		}

		if (pngBitmap.width != entry.width || pngBitmap.height != entry.height)
			trace('[AstcLoader] PNG fallback size mismatch for $pngPath');

		// Upload PNG pixels via OpenFL's standard path into a temporary RectangleTexture,
		// then steal its GL handle.
		var tempTex:RectangleTexture = context3D.createRectangleTexture(
			pngBitmap.width, pngBitmap.height, Context3DTextureFormat.BGRA, false);
		tempTex.uploadFromBitmapData(pngBitmap);

		var handle = tempTex.__textureID;
		tempTex.__textureID = 0; // orphan wrapper — handle ownership moves to entry.rectTex
		entry.rectTex.__textureID = handle;
		pngBitmap.dispose();

		// Mark entry as PNG mode for all future context-restore cycles.
		entry.glFormat = 0;
		entry.cachedBytes = null; // ASTC bytes no longer needed

		return true;
	}

	/**
	 * Maps an ASTC block size to the corresponding GL_COMPRESSED_RGBA_ASTC_*_KHR
	 * constant (RGBA linear variants, 0x93B0-0x93BD).
	 * Returns 0 for unknown block sizes.
	 */
	static function blockSizeToGlFormat(bw:Int, bh:Int):Int
	{
		return switch ([bw, bh])
		{
			case [4, 4]:   0x93B0; // GL_COMPRESSED_RGBA_ASTC_4x4_KHR
			case [5, 4]:   0x93B1;
			case [5, 5]:   0x93B2; // GL_COMPRESSED_RGBA_ASTC_5x5_KHR
			case [6, 5]:   0x93B3;
			case [6, 6]:   0x93B4; // GL_COMPRESSED_RGBA_ASTC_6x6_KHR
			case [8, 5]:   0x93B5;
			case [8, 6]:   0x93B6;
			case [8, 8]:   0x93B7; // GL_COMPRESSED_RGBA_ASTC_8x8_KHR
			case [10, 5]:  0x93B8;
			case [10, 6]:  0x93B9;
			case [10, 8]:  0x93BA;
			case [10, 10]: 0x93BB; // GL_COMPRESSED_RGBA_ASTC_10x10_KHR
			case [12, 10]: 0x93BC;
			case [12, 12]: 0x93BD; // GL_COMPRESSED_RGBA_ASTC_12x12_KHR
			default: 0;
		};
	}

	/**
	 * Derives the ASTC file path from a PNG asset path.
	 * The .astc file lives next to the .png — only the extension changes.
	 *
	 *   assets/images/characters/bf.png  →  assets/images/characters/bf.astc
	 *   /sdcard/.WashosEngine/assets/images/bf.png
	 *     → /sdcard/.WashosEngine/assets/images/bf.astc
	 */
	public static function deriveAstcPath(pngPath:String):Null<String>
	{
		if (!pngPath.endsWith('.png')) return null;
		return pngPath.substr(0, pngPath.length - 4) + '.astc';
	}

	#end // android && cpp
}
