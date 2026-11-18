package com.seaky.smplayer_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodChannel

class MusicSharingService : Service() {
    private var engine: FlutterEngine? = null
    private var management: MethodChannel? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            MusicSharingConfiguration.setStartupEnabled(this, false)
            management?.invokeMethod("stopSharing", null)
            return START_NOT_STICKY
        }
        if (engine != null) return START_NOT_STICKY
        val manager = getSystemService(NotificationManager::class.java)
        val chinese = resources.configuration.locales[0].language == "zh"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(CHANNEL,
                if (chinese) "后台音乐共享" else "Background music sharing", NotificationManager.IMPORTANCE_LOW))
        }
        val open = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(this, 1,
            Intent(this, MusicSharingService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = Notification.Builder(this, CHANNEL)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(if (chinese) "音乐共享正在运行" else "Music sharing is running")
            .setContentText(if (chinese) "已配对设备可连接，点击打开播放器管理共享" else "Paired devices can connect. Tap to manage sharing.")
            .setContentIntent(open).setOngoing(true)
            .addAction(Notification.Action.Builder(null,
                if (chinese) "停止共享" else "Stop sharing", stop).build()).build()
        startForeground(4521, notification)
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)
        val next = FlutterEngine(this)
        engine = next
        MusicSharingConfiguration.register(this, next.dartExecutor.binaryMessenger)
        management = MethodChannel(next.dartExecutor.binaryMessenger, "smplayer_flutter/background_sharing")
        next.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(
            loader.findAppBundlePath(), "backgroundSharingMain"))
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        engine?.destroy()
        engine = null
        super.onDestroy()
    }

    companion object {
        const val ACTION_STOP = "com.seaky.smplayer_flutter.STOP_SHARING"
        private const val CHANNEL = "music_sharing"
    }
}

class MusicSharingBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        if (!MusicSharingConfiguration.startupEnabled(context)) return
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)
            != android.content.pm.PackageManager.PERMISSION_GRANTED) return
        val service = Intent(context, MusicSharingService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(service)
        else context.startService(service)
    }
}
