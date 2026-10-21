package ir.bootic.store_app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import java.io.File
import java.util.UUID

/** Full-screen back-camera still capture. It never runs beside the live front camera. */
class GarmentCaptureActivity : Activity(), LifecycleOwner {
    private val cameraLifecycle = LifecycleRegistry(this)
    override val lifecycle: Lifecycle get() = cameraLifecycle
    private var provider: ProcessCameraProvider? = null
    private var imageCapture: ImageCapture? = null
    private var captureFile: File? = null
    private var takingPhoto = false
    private var finished = false
    private lateinit var previewView: PreviewView
    private lateinit var shutter: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        cameraLifecycle.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
        val cutoff = System.currentTimeMillis() - 24L * 60 * 60 * 1000
        File(filesDir, "capture-temp").listFiles()?.forEach {
            if (it.isFile && it.lastModified() < cutoff) it.delete()
        }
        buildUi()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            bindCamera()
        } else {
            requestPermissions(arrayOf(Manifest.permission.CAMERA), PERMISSION_REQUEST)
        }
    }

    override fun onStart() {
        super.onStart()
        cameraLifecycle.handleLifecycleEvent(Lifecycle.Event.ON_START)
    }

    override fun onResume() {
        super.onResume()
        cameraLifecycle.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
    }

    override fun onPause() {
        cameraLifecycle.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
        super.onPause()
    }

    override fun onStop() {
        provider?.unbindAll()
        provider = null
        cameraLifecycle.handleLifecycleEvent(Lifecycle.Event.ON_STOP)
        super.onStop()
    }

    override fun onDestroy() {
        provider?.unbindAll()
        cameraLifecycle.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        if (!isChangingConfigurations && !isFinishing) captureFile?.delete()
        super.onDestroy()
    }

    private fun buildUi() {
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        previewView = PreviewView(this).apply {
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            scaleType = PreviewView.ScaleType.FILL_CENTER
        }
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        root.addView(previewView, FrameLayout.LayoutParams(-1, -1))
        val controls = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            setPadding(24, 20, 24, 32)
            setBackgroundColor(0xAA000000.toInt())
        }
        controls.addView(TextView(this).apply {
            text = "عکس لباس؛ دوربین پشت"
            textSize = 18f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        })
        val buttons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        shutter = Button(this).apply {
            text = "ثبت عکس"
            isEnabled = false
            setOnClickListener { takePhoto() }
        }
        buttons.addView(shutter)
        buttons.addView(Button(this).apply {
            text = "انصراف"
            setOnClickListener { finishWith(null) }
        })
        controls.addView(buttons)
        root.addView(controls, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM))
        setContentView(root)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISSION_REQUEST) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) bindCamera()
        else {
            Toast.makeText(this, "اجازه دوربین داده نشد", Toast.LENGTH_SHORT).show()
            finishWith(null)
        }
    }

    private fun bindCamera() {
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener({
            if (isFinishing || isDestroyed) return@addListener
            try {
                val current = future.get()
                if (!current.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA)) {
                    Toast.makeText(this, "دوربین پشت در دسترس نیست", Toast.LENGTH_SHORT).show()
                    finishWith(null)
                    return@addListener
                }
                current.unbindAll()
                provider = current
                val preview = Preview.Builder().build().also { it.setSurfaceProvider(previewView.surfaceProvider) }
                val still = ImageCapture.Builder()
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                    .build()
                current.bindToLifecycle(this, CameraSelector.DEFAULT_BACK_CAMERA, preview, still)
                imageCapture = still
                shutter.isEnabled = true
            } catch (_: Exception) {
                Toast.makeText(this, "راه‌اندازی دوربین ممکن نشد", Toast.LENGTH_SHORT).show()
                finishWith(null)
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun takePhoto() {
        val capture = imageCapture ?: return
        if (takingPhoto) return
        takingPhoto = true
        shutter.isEnabled = false
        val folder = File(filesDir, "capture-temp")
        if (!folder.exists() && !folder.mkdirs()) {
            Toast.makeText(this, "فضای ذخیره‌سازی در دسترس نیست", Toast.LENGTH_SHORT).show()
            takingPhoto = false
            shutter.isEnabled = true
            return
        }
        val file = File(folder, "${UUID.randomUUID()}.jpg")
        captureFile = file
        val output = ImageCapture.OutputFileOptions.Builder(file).build()
        capture.takePicture(output, ContextCompat.getMainExecutor(this), object : ImageCapture.OnImageSavedCallback {
            override fun onImageSaved(result: ImageCapture.OutputFileResults) {
                if (finished) { file.delete(); return }
                if (!file.isFile || file.length() == 0L) {
                    file.delete()
                    takingPhoto = false
                    shutter.isEnabled = true
                    Toast.makeText(this@GarmentCaptureActivity, "فایل عکس معتبر نیست", Toast.LENGTH_SHORT).show()
                    return
                }
                finishWith(file)
            }

            override fun onError(exception: androidx.camera.core.ImageCaptureException) {
                file.delete()
                if (finished) return
                captureFile = null
                takingPhoto = false
                shutter.isEnabled = true
                Toast.makeText(this@GarmentCaptureActivity, "ثبت عکس ممکن نشد؛ دوباره تلاش کنید", Toast.LENGTH_SHORT).show()
            }
        })
    }

    private fun finishWith(file: File?) {
        if (finished) return
        finished = true
        if (file == null) {
            captureFile?.delete()
            setResult(RESULT_CANCELED)
        } else {
            setResult(RESULT_OK, Intent().putExtra("path", file.absolutePath))
        }
        finish()
    }

    @Deprecated("Use the native capture controls")
    override fun onBackPressed() { finishWith(null) }

    companion object { private const val PERMISSION_REQUEST = 7150 }
}
