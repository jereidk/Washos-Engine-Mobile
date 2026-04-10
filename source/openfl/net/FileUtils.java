package openfl.net;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelFileDescriptor;
import org.haxe.extension.Extension;
import java.io.FileOutputStream;

/** * @Authors LumiCoder, (FNF BR)
 * @version: 0.1.4
**/
public class FileUtils extends Extension {

    private static final int CREATE_FILE_CODE = 1024;
    private static final int PICK_FILE_CODE = 1025;
    private static String contentToSave = "";

    public static void saveFile(final String fileName, final String data) {
        if (data == null || data.isEmpty()) return;

        contentToSave = data;

        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                try {
                    Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                    intent.addCategory(Intent.CATEGORY_OPENABLE);
                    intent.setType("application/json");
                    intent.putExtra(Intent.EXTRA_TITLE, fileName);

                    if (Extension.mainActivity != null) {
                        Extension.mainActivity.startActivityForResult(intent, CREATE_FILE_CODE);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        });
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == CREATE_FILE_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                Uri uri = data.getData();
                if (uri != null) {
                    writeFileToUri(uri);
                }
            } else {
                contentToSave = ""; 
            }
            return true;
        }
        return false;
    }

    private static void writeFileToUri(Uri uri) {
        try {
            ParcelFileDescriptor pfd = Extension.mainActivity.getContentResolver().openFileDescriptor(uri, "wt");
            
            if (pfd != null) {
                FileOutputStream fileOutputStream = new FileOutputStream(pfd.getFileDescriptor());
                
                byte[] bytesToWrite = contentToSave.getBytes("UTF-8");
                
                fileOutputStream.write(bytesToWrite);
                fileOutputStream.flush();
                fileOutputStream.getFD().sync();
                fileOutputStream.close();
                pfd.close();
                
                contentToSave = ""; 
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}