package com.ikesato.bluetooth;

import java.util.Collection;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;

public class Bluetooth {
    public interface OnScanDeviceListener {
        public void onFoundDevice(BluetoothDevice device);
        public void onFinishedScan();
    }

    private BluetoothAdapter mBtAdapter;
    private OnScanDeviceListener mListener = null;

    /**
     * Constructor
     */
    public Bluetooth() {
        mBtAdapter = BluetoothAdapter.getDefaultAdapter();
    }

    /**
     * List paired devices
     * @return already paired devices in the Phone
     */
    public Collection<BluetoothDevice> listPairedDevices() {
        Collection<BluetoothDevice> pairedDevices = mBtAdapter.getBondedDevices();
        return pairedDevices;
    }

    /**
     * Scan Bluetooth devices
     */
    public void startScan(OnScanDeviceListener listener) {
        if (listener == null)
            throw new RuntimeException("you need to specify listener");
        mListener = listener;

        if (mBtAdapter.isDiscovering())
            mBtAdapter.cancelDiscovery();

        mBtAdapter.startDiscovery();
    }

	/**
	 * Register the receiver
	 */
    public void registerReceiver(Context context) {
        // Register for broadcasts when a device is discovered
        IntentFilter filter = new IntentFilter(BluetoothDevice.ACTION_FOUND);
        context.registerReceiver(mReceiver, filter);

        // Register for broadcasts when discovery has finished
        filter = new IntentFilter(BluetoothAdapter.ACTION_DISCOVERY_FINISHED);
        context.registerReceiver(mReceiver, filter);
    }

	/**
	 * Unregister the receiver
	 */
    public void unregisterReceiver(Context context) {
        context.unregisterReceiver(mReceiver);
    }

    // The BroadcastReceiver that listens for discovered devices and
    // changes the title when discovery is finished
    private final BroadcastReceiver mReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();
            if (BluetoothDevice.ACTION_FOUND.equals(action)) {
                // When discovery finds a device
                BluetoothDevice device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
                mListener.onFoundDevice(device);
            } else if (BluetoothAdapter.ACTION_DISCOVERY_FINISHED.equals(action)) {
                // When discovery is finished
                mListener.onFinishedScan();
                mListener = null;
            }
        }
    };
}
