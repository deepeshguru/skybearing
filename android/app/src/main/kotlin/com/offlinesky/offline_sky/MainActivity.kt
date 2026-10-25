package com.offlinesky.offline_sky

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.view.Surface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.cos
import kotlin.math.sin

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.offlinesky.sky/orientation"
    private val eventChannelName = "com.offlinesky.sky/orientation/events"
    private var eventSink: EventChannel.EventSink? = null
    private var sensorManager: SensorManager? = null
    private var rotationSensor: Sensor? = null
    private var sensorListener: SensorEventListener? = null
    private var observerLatitude: Double? = null
    private var observerLongitude: Double? = null
    private var observerElevation = 0.0
    private var accuracyStatus = SensorManager.SENSOR_STATUS_UNRELIABLE

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setObserverLocation" -> {
                        observerLatitude = call.argument<Number>("latitude")?.toDouble()
                        observerLongitude = call.argument<Number>("longitude")?.toDouble()
                        observerElevation = call.argument<Number>("elevation")?.toDouble() ?: 0.0
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                    startOrientationUpdates()
                }

                override fun onCancel(arguments: Any?) {
                    stopOrientationUpdates()
                    eventSink = null
                }
            })
    }

    override fun onPause() {
        stopOrientationUpdates()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        if (eventSink != null) startOrientationUpdates()
    }

    private fun startOrientationUpdates() {
        if (sensorListener != null) return
        val manager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        sensorManager = manager
        rotationSensor = manager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            ?: manager.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
        val sensor = rotationSensor
        if (sensor == null) {
            eventSink?.success(mapOf("available" to false, "quality" to "unavailable"))
            return
        }

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (event.sensor.type == sensor.type) emitOrientation(event)
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
                accuracyStatus = accuracy
            }
        }
        sensorListener = listener
        if (!manager.registerListener(
                listener,
                sensor,
                SensorManager.SENSOR_DELAY_GAME,
                Handler(Looper.getMainLooper()),
            )
        ) {
            sensorListener = null
            eventSink?.success(mapOf("available" to false, "quality" to "unavailable"))
        }
    }

    private fun stopOrientationUpdates() {
        val listener = sensorListener ?: return
        sensorManager?.unregisterListener(listener)
        sensorListener = null
    }

    private fun emitOrientation(event: SensorEvent) {
        val matrix = FloatArray(9)
        SensorManager.getRotationMatrixFromVector(matrix, event.values)
        val forward = deviceToWorld(matrix, 0.0, 0.0, -1.0)
        val (screenRightAxis, screenUpAxis) = screenAxes()
        val right = deviceToWorld(matrix, screenRightAxis[0], screenRightAxis[1], 0.0)
        val up = deviceToWorld(matrix, screenUpAxis[0], screenUpAxis[1], 0.0)
        val declination = observerLatitude?.let { latitude ->
            observerLongitude?.let { longitude ->
                GeomagneticField(
                    latitude.toFloat(), longitude.toFloat(), observerElevation.toFloat(),
                    System.currentTimeMillis(),
                ).declination.toDouble()
            }
        } ?: 0.0

        val trueForward = magneticToTrue(forward, declination)
        val trueRight = magneticToTrue(right, declination)
        val trueUp = magneticToTrue(up, declination)
        val reportedAccuracy = if (
            event.values.size > 4 && event.values[4].isFinite() && event.values[4] > 0f
        ) {
            Math.toDegrees(event.values[4].toDouble())
        } else {
            null
        }
        val quality = when {
            accuracyStatus == SensorManager.SENSOR_STATUS_UNRELIABLE -> "low"
            reportedAccuracy != null && reportedAccuracy < 12 -> "high"
            reportedAccuracy != null && reportedAccuracy < 35 -> "medium"
            accuracyStatus == SensorManager.SENSOR_STATUS_ACCURACY_HIGH -> "high"
            accuracyStatus == SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM -> "medium"
            else -> "low"
        }
        val payload = mutableMapOf<String, Any>(
            "available" to true,
            "northReference" to if (observerLatitude != null) "true" else "magnetic",
            "quality" to quality,
            "cameraEast" to trueForward[0],
            "cameraNorth" to trueForward[1],
            "cameraUp" to trueForward[2],
            "rightEast" to trueRight[0],
            "rightNorth" to trueRight[1],
            "rightUp" to trueRight[2],
            "upEast" to trueUp[0],
            "upNorth" to trueUp[1],
            "upUp" to trueUp[2],
        )
        if (reportedAccuracy != null) payload["headingAccuracyDegrees"] = reportedAccuracy
        eventSink?.success(payload)
    }

    private fun screenAxes(): Pair<DoubleArray, DoubleArray> {
        return when (windowManager.defaultDisplay.rotation) {
            Surface.ROTATION_90 -> Pair(doubleArrayOf(0.0, -1.0), doubleArrayOf(1.0, 0.0))
            Surface.ROTATION_180 -> Pair(doubleArrayOf(-1.0, 0.0), doubleArrayOf(0.0, -1.0))
            Surface.ROTATION_270 -> Pair(doubleArrayOf(0.0, 1.0), doubleArrayOf(-1.0, 0.0))
            else -> Pair(doubleArrayOf(1.0, 0.0), doubleArrayOf(0.0, 1.0))
        }
    }

    private fun deviceToWorld(matrix: FloatArray, x: Double, y: Double, z: Double): DoubleArray {
        return doubleArrayOf(
            matrix[0] * x + matrix[1] * y + matrix[2] * z,
            matrix[3] * x + matrix[4] * y + matrix[5] * z,
            matrix[6] * x + matrix[7] * y + matrix[8] * z,
        )
    }

    private fun magneticToTrue(vector: DoubleArray, declinationDegrees: Double): DoubleArray {
        val declination = Math.toRadians(declinationDegrees)
        val east = vector[0]
        val north = vector[1]
        return doubleArrayOf(
            east * cos(declination) + north * sin(declination),
            -east * sin(declination) + north * cos(declination),
            vector[2],
        )
    }
}
