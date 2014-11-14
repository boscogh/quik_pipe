package hum.bosco.trade.quik.adapter;

import com.sun.jna.platform.win32.Kernel32;

public interface PipesAPI extends Kernel32{
	DWORD PIPE_READMODE_MESSAGE = new DWORD(2);
	boolean SetNamedPipeHandleState(
			  HANDLE hNamedPipe,
			  DWORDByReference lpMode,
			  DWORDByReference lpMaxCollectionCount,
			  DWORDByReference lpCollectDataTimeout
			);
	boolean FlushFileBuffers(HANDLE hNamedPipe);
}
