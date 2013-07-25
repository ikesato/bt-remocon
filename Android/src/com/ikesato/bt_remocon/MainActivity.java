package com.ikesato.bt_remocon;

import java.util.Collection;

import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.Menu;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Toast;

import com.ikesato.bluetooth.Bluetooth;

public class MainActivity extends Activity {
    private static final String TAG=MainActivity.class.getSimpleName();
    private Bluetooth mBluetooth;

    private static final int REQUEST_ENABLE_BT = 1;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        mBluetooth = new Bluetooth();

        findViewById(R.id.list_devices_button).setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.v(TAG, "list devices");
                Log.v(TAG, "============");
                Collection<BluetoothDevice> devices = mBluetooth.listPairedDevices();
                for (BluetoothDevice device : devices) {
                    String s = String.format("device: %s %d %s %s",
                                             device.getAddress(),
                                             device.getBondState(),
                                             device.getName(),
                                             device.getBluetoothClass().toString());
                    Log.v(TAG, s);
                }
            }
        });

        findViewById(R.id.scan_devices_button).setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.v(TAG, "scan devices");
                Log.v(TAG, "============");
                mBluetooth.startScan(new Bluetooth.OnScanDeviceListener() {
                    @Override
                    public void onFoundDevice(BluetoothDevice device) {
                        String s = String.format("found: %s %d %s %s",
                                                 device.getAddress(),
                                                 device.getBondState(),
                                                 device.getName(),
                                                 device.getBluetoothClass().toString());
                        Log.v(TAG, s);
                    }

                    @Override
                    public void onFinishedScan() {
                        Log.v(TAG, "finished scan devices.");
                    }
                });
            }
        });

        if (!mBluetooth.isEnabled()) {
            Intent intent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
            startActivityForResult(intent, REQUEST_ENABLE_BT);
        }
    }

    public void onResume() {
        super.onResume();
        mBluetooth.registerReceiver(this);
    }

    public void onPause() {
        super.onPause();
        mBluetooth.unregisterReceiver(this);
    }

    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        switch (requestCode) {
        case REQUEST_ENABLE_BT:
            if (resultCode == Activity.RESULT_OK) {
                Log.d(TAG, "BT was enabled");
            } else {
                Log.d(TAG, "BT not enabled");
                Toast.makeText(this, R.string.bt_not_enabled_leaving, Toast.LENGTH_SHORT).show();
                finish();
            }
        }
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.main, menu);
        return true;
    }
}
