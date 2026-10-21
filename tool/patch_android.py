"""Adapte le projet Android généré par `flutter create` aux besoins de TroDañs.

Le dossier android/ n'est pas versionné : il est régénéré à chaque compilation,
puis ce script ajoute les permissions, le service de lecture en arrière-plan
(just_audio_background) et le nom affiché de l'appli.
"""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
manifest = root / "android/app/src/main/AndroidManifest.xml"
text = manifest.read_text(encoding="utf-8")

if "MANAGE_EXTERNAL_STORAGE" not in text:
    if "xmlns:tools" not in text:
        text = text.replace(
            'xmlns:android="http://schemas.android.com/apk/res/android"',
            'xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    xmlns:tools="http://schemas.android.com/tools"',
            1,
        )
    permissions = """
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" tools:ignore="ScopedStorage" />
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
"""
    text = text.replace("<application", permissions + "    <application", 1)
    text = re.sub(r'android:label="[^"]*"', 'android:label="TroDañs"', text, count=1)
    text = text.replace(
        "<application",
        '<application\n        android:requestLegacyExternalStorage="true"',
        1,
    )
    services = """
        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
    </application>"""
    text = text.replace("</application>", services, 1)
    manifest.write_text(text, encoding="utf-8")
    print("AndroidManifest.xml adapté")

activities = list((root / "android/app/src/main").rglob("MainActivity.*"))
if not activities:
    sys.exit("MainActivity introuvable")
for act in activities:
    src = act.read_text(encoding="utf-8")
    src = src.replace(
        "import io.flutter.embedding.android.FlutterActivity",
        "import com.ryanheise.audioservice.AudioServiceActivity",
    )
    src = re.sub(r"FlutterActivity\(\)", "AudioServiceActivity()", src)
    src = re.sub(r"extends FlutterActivity", "extends AudioServiceActivity", src)
    act.write_text(src, encoding="utf-8")
    print(f"{act.name} adapté")
