package hum.bosco.trade.quik.adapter;

import java.nio.ByteBuffer;

import com.sun.jna.platform.win32.Kernel32;
import com.sun.jna.ptr.IntByReference;

/*
	Copyright (c) Pavel M Bosco, 2014
*/
public interface PipesAPI extends Kernel32{
    boolean PeekNamedPipe(
    		  HANDLE hNamedPipe,
    		  ByteBuffer lpBuffer,
    		  int nBufferSize,
    		  IntByReference lpBytesRead,
    		  DWORDByReference lpTotalBytesAvail,
    		  DWORDByReference lpBytesLeftThisMessage
    		);
    
	DWORD PIPE_READMODE_MESSAGE = new DWORD(2);
	DWORD PIPE_READMODE_BYTE = new DWORD(0);
	boolean SetNamedPipeHandleState(
			  HANDLE hNamedPipe,
			  DWORDByReference lpMode,
			  DWORDByReference lpMaxCollectionCount,
			  DWORDByReference lpCollectDataTimeout
			);
	boolean FlushFileBuffers(HANDLE hNamedPipe);
}
