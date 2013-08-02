package com.ikesato.bt_remocon;

import java.util.Collection;

import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.view.Menu;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Toast;

import com.ikesato.bluetooth.Bluetooth;
import com.ikesato.bluetooth.BluetoothChatService;

public class MainActivity extends Activity {
    private static final String TAG=MainActivity.class.getSimpleName();
    private Bluetooth mBluetooth;
    private BluetoothChatService mChatService = null;

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

        findViewById(R.id.connect_button).setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.v(TAG, "connect button");
                Log.v(TAG, "==============");
				//connectDevice("00:13:01:10:36:42");
				connectDevice("84:00:D2:C2:58:2D");
            }
        });
    }

    @Override
    public void onStart() {
        super.onStart();

        // If BT is not on, request that it be enabled.
        // setupChat() will then be called during onActivityResult
        if (!mBluetooth.isEnabled()) {
            Intent intent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
            startActivityForResult(intent, REQUEST_ENABLE_BT);
        } else {
            if (mChatService == null)
				setupBluetoothService();
        }
    }

    @Override
    public void onResume() {
        super.onResume();
        mBluetooth.registerReceiver(this);
    }

    @Override
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

	private void setupBluetoothService() {
        Log.d(TAG, "setupBluetoothService()");

        // Initialize the send button with a listener that for click events
        View sendButton = findViewById(R.id.send_button);
        sendButton.setOnClickListener(new OnClickListener() {
            public void onClick(View v) {
                sendMessage("H1551,L776,H97,L291,H97,L291,H97,L97,H97,L97,H97,L97,H97,L97,H97,L97,H97,L97,H97,L291,H97,L291,H97,L291,H97,L97,H97,L291,H97,L97,H97,L97,H97,L97,H97,L4019,H97,L291,H97,L291,H97,L97,H97,L97,H97,L97,H97,L97,H97,L97,H97,L97,H97,L291,H97,L291,H97,L291,H97,L97,H97,L291,H97,L97,H97,L97,H97,L97,H97,L4019\r\n");
            }
        });

        // Initialize the BluetoothChatService to perform bluetooth connections
        mChatService = new BluetoothChatService(this, mHandler);
	}

    // The Handler that gets information back from the BluetoothChatService
    private final Handler mHandler = new Handler() {
        @Override
        public void handleMessage(Message msg) {
            switch (msg.what) {
            case BluetoothChatService.MESSAGE_STATE_CHANGE:
                Log.i(TAG, "MESSAGE_STATE_CHANGE: " + msg.arg1);
                switch (msg.arg1) {
                case BluetoothChatService.STATE_CONNECTED:
                    setStatus(getString(R.string.title_connected_to));
                    break;
                case BluetoothChatService.STATE_CONNECTING:
                    setStatus(R.string.title_connecting);
                    break;
                case BluetoothChatService.STATE_LISTEN:
                case BluetoothChatService.STATE_NONE:
                    setStatus(R.string.title_not_connected);
                    break;
                }
                break;
            case BluetoothChatService.MESSAGE_WRITE:
                byte[] writeBuf = (byte[]) msg.obj;
                // construct a string from the buffer
                String writeMessage = new String(writeBuf);
                Log.v(TAG, "Me:  " + writeMessage);
                break;
            case BluetoothChatService.MESSAGE_READ:
                byte[] readBuf = (byte[]) msg.obj;
                // construct a string from the valid bytes in the buffer
                String readMessage = new String(readBuf, 0, msg.arg1);
                Log.v(TAG, "MESSAGE READ : " + readMessage);
                break;
            case BluetoothChatService.MESSAGE_DEVICE_NAME:
                // save the connected device's name
            	String deviceName = msg.getData().getString("DEVICE_NAME");
                Log.v(TAG, "ConnectedDeviceName = " + deviceName);
                Toast.makeText(getApplicationContext(), "Connected to " + deviceName,
                			   Toast.LENGTH_SHORT).show();
                break;
            case BluetoothChatService.MESSAGE_NOTIFY:
                Toast.makeText(getApplicationContext(), msg.getData().getString("NOTIFY"),
                               Toast.LENGTH_SHORT).show();
                break;
            }
        }
    };

    /**
     * Sends a message.
     * @param message  A string of text to send.
     */
    private void sendMessage(String message) {
        // Check that we're actually connected before trying anything
        if (mChatService.getState() != BluetoothChatService.STATE_CONNECTED) {
            Toast.makeText(this, R.string.not_connected, Toast.LENGTH_SHORT).show();
            return;
        }

        // Check that there's actually something to send
        if (message.length() > 0) {
            // Get the message bytes and tell the BluetoothChatService to write
            byte[] send = message.getBytes();
            mChatService.write(send);
        }
    }

    private final void setStatus(int resId) {
    	setTitle(resId);
    }

    private final void setStatus(CharSequence subTitle) {
    	setTitle(subTitle);
    }

    private void connectDevice(String address) {
        // Attempt to connect to the device
        mChatService.connect(address);
    }

}
