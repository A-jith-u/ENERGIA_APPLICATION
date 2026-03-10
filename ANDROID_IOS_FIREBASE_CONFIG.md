# Android & iOS Configuration for Firebase Push Notifications

## 📱 Android Configuration

### 1. AndroidManifest.xml
**Location**: `android/app/src/main/AndroidManifest.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.energia">

    <!-- Internet permission (required for Firebase) -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <!-- Notification permission (Android 13+) -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application
        android:label="@string/app_name"
        android:icon="@mipmap/ic_launcher">
        
        <!-- Main Activity -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <!-- Meta-data for Firebase configuration -->
        <meta-data
            android:name="com.google.firebase.ml.vision.DEPENDENCIES"
            android:value="com.google.firebase.messaging" />

    </application>

</manifest>
```

### 2. Build Gradle - Root
**Location**: `android/build.gradle`

```gradle
buildscript {
    ext.kotlin_version = '1.7.10'
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:7.3.0'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
        
        // Add Google Services plugin for Firebase
        classpath 'com.google.gms:google-services:4.3.15'
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = '../build'
subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}
subprojects {
    project.evaluationDependsOn(':app')
}

task clean(type: Delete) {
    delete rootProject.buildDir
}
```

### 3. Build Gradle - App Module
**Location**: `android/app/build.gradle`

```gradle
def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterRoot = localProperties.getProperty('flutter.sdk')
if (flutterRoot == null) {
    throw new GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
if (flutterVersionCode == null) {
    flutterVersionCode = '1'
}

def flutterVersionName = localProperties.getProperty('flutter.versionName')
if (flutterVersionName == null) {
    flutterVersionName = '1.0'
}

apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'
apply plugin: 'com.google.gms.google-services'  // Add this line
apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"

android {
    compileSdkVersion flutter.compileSdkVersion
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "com.example.energia"
        minSdkVersion flutter.minSdkVersion
        targetSdkVersion flutter.targetSdkVersion
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
        
        // Firebase requires at least minSdkVersion 19
        minSdkVersion 21
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
    
    // Firebase dependencies (usually added automatically by Flutter plugins)
    implementation 'com.google.firebase:firebase-core'
    implementation 'com.google.firebase:firebase-messaging'
}
```

### 4. MainActivity.kt
**Location**: `android/app/src/main/kotlin/com/example/energia/MainActivity.kt`

```kotlin
package com.example.energia

import io.flutter.embedding.android.FlutterFragmentActivity
import android.os.Build
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity: FlutterFragmentActivity() {
    
    companion object {
        private const val NOTIFICATION_PERMISSION_CODE = 101
    }
    
    override fun onResume() {
        super.onResume()
        
        // Request notification permission on Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this,
                    android.Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_CODE
                )
            }
        }
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        when (requestCode) {
            NOTIFICATION_PERMISSION_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    println("[Notifications] POST_NOTIFICATIONS permission granted")
                } else {
                    println("[Notifications] POST_NOTIFICATIONS permission denied")
                }
            }
        }
    }
}
```

### 5. Google Services JSON
**Location**: `android/app/google-services.json`

This file is auto-generated when you add Firebase to your Android project. Download from Firebase Console:
1. Firebase Console → Project Settings
2. Your apps → Android app
3. Download google-services.json
4. Place in `android/app/`

---

## 🍎 iOS Configuration

### 1. Podfile
**Location**: `ios/Podfile`

```ruby
# Podfile
platform :ios, '12.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join(
    File.dirname(__FILE__),
    'Flutter',
    'Flutter-Generated.xcconfig',
  ), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Flutter-Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_NOTIFICATIONS=1',
      ]
    end
  end
end
```

### 2. Runner Project Settings
**Location**: `ios/Runner.xcworkspace`

#### Add Push Notifications Capability
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Runner" project → "Runner" target
3. Go to "Signing & Capabilities"
4. Click "+ Capability"
5. Search for "Push Notifications"
6. Click to add

#### Configure APNs (Apple Push Notifications)
1. In Xcode: Signing & Capabilities → "+ Capability" → "Background Modes"
2. Check "Remote notifications"
3. Go to [Apple Developer Portal](https://developer.apple.com)
4. Create APNs certificate
5. In Firebase Console → Project Settings → iOS App
6. Upload APNs certificate

### 3. GoogleService-Info.plist
**Location**: `ios/Runner/GoogleService-Info.plist`

This file is auto-generated when you add Firebase to your iOS project. Download from Firebase Console:
1. Firebase Console → Project Settings
2. Your apps → iOS app
3. Download GoogleService-Info.plist
4. Add to Xcode (drag to Runner folder)

To add in Xcode:
1. Right-click on Runner folder in Xcode
2. Select "Add Files to Runner"
3. Select GoogleService-Info.plist
4. Make sure it's added to Runner target

### 4. Runner-Bridging-Header.h
**Location**: `ios/Runner/Runner-Bridging-Header.h` (create if doesn't exist)

```objc
//
//  Runner-Bridging-Header.h
//  Runner
//

#ifndef Runner_Bridging_Header_h
#define Runner_Bridging_Header_h

#import "GeneratedPluginRegistrant.h"
#import <Firebase/Firebase.h>

#endif /* Runner_Bridging_Header_h */
```

### 5. Info.plist Configuration
**Location**: `ios/Runner/Info.plist`

No special configuration needed, but ensure NSUserNotificationCenterDelegate is supported:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Other existing keys -->
    
    <!-- Notification permissions -->
    <key>NSRemoteNotificationPermission</key>
    <string>Remote notification permission</string>
    
</dict>
</plist>
```

---

## ✅ Checklist

### Android Setup
- [ ] Add INTERNET and POST_NOTIFICATIONS permissions to AndroidManifest.xml
- [ ] Update google-services plugin in build.gradle
- [ ] Add Firebase dependencies to app/build.gradle
- [ ] Download google-services.json and add to android/app/
- [ ] Update MainActivity.kt to request notification permission
- [ ] Test on Android device or emulator

### iOS Setup
- [ ] Update Podfile with proper configuration
- [ ] Add Push Notifications capability in Xcode
- [ ] Add Background Modes capability (Remote notifications)
- [ ] Upload APNs certificate to Firebase
- [ ] Download GoogleService-Info.plist and add to Xcode
- [ ] Configure Runner-Bridging-Header.h
- [ ] Test on iOS device (simulator won't receive push notifications)

### Common Issues
- [ ] Notification permission denied → Ask user in app
- [ ] Firebase not initialized → Check GoogleService files
- [ ] Android notifications don't appear → Check notification settings
- [ ] iOS notifications don't work → Verify APNs certificate
- [ ] Build fails → Run `flutter clean` and try again

---

## 🧪 Testing Notifications

### Android
```bash
# Test in emulator
flutter run

# Send test notification
python backend/send_push_notification.py "YOUR_TOKEN"
```

### iOS
```bash
# Test on real device only (simulator won't receive notifications)
flutter run -d <device_id>

# Send test notification
python backend/send_push_notification.py "YOUR_TOKEN"
```

---

## 📚 Additional Resources

- [Android Notification Setup](https://firebase.flutter.dev/docs/messaging/android-integration/)
- [iOS Notification Setup](https://firebase.flutter.dev/docs/messaging/ios-integration/)
- [Firebase Console](https://console.firebase.google.com)
- [Apple Developer Portal](https://developer.apple.com)
