package com.ikesato.bluetooth;

import java.util.Set;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;

public class Bluetooth {
    private BluetoothAdapter mBtAdapter;

    /**
     * List paired devices
     * @return already paired devices in the Phone
     */
    public Set<BluetoothDevice> listPairedDevices() {
        mBtAdapter = BluetoothAdapter.getDefaultAdapter();
        Set<BluetoothDevice> pairedDevices = mBtAdapter.getBondedDevices();
        return pairedDevices;
    }

    //public xxx startScanDevices();
}
