--[[
*******************************************************************
Copyright (c) Pavel M Bosco, 2014


Сервер получения запросов и отправки результатов через Pipe.
В примере обрабатываются запросы на получение моментального снимка стакана Quik,
а так же получение последних N свечей. В качестве параметров принимаются код класса и код бумаги.
Для свечей в качестве параметров кроме этого еще принимаются период и количество свечей с конца.
Индекс 0 таким образом соответствует последней, текущей свече, ещё до того как она закончилась. 
Формат вывода для свечей - csv, разделитель ";" - date;time;open;high;low;close;volume 
*******************************************************************
]]

mode = 0
stopped = false
f = nil
cls = ""
sec = ""
cmd = ""
response = ""
candleCount = 0
last50CandlesAsString = ""
SERVER_NOT_CONNECTED = "not connected"

function ds_getCandlesByIndex(ds,count)
   local size=ds:Size()
   local t={}
   local first_candle = size - count+1
   local end_candle = size
   if end_candle>size then 
    end_candle=size 
   end
   if first_candle < 0 then
     first_candle = 0
   end
   --message("in func: " .. string.format("%d, %d, %d\n", first_candle, end_candle, count), 1)

   local s = ""
   for i=first_candle,end_candle do
      j = i-first_candle
      t[j]={
         open=ds:O(i);
         high=ds:H(i);
         low=ds:L(i);
         close=ds:C(i);
         volume=ds:V(i);
         datetime=string.format("%04d%02d%02d;%02d%02d%02d", ds:T(i).year, ds:T(i).month, ds:T(i).day, ds:T(i).hour, ds:T(i).min, ds:T(i).sec);
      }
      s = s .. string.format("%s;%1.2f;%1.2f;%1.2f;%1.2f;%1.2f\n", t[j].datetime, t[j].open, t[j].high, t[j].low, t[j].close, t[j].volume)
   end
   --message("in func: " .. string.format("%d, %d, %d\n", first_candle, end_candle, count) .. s, 1)
   return s
end


--колбек вызывается при получении нового стакана
function OnQuote(cl, sc )
        local s = ""
	if cmd == "stakan" and cl == cls and sc == sec then
           s = marshalStakan(cl, sc)
	end
	if cmd == "stakan" and string.len(s)>0 then
	   response = s
	end 
end

function marshalStakan(cl, sc)
	local s = ""
	ql2 = getQuoteLevel2(cls, sec)
	for i=1,ql2.bid_count do
		s = s.. string.format("%1.2f:%1.2f\n", ql2.bid[i].quantity, ql2.bid[i].price)
	end
	s = s .. "###\n"
	for i=1,ql2.offer_count do
		s = s.. string.format("%1.2f:%1.2f\n", ql2.offer[i].quantity, ql2.offer[i].price)
	end
        return s
end

-- вызывается при нажатии кнопки "остановить" в диалоге
function OnStop(signal)
	stopped = true
end

ffi = assert(require("ffi"))
dlls = {}
dlls.__cdecl = assert(ffi.load('kernel32'))
ffi.cdef[[
typedef unsigned long ULONG_PTR;
typedef unsigned long DWORD;
typedef void *PVOID;
typedef PVOID HANDLE;
typedef int *LPDWORD;
typedef struct { ULONG_PTR Internal; 
  ULONG_PTR InternalHigh;
  union {
    struct {
      DWORD Offset;
      DWORD OffsetHigh;
    };
    PVOID  Pointer;
  };
  HANDLE    hEvent;
} OVERLAPPED;
int FlushFileBuffers(HANDLE hFile);
int MessageBoxA(void *w, const char *txt, const char *cap, int type);
int CreateNamedPipeA(const char *name, int openMode, int pipeMode, int maxInstances, int outBufferSize, int inBufferSize, int defTimeout, void *security);
int GetLastError();
int ConnectNamedPipe(HANDLE, OVERLAPPED*); 
int DisconnectNamedPipe(HANDLE);
int CloseHandle(HANDLE hObject);
int WriteFile(HANDLE hFile, const char *lpBuffer, int nNumberOfBytesToWrite, int *lpNumberOfBytesWritten, OVERLAPPED* lpOverlapped);
int ReadFile(HANDLE hFile, PVOID lpBuffer, DWORD nNumberOfBytesToRead, LPDWORD lpNumberOfBytesRead, OVERLAPPED* lpOverlapped);
]]

