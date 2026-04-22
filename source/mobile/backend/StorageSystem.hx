package mobile.backend;

import openfl.utils.Assets;
import sys.FileSystem;
import sys.io.File;
import haxe.Http;
import lime.system.JNI;
import haxe.zip.Reader;
#if android
import extension.androidtools.os.Environment;
import extension.androidtools.Settings;
import extension.androidtools.Permissions;
import extension.androidtools.os.Build.VERSION;
import extension.androidtools.os.Build.VERSION_CODES;
import extension.androidtools.Tools;
#end
import lime.app.Application;
import haxe.io.Path;
import haxe.io.Bytes;
import openfl.utils.ByteArray;

using StringTools;

/** 
 * @Authors StarNova (Cream.BR), LumiCoder (FNF BR)
 * @version: 0.1.5 (Indev)
**/
class StorageSystem
{
	private static var folderName(get, never):String;

	private static function get_folderName():String
	{
		return Application.current.meta.get('file');
	}

	public static inline function getStorageDirectory():String
		return #if android Path.addTrailingSlash(Environment.getExternalStorageDirectory() + '/.' + folderName) #elseif ios lime.system.System.documentsDirectory #else Sys.getCwd() #end;

	public static function getDirectory():String
	{
		#if android
		return Environment.getExternalStorageDirectory() + '/.' + folderName + '/';
		#elseif ios
		return lime.system.System.documentsDirectory;
		#else
		return Sys.getCwd();
		#end
	}

	/**
	 * Request permission to access the files
	 */
	public static function getPermissions():Void
    {
        #if mobile
        #if android
        if (VERSION.SDK_INT >= VERSION_CODES.TIRAMISU) {
            Permissions.requestPermissions(['READ_MEDIA_IMAGES', 'READ_MEDIA_VIDEO', 'READ_MEDIA_AUDIO', 'READ_MEDIA_VISUAL_USER_SELECTED']);
        } else {
            Permissions.requestPermissions(['READ_EXTERNAL_STORAGE', 'WRITE_EXTERNAL_STORAGE']);
        }

        if (VERSION.SDK_INT >= VERSION_CODES.R) {
            if (!Environment.isExternalStorageManager()) Settings.requestSetting('MANAGE_APP_ALL_FILES_ACCESS_PERMISSION');
        }
        #end

        try {
            var path = getDirectory();
            if (!FileSystem.exists(path)) FileSystem.createDirectory(path);

            if (!FileSystem.exists(path + "assets") && !FileSystem.exists(path + "mods")) 
            {
                #if android
                Tools.showAlertDialog("Download", "Assets Not Found. Download now?", 
                {name: "Yes", func: function() { downloadZipRecursive(); }}, 
                {name: "No", func: function() { lime.system.System.exit(0); }});
                downloadZipRecursive();
                #end
            }
        } catch (e:Dynamic) { trace("Erro: " + e); }
        #end
    }

	/**
	 * Saves a file in 'files' Directory
	 */
	#if sys
	public static function saveContent(name:String = 'file', ext:String = '.json', data:String = ''):Void
	{
		var saveFolder:String = Path.join([getDirectory(), "files"]);
		var fullPath:String = Path.join([saveFolder, name + ext]);

		try
		{
			if (!FileSystem.exists(saveFolder))
			{
				FileSystem.createDirectory(saveFolder);
			}

			File.saveContent(fullPath, data);

			#if android
			Tools.showAlertDialog("Sucess!", "File saved in:\n" + saveFolder + "/" + name + ext, {name: "OK", func: null}, null);
			#elseif ios
			Application.current.window.alert("File saved in:\n" + saveFolder + "/" + name + ext, "Sucess!");
			#end
		}
		catch (e:haxe.Exception)
		{
			var errorMsg:String = "Error on Save!:\n" + e.message;
			trace('Error ' + errorMsg);

			#if android
			Tools.showAlertDialog("Error saving file", errorMsg, {name: "Close", func: null}, null);
			#elseif ios
			Application.current.window.alert(errorMsg, "Error saving file");
			#end
		}
	}
	#end
	public static function downloadZipRecursive(?url:String):Void
    {
        if (url == null) 
            url = "https://github.com/DeveloperPorting/Psych-Engine-0.7.3-Mobile/releases/download/zip/assets.zip";
            
        var savePath = getDirectory() + "temp.zip";

        #if android
        try {
            var jniCall = JNI.createStaticMethod("mobile/backend/java/FileUtils", "downloadFile", "(Ljava/lang/String;Ljava/lang/String;)Z");
            
            trace("Starting ZIP Download...");
            var success:Bool = jniCall(url, savePath);

            if (success) {
                trace("Successfully Downloaded.");
                extractZip(savePath, getDirectory());
            } else {
                trace("Error on Download, Please Check Your Connection.");
                Tools.showAlertDialog("Error", "Server side error. Check your connection.", {name: "Retry", func: function() { downloadZipRecursive(url); }}, null);
            }
        } catch(e:Dynamic) {
            trace("JNI Error: " + e);
        }
        #end
	}

