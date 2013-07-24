package com.ikesato.bt_remocon;

import java.util.Set;

import android.app.Activity;
import android.bluetooth.BluetoothDevice;
import android.os.Bundle;
import android.util.Log;
import android.view.Menu;

import com.ikesato.bluetooth.Bluetooth;

public class MainActivity extends Activity {
	private static final String TAG=MainActivity.class.getSimpleName();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

		Bluetooth bt = new Bluetooth();
		Set<BluetoothDevice> devices = bt.listPairedDevices();
		for (BluetoothDevice device : devices) {
			String s = String.format("%s %d %s %s",
									 device.getAddress(),
									 device.getBondState(),
									 device.getName(),
									 device.getBluetoothClass().toString());
			Log.v(TAG, s);
		}
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.main, menu);
        return true;
    }
}