STATUS_PENDING = 259;                       
ERROR_IO_PENDING = 997;                     
ERROR_PIPE_CONNECTED = 535;                 
PIPE_ACCESS_DUPLEX = 0x00000003;            
PIPE_ACCESS_INBOUND = 0x00000001;           
PIPE_ACCESS_OUTBOUND = 0x00000002;          
FILE_FLAG_FIRST_PIPE_INSTANCE = 0x00080000; 
FILE_FLAG_OVERLAPPED = 0x40000000;          
PIPE_TYPE_MESSAGE = 0x00000004;             
PIPE_READMODE_MESSAGE = 0x00000002;         
PIPE_WAIT = 0x00000000;                     
PIPE_NOWAIT = 0x00000001;                   
PIPE_REJECT_REMOTE_CLIENTS = 0x00000008;    

poverlapped = ffi.new("OVERLAPPED[1]")
buflen = ffi.new("unsigned long[1]", 1)
readBuffer = ffi.new("char [4*1024]")
bytesRead = ffi.new("unsigned long[1]", 1)
params = ""

function OnConnected()
 if mode == 0 then
   disconnectAndReconnect(true)
   message("Труба открыта", 1) 
 end  
end

function OnClose()
  if mode == 1 then
     r = ffi.C.ReadFile(handle, readBuffer, 4*1024, bytesRead, nil);
  end             
  mode = 0
  disconnectAndReconnect(false)
end

function OnDisconnected()
  OnClose()
  message("Труба закрыта", 1) 
end

function disconnectAndReconnect(doConnect)
  ffi.C.FlushFileBuffers(handle)
  ffi.C.DisconnectNamedPipe(handle)
  if doConnect then
    assert(ffi.C.ConnectNamedPipe(handle, poverlapped), "Соединение установить не удалось")
  end
end

function notEmpty(ss)
  if ss == "" then
    return SERVER_NOT_CONNECTED
  else
    return ss
  end
end

function processCommand(request)
--[[ 
1. выделям команду
2. выделяем параметры class code, sec code, период, количество свечей 
3. устанавливаем параметры
4. обнуляем response
5. устанавливаем команду
]]
  command = string.sub(request, 1, 3)
  if command == "sta" or command == "sti" then -- sta - стакан после изменения, sti - стакан немедленно!
