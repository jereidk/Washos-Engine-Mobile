package mobile.backend;

import lime.app.Application;
/**
 * @Author LumiCoder
 */
class PopUp
{
    public static function showAlert(title:String, message:String, buttonLabel:String = "OK"):Void
    {
        #if android
        Tools.showAlertDialog(title, message, {name: buttonLabel, func: null}, null);
        #elseif ios
        Application.current.window.alert(message, title);
        #else
        trace('$title: $message');
        Application.current.window.alert(message, title);
        #end
    }
    public static function showConfirm(title:String, message:String, yesLabel:String = "Yes", noLabel:String = "No", onYes:Void->Void, ?onNo:Void->Void):Void
    {
        #if android
        Tools.showAlertDialog(title, message, {name: yesLabel, func: onYes}, {name: noLabel, func: onNo});
        #else
        Application.current.window.alert(message, title);
        if (onYes != null) onYes(); 
        #end
    }
}