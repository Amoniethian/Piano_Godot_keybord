package com.piano.godot.midi;

import android.content.Context;
import android.media.midi.MidiDevice;
import android.media.midi.MidiDeviceInfo;
import android.media.midi.MidiManager;
import android.media.midi.MidiOutputPort;
import android.media.midi.MidiReceiver;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.IOException;
import java.util.HashSet;
import java.util.Set;

/**
 * Godot 4.x Android plugin that bridges Android's MidiManager API
 * to GDScript, enabling USB MIDI keyboard input via Type-C / OTG.
 *
 * GDScript usage:
 *   var plugin = Engine.get_singleton("GodotMidiUSB")
 *   plugin.connect("midi_note_on", _on_midi_note_on)
 *   plugin.connect("midi_note_off", _on_midi_note_off)
 *   plugin.open_midi_devices()
 */
public class GodotMidiUSB extends GodotPlugin {

    private static final String TAG = "GodotMidiUSB";

    private MidiManager midiManager;
    private MidiDevice currentDevice;
    private MidiOutputPort currentOutputPort;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    // ── Constructor ──────────────────────────────────────────────────────────

    public GodotMidiUSB(Godot godot) {
        super(godot);
    }

    // ── GodotPlugin overrides ────────────────────────────────────────────────

    @NonNull
    @Override
    public String getPluginName() {
        return "GodotMidiUSB";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        // midi_note_on(pitch: int, velocity: int)
        signals.add(new SignalInfo("midi_note_on", Integer.class, Integer.class));
        // midi_note_off(pitch: int)
        signals.add(new SignalInfo("midi_note_off", Integer.class));
        // midi_device_connected(device_name: String)
        signals.add(new SignalInfo("midi_device_connected", String.class));
        // midi_device_disconnected(device_name: String)
        signals.add(new SignalInfo("midi_device_disconnected", String.class));
        return signals;
    }

    // ── Public API (exposed to GDScript via @UsedByGodot) ────────────────────

    /**
     * Call from GDScript to initialise MIDI scanning.
     * Registers a hotplug callback and opens any already-connected device.
     */
    @UsedByGodot
    public void open_midi_devices() {
        Context context = getActivity();
        if (context == null) {
            Log.e(TAG, "Cannot get Activity context");
            return;
        }

        midiManager = (MidiManager) context.getSystemService(Context.MIDI_SERVICE);
        if (midiManager == null) {
            Log.e(TAG, "MidiManager service not available on this device");
            return;
        }

        // Register for hotplug events (device plugged / unplugged)
        midiManager.registerDeviceCallback(deviceCallback, mainHandler);

        // Open the first already-connected MIDI device that has output ports
        MidiDeviceInfo[] devices = midiManager.getDevices();
        Log.i(TAG, "Found " + devices.length + " MIDI device(s) at startup");
        for (MidiDeviceInfo info : devices) {
            if (getOutputPortCount(info) > 0) {
                openDevice(info);
                break; // open only the first suitable device
            }
        }
    }

    /**
     * Call from GDScript to cleanly close the current MIDI connection.
     */
    @UsedByGodot
    public void close_midi_devices() {
        if (midiManager != null) {
            midiManager.unregisterDeviceCallback(deviceCallback);
        }
        closeCurrentDevice();
    }

    /**
     * Returns an array of connected MIDI device names (for debug / UI).
     */
    @UsedByGodot
    public String[] get_connected_devices() {
        if (midiManager == null) return new String[0];
        MidiDeviceInfo[] devices = midiManager.getDevices();
        String[] names = new String[devices.length];
        for (int i = 0; i < devices.length; i++) {
            names[i] = getDeviceName(devices[i]);
        }
        return names;
    }

    // ── Hotplug callback ─────────────────────────────────────────────────────

    private final MidiManager.DeviceCallback deviceCallback = new MidiManager.DeviceCallback() {
        @Override
        public void onDeviceAdded(MidiDeviceInfo info) {
            String name = getDeviceName(info);
            Log.i(TAG, "MIDI device connected: " + name);
            emitSignal("midi_device_connected", name);

            // Auto-open if we don't have a device yet
            if (currentDevice == null && getOutputPortCount(info) > 0) {
                openDevice(info);
            }
        }

        @Override
        public void onDeviceRemoved(MidiDeviceInfo info) {
            String name = getDeviceName(info);
            Log.i(TAG, "MIDI device disconnected: " + name);
            emitSignal("midi_device_disconnected", name);
            closeCurrentDevice();
        }
    };

    // ── Device open / close ──────────────────────────────────────────────────