--  2. выделяем параметры class code, sec code
    local ind = string.find(request,":",3,true)
    
    cls = string.sub(request, 4, ind-1)
    sec = string.sub(request, 1+ind) 
    --message(string.format("Запрос стакана. Параметры: %s, %s", cls, sec), 1)
    response = ""
    if command == "sta" then
      cmd = "stakan"
      if isConnected() == 1 then
        cmd = "stakan"
      else
        response = SERVER_NOT_CONNECTED
      end
    else 
        response = notEmpty(marshalStakan(cls, sec))
    end
  end
  if command == "sve" then -- свеча
    --2. выделяем параметры class code, sec code, период, количество свечей 
    ind = string.find(request,":",3,true)
    jnd = string.find(request,":",ind+1,true)
    knd = string.find(request,":",jnd+1,true)    
    cls = string.sub(request, 4, ind-1)
    sec = string.sub(request, 1+ind, jnd-1) 
    interval = tonumber(string.sub(request, jnd+1, knd-1))
    candleCount  = tonumber(string.sub(request, knd+1))
    local ds, errdesc = CreateDataSource(cls, sec, interval)
    if ds == nil then
       message("Ошибка при открытии графика " .. cls .. " : " .. sec .. " : ".. errdesc, 1)
    else
       --message(string.format("Запрос свечей. Параметры: %s, %s, %d, %d", cls, sec, interval, candleCount), 1)

       last50CandlesAsString = ds_getCandlesByIndex(ds, candleCount)
       ds:Close()
    end

    response = notEmpty(last50CandlesAsString) --""
    --Если много свечей, то квик безбожно виснет
    --message("Ответ по графику: " .. last50CandlesAsString, 1)
    cmd = "svecha"
  end
  if command == "isc" then -- проверка соединения. отвечаем сразу
    response = tostring(isConnected())
  end 
  if command == "stm" then -- время сервера, отвечаем сразу
    response = notEmpty(getInfoParam("SERVERTIME"))
    --message("Ответ: " .. response, 1)
  end
  if command == "trd" then -- время сервера, отвечаем сразу
    response = notEmpty(getInfoParam("TRADEDATE"))
    --message("Ответ: " .. response, 1)
  end
  if command == "go " then
    ind = string.find(request,":",3,true)
    cls = string.sub(request, 4, ind-1)
    sec = string.sub(request, 1+ind) 
    info = getParamEx(cls, sec, "BUYDEPO")
   
    response = notEmpty(info.param_image)
  end

end
                               
-- главная нить, обрабатывает подключения клиента и запросы от него
function main(  )
  handle = assert(ffi.C.CreateNamedPipeA("\\\\.\\pipe\\pmb.quik.pipe", 
			PIPE_ACCESS_DUPLEX + FILE_FLAG_OVERLAPPED + FILE_FLAG_FIRST_PIPE_INSTANCE, 
			PIPE_TYPE_MESSAGE + PIPE_READMODE_MESSAGE + PIPE_REJECT_REMOTE_CLIENTS, 
			1, 
			4*1024, 4*1024, 
			0, nil))
  assert(ffi.C.ConnectNamedPipe(handle, poverlapped), "Проблемы с подключением к трубе!")
  mode = 0; -- 0 - подключаемся и ждём клиента, 1 - читаем, 2 - пишем 
  --message("Запустились", 1)
  while not stopped do
    if mode == 0 then -- подключаемся
      if poverlapped[0].Internal ~= STATUS_PENDING then -- пока никого
        --message("Клиент подключился", 1)
        mode = 1 -- пора читать
      else
        sleep(4)
        if poverlapped[0].Internal ~= STATUS_PENDING then -- пока никого
          --message("Клиент подключился", 1)
          mode = 1 -- пора читать
        end
      end 
    end 
    if mode == 1 then
    	--message("Читаем", 1)
    	r = ffi.C.ReadFile(handle, readBuffer, 4*1024, bytesRead, nil);
    	if r == 0 and bytesRead[0] ==0 then -- клиент отвалился, заканчиваем
          --message("Клиент отключился ", 1)
    	  disconnectAndReconnect(true)	  
          mode = 0
    	else -- чего-то считали
    	  --message("Считали " .. bytesRead[0] .. " байт", 1)
    	  request = ffi.string(readBuffer)
          --message(request, 1)
          --message("Обработали запрос", 1)
          processCommand(request)  
    	  mode = 2 -- считали, можно и пописАть
          --message("Переключились на запись", 1)
    	end 
    end
    if mode == 2 and string.len(response) > 0 then
      cmd = ""
      --message("Пишем..", 1)
      ffi.C.WriteFile(handle, response, string.len(response), buflen, poverlapped)
      ffi.C.FlushFileBuffers(handle)
      --message("Записали", 1)
      mode = 1
      --message("Переключились на чтение", 1)
    end 
  end 
  disconnectAndReconnect(false)
  ffi.C.CloseHandle(handle)
end
