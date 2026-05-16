package com.proeditor.pro_editor

import com.ryanheise.audioservice.AudioServiceActivity
import android.os.Bundle
import android.util.Log

class MainActivity: AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MainActivity", "Native onCreate completed")
    }
}