    private static function extractZip(zipPath:String, outputDir:String):Void
    {
        try {
            trace("Starting ZIP Extraction...");
            var bytes = File.getBytes(zipPath);
            var input = new haxe.io.BytesInput(bytes);
            var reader = new Reader(input);
            var entries = reader.read();
            
            var targetAssetsFolder = Path.addTrailingSlash(outputDir) + "assets/";
            
            if (!FileSystem.exists(targetAssetsFolder)) 
                FileSystem.createDirectory(targetAssetsFolder);

            for (entry in entries) {
                var fileName = entry.fileName;
                if (fileName == "" || fileName == null) continue;

                var finalPath = Path.join([targetAssetsFolder, fileName]);

                if (entry.fileSize == 0) { 
                    if (!FileSystem.exists(finalPath)) 
                        FileSystem.createDirectory(finalPath);
                } else { 
                    var dir = Path.directory(finalPath);
                    if (!FileSystem.exists(dir)) 
                        FileSystem.createDirectory(dir);
                    
                    var unzippedData = Reader.unzip(entry);
                    File.saveBytes(finalPath, unzippedData);
                }
            }

            trace("Extraction Complete!");
            FileSystem.deleteFile(zipPath);
            
            #if android
            Tools.showAlertDialog("Sucess", "Assets Extracted Successfully. Restart the Game.", {name: "OK", func: function() { lime.system.System.exit(0); }}, null);
            #end
        } catch(e:Dynamic) {
            trace("Error on Extraction: " + e);
            #if android
            Tools.showAlertDialog("Error During Extraction", Std.string(e), {name: "OK", func: null}, null);
            #end
        }
    }
	
   /**
   * Recursively copies any folder from the APK (assets, mods, etc.) to the external directory
   * @param sourceDir The source path within the APK (e.g., "assets/" or "mods/")
   * @param targetDir Destination path (optional, uses getDirectory() + sourceDir if null)
   * @param forceOverwrite If true, always replace files to ensure updates are applied
   */
  public static function copyFromAPK(sourceDir:String, targetDir:String = null, forceOverwrite:Bool = true):Void {
    #if mobile
    if (!StringTools.endsWith(sourceDir, "/")) sourceDir += "/";
    
    if (targetDir == null) {
        targetDir = getDirectory() + sourceDir;
    }
    if (!StringTools.endsWith(targetDir, "/")) targetDir += "/";

    try {
        if (!sys.FileSystem.exists(targetDir)) {
            createDirectoryRecursive(targetDir);
        }

        var assetList:Array<String> = openfl.utils.Assets.list();
        var copiedCount = 0;

        for (assetPath in assetList) {
            if (StringTools.startsWith(assetPath, sourceDir)) {
                var relativePath = assetPath.substring(sourceDir.length);
                if (relativePath == "") continue;
                
                var fullTargetPath = targetDir + relativePath;
                var targetFolder = haxe.io.Path.directory(fullTargetPath);
                
                if (!sys.FileSystem.exists(targetFolder)) {
                    createDirectoryRecursive(targetFolder);
                }
                
                if (openfl.utils.Assets.exists(assetPath)) {
                    var shouldCopy = true;
                    
                    if (sys.FileSystem.exists(fullTargetPath) && !forceOverwrite) {
                        shouldCopy = false;
                    }
                    
                    if (shouldCopy) {
                        var fileBytes:haxe.io.Bytes = null;
                        
                        try {
                            fileBytes = lime.utils.Assets.getBytes(assetPath);
                        } catch(e:Dynamic) {}
                        
                        if (fileBytes == null) {
                            try {
                                fileBytes = openfl.utils.Assets.getBytes(assetPath);
                            } catch(e:Dynamic) {}
                        }
                        
                        if (fileBytes != null) {
                            sys.io.File.saveBytes(fullTargetPath, fileBytes);
                            trace('Copiado (Binário/Áudio): $assetPath -> $fullTargetPath');
                            copiedCount++;
                        } else {
                            var textData = openfl.utils.Assets.getText(assetPath);
                            if (textData != null) {
                                sys.io.File.saveContent(fullTargetPath, textData);
                                trace('Copiado (Texto): $assetPath -> $fullTargetPath');
                                copiedCount++;
                            } else {
                                trace('Aviso: Impossível extrair $assetPath. Pode estar protegido ou mal configurado no project.xml.');
                            }
                        }
                    }
                }
            }
        }
        trace('Cópia concluída com sucesso! $copiedCount arquivos transferidos para: $targetDir');
    } catch (e:Dynamic) {
        trace('Erro crítico ao copiar arquivos: $e');
        lime.app.Application.current.window.alert('Erro de Sistema', 'Falha ao copiar os arquivos do jogo. Verifique as permissões de armazenamento.');
    }
    #end
  }

  /**
   * Creates folders recursively in a safe way, fixing the absolute paths bug in Android
   */
  private static function createDirectoryRecursive(path:String):Void {
    #if mobile
    if (sys.FileSystem.exists(path)) return;
    
    var pathParts = path.split("/");
    var currentPath = "";
    
    if (StringTools.startsWith(path, "/")) {
        currentPath = "/";
        pathParts.shift();
    }
    
    for (part in pathParts) {
        if (part == "") continue;
        
        if (currentPath == "/") {
            currentPath += part;
        } else {
            currentPath += "/" + part;
        }
        
        if (!sys.FileSystem.exists(currentPath)) {
            try {
                sys.FileSystem.createDirectory(currentPath);
            } catch (e:Dynamic) {
                trace('Erro ao criar subpasta $currentPath: $e');
            }
        }
    }
    #end
  }
}