    private void openDevice(MidiDeviceInfo info) {
        if (midiManager == null) return;

        midiManager.openDevice(info, new MidiManager.OnDeviceOpenedListener() {
            @Override
            public void onDeviceOpened(MidiDevice device) {
                if (device == null) {
                    Log.e(TAG, "Failed to open MIDI device");
                    return;
                }

                currentDevice = device;
                Log.i(TAG, "MIDI device opened: " + getDeviceName(info));

                // Open the first output port (output from device = input to us)
                MidiDeviceInfo deviceInfo = device.getInfo();
                MidiDeviceInfo.PortInfo[] ports = deviceInfo.getPorts();
                for (MidiDeviceInfo.PortInfo port : ports) {
                    if (port.getType() == MidiDeviceInfo.PortInfo.TYPE_OUTPUT) {
                        currentOutputPort = device.openOutputPort(port.getPortNumber());
                        if (currentOutputPort != null) {
                            currentOutputPort.connect(midiReceiver);
                            Log.i(TAG, "Connected to output port " + port.getPortNumber());
                        }
                        break;
                    }
                }
            }
        }, mainHandler);
    }

    private void closeCurrentDevice() {
        if (currentOutputPort != null) {
            try {
                currentOutputPort.disconnect(midiReceiver);
                currentOutputPort.close();
            } catch (IOException e) {
                Log.w(TAG, "Error closing output port", e);
            }
            currentOutputPort = null;
        }

        if (currentDevice != null) {
            try {
                currentDevice.close();
            } catch (IOException e) {
                Log.w(TAG, "Error closing device", e);
            }
            currentDevice = null;
        }
    }

    // ── MIDI data receiver ───────────────────────────────────────────────────

    private final MidiReceiver midiReceiver = new MidiReceiver() {
        @Override
        public void onSend(byte[] data, int offset, int count, long timestamp) {
            // Parse raw MIDI messages
            int i = offset;
            while (i < offset + count) {
                int status = data[i] & 0xFF;

                // Skip non-status bytes (running status not supported for simplicity)
                if (status < 0x80) {
                    i++;
                    continue;
                }

                int messageType = status & 0xF0;

                switch (messageType) {
                    case 0x90: // Note On
                        if (i + 2 < offset + count) {
                            int pitch = data[i + 1] & 0x7F;
                            int velocity = data[i + 2] & 0x7F;
                            if (velocity > 0) {
                                emitOnMainThread("midi_note_on", pitch, velocity);
                            } else {
                                // Note On with velocity 0 = Note Off
                                emitOnMainThread("midi_note_off", pitch);
                            }
                        }
                        i += 3;
                        break;

                    case 0x80: // Note Off
                        if (i + 2 < offset + count) {
                            int pitch = data[i + 1] & 0x7F;
                            emitOnMainThread("midi_note_off", pitch);
                        }
                        i += 3;
                        break;

                    case 0xA0: // Polyphonic Aftertouch
                    case 0xB0: // Control Change
                    case 0xE0: // Pitch Bend
                        i += 3; // 3-byte messages, skip
                        break;

                    case 0xC0: // Program Change
                    case 0xD0: // Channel Pressure
                        i += 2; // 2-byte messages, skip
                        break;

                    case 0xF0: // System messages
                        if (status == 0xF0) {
                            // SysEx: skip until 0xF7
                            while (i < offset + count && (data[i] & 0xFF) != 0xF7) {
                                i++;
                            }
                            i++; // skip 0xF7
                        } else if (status >= 0xF1 && status <= 0xF3) {
                            i += 2;
                        } else {
                            i += 1;
                        }
                        break;

                    default:
                        i++;
                        break;
                }
            }
        }
    };

    /**
     * Emit signal on the main thread (Godot requires signals from the GL thread).
     */
    private void emitOnMainThread(final String signal, final Object... args) {
        mainHandler.post(() -> {
            try {
                emitSignal(signal, args);
            } catch (Exception e) {
                Log.e(TAG, "Error emitting signal " + signal, e);
            }
        });
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static String getDeviceName(MidiDeviceInfo info) {
        Bundle props = info.getProperties();
        String name = props.getString(MidiDeviceInfo.PROPERTY_NAME);
        if (name == null || name.isEmpty()) {
            name = props.getString(MidiDeviceInfo.PROPERTY_MANUFACTURER, "Unknown")
                 + " " + props.getString(MidiDeviceInfo.PROPERTY_PRODUCT, "MIDI Device");
        }
        return name;
    }

    private static int getOutputPortCount(MidiDeviceInfo info) {
        int count = 0;
        for (MidiDeviceInfo.PortInfo port : info.getPorts()) {
            if (port.getType() == MidiDeviceInfo.PortInfo.TYPE_OUTPUT) {
                count++;
            }
        }
        return count;
    }
}